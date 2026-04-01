#!/usr/bin/env python3
"""
Calendar integration service for Ambxst.
Communicates with QML via stdin (commands) / stdout (JSON lines).
Supports Google Calendar (OAuth 2.0) and CalDAV providers.
"""

import json
import os
import re
import sys
import time
import threading
import subprocess
import signal
from datetime import datetime, timedelta
from urllib.parse import urlparse, parse_qs

# ── paths ──────────────────────────────────────────────────────────

XDG_CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
XDG_CACHE = os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
CONFIG_DIR = os.path.join(XDG_CONFIG, "ambxst")
CACHE_DIR = os.path.join(XDG_CACHE, "ambxst")
TOKENS_PATH = os.path.join(CONFIG_DIR, "calendar_tokens.json")
CACHE_PATH = os.path.join(CACHE_DIR, "calendar_events.json")
NOTIFIED_PATH = os.path.join(CACHE_DIR, "calendar_notified.json")

# Google OAuth client (public / installed-app type – no secret needed for
# device or localhost redirect flows with PKCE).
GOOGLE_CLIENT_ID = ""
GOOGLE_CLIENT_SECRET = ""
GOOGLE_SCOPES = ["https://www.googleapis.com/auth/calendar"]

# gcalcli token paths (pickle format, google.oauth2.credentials.Credentials)
XDG_DATA = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
GCALCLI_TOKEN_PATH = os.path.join(XDG_DATA, "gcalcli", "oauth")

os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(CACHE_DIR, exist_ok=True)

# Bundled sound file (shipped with the shell)
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BUNDLED_SOUND = os.path.join(_SCRIPT_DIR, "..", "assets", "sound", "polite-warning-tone.wav")


# ── helpers ────────────────────────────────────────────────────────

def emit(obj):
    """Send a JSON message to QML (stdout)."""
    print(json.dumps(obj, ensure_ascii=False), flush=True)


def load_json(path, default=None):
    try:
        with open(path, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return default if default is not None else {}


def save_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    # Secure the tmp file BEFORE the atomic rename so the file is never
    # visible at the target path with open permissions (closes a race window).
    if path == TOKENS_PATH:
        os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def iso_now():
    return datetime.now().astimezone().isoformat(timespec="seconds")


# ── Google Calendar provider ──────────────────────────────────────

class GoogleProvider:
    """Handles Google Calendar OAuth + API calls."""

    def __init__(self, account_data, tokens):
        self.account_id = account_data["id"]
        self.email = account_data.get("email", "")
        self.tokens = tokens  # reference to the global tokens dict
        # NOTE: _service is intentionally NOT cached here.
        # The google-api-python-client Service object holds a reference to the
        # Credentials object at build time.  After a token refresh the old Service
        # silently continues sending the stale access_token and gets 401 errors.
        # Re-building on every call is cheap because the discovery document is
        # cached internally by the library.

    def _get_credentials(self):
        from google.oauth2.credentials import Credentials
        tok = self.tokens.get("google", {}).get(self.account_id)
        if not tok:
            return None
        # Use stored client_id/secret (may come from gcalcli import)
        client_id = tok.get("client_id") or GOOGLE_CLIENT_ID
        client_secret = tok.get("client_secret") or GOOGLE_CLIENT_SECRET

        # Restore stored expiry so creds.expired is accurate (avoids unnecessary refreshes)
        expiry = None
        if tok.get("token_expiry"):
            try:
                expiry = datetime.fromisoformat(tok["token_expiry"])
            except (ValueError, TypeError):
                pass

        creds = Credentials(
            token=tok.get("access_token"),
            refresh_token=tok.get("refresh_token"),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=client_id,
            client_secret=client_secret,
            scopes=GOOGLE_SCOPES,
            expiry=expiry,
        )
        if creds.expired and creds.refresh_token:
            from google.auth.transport.requests import Request
            try:
                creds.refresh(Request())
                tok["access_token"] = creds.token
                if creds.expiry:
                    tok["token_expiry"] = creds.expiry.isoformat()
                save_json(TOKENS_PATH, self.tokens)
            except Exception as e:
                emit({"type": "auth_error", "message": f"Google token refresh failed: {e}"})
                return None
        return creds

    def _build_service(self):
        creds = self._get_credentials()
        if creds is None:
            return None
        try:
            from googleapiclient.discovery import build
            return build("calendar", "v3", credentials=creds)
        except Exception as e:
            emit({"type": "error", "message": f"Google service build failed: {e}"})
            return None

    def list_calendars(self):
        svc = self._build_service()
        if not svc:
            return []
        try:
            result = svc.calendarList().list().execute()
            cals = []
            for item in result.get("items", []):
                cals.append({
                    "id": item["id"],
                    "accountId": self.account_id,
                    "name": item.get("summary", "Untitled"),
                    "color": item.get("backgroundColor", "#bd93f9"),
                    "enabled": True,
                })
            return cals
        except Exception as e:
            emit({"type": "error", "message": f"Google list calendars: {e}"})
            return []

    @staticmethod
    def _extract_google_meet_link(item):
        """Return the Google Meet / video conference URL from a Google Calendar event item."""
        # 1. Modern API: conferenceData.entryPoints[type=video].uri
        for ep in (item.get("conferenceData") or {}).get("entryPoints") or []:
            if ep.get("entryPointType") == "video":
                uri = (ep.get("uri") or "").strip()
                if uri.startswith("https://"):
                    return uri
        # 2. Legacy hangoutLink field (still present on many personal-account events)
        link = (item.get("hangoutLink") or "").strip()
        if link.startswith("https://"):
            return link
        return ""

    def fetch_events(self, calendar_id, time_min, time_max):
        svc = self._build_service()
        if not svc:
            return []
        try:
            result = svc.events().list(
                calendarId=calendar_id,
                timeMin=time_min,
                timeMax=time_max,
                singleEvents=True,
                orderBy="startTime",
                maxResults=500,
            ).execute()
            events = []
            for item in result.get("items", []):
                start = item.get("start", {})
                end = item.get("end", {})
                all_day = "date" in start
                meet_link = self._extract_google_meet_link(item)
                events.append({
                    "id": item["id"],
                    "calendarId": calendar_id,
                    "title": item.get("summary", ""),
                    "description": item.get("description", ""),
                    "location": item.get("location", ""),
                    "meetLink": meet_link,
                    "start": start.get("date") or start.get("dateTime", ""),
                    "end": end.get("date") or end.get("dateTime", ""),
                    "allDay": all_day,
                    "reminder": self._extract_reminder(item),
                })
            return events
        except Exception as e:
            emit({"type": "error", "message": f"Google fetch events: {e}"})
            return []

    def _extract_reminder(self, item):
        overrides = item.get("reminders", {}).get("overrides", [])
        if overrides:
            return overrides[0].get("minutes", 15)
        if item.get("reminders", {}).get("useDefault", True):
            return 15
        return 0

    def create_event(self, event):
        svc = self._build_service()
        if not svc:
            return None
        body = self._build_event_body(event)
        try:
            result = svc.events().insert(
                calendarId=event["calendarId"],
                body=body,
                conferenceDataVersion=1,  # always request so conferenceData is in the response
            ).execute()
            # Google returns the created event with conferenceData already populated
            # (creation is typically synchronous).  Update the caller's dict in-place
            # so the cached copy immediately has the real meet link.
            meet = self._extract_google_meet_link(result)
            if meet:
                event["meetLink"] = meet
            return result.get("id")
        except Exception as e:
            emit({"type": "error", "message": f"Google create event: {e}"})
            return None

    def update_event(self, event):
        svc = self._build_service()
        if not svc:
            return False
        body = self._build_event_body(event)
        try:
            result = svc.events().update(
                calendarId=event["calendarId"],
                eventId=event["id"],
                body=body,
                conferenceDataVersion=1,
            ).execute()
            meet = self._extract_google_meet_link(result)
            if meet:
                event["meetLink"] = meet
            return True
        except Exception as e:
            emit({"type": "error", "message": f"Google update event: {e}"})
            return False

    def delete_event(self, calendar_id, event_id):
        svc = self._build_service()
        if not svc:
            return False
        try:
            svc.events().delete(calendarId=calendar_id, eventId=event_id).execute()
            return True
        except Exception as e:
            emit({"type": "error", "message": f"Google delete event: {e}"})
            return False

    def _build_event_body(self, event):
        body = {
            "summary": event.get("title", ""),
            "description": event.get("description", ""),
        }
        if event.get("location"):
            body["location"] = event["location"]
        meet_link = event.get("meetLink", "")
        if meet_link == "request":
            body["conferenceData"] = {
                "createRequest": {
                    "requestId": f"ambxst-{event.get('id') or __import__('uuid').uuid4().hex[:16]}",
                    "conferenceSolutionKey": {"type": "hangoutsMeet"}
                }
            }
        if event.get("allDay"):
            body["start"] = {"date": event["start"][:10]}
            body["end"] = {"date": event["end"][:10]}
        else:
            start_str = event["start"]
            end_str = event["end"]
            # Google API requires timezone in dateTime — add local offset if missing
            if "+" not in start_str and "-" not in start_str[10:] and "Z" not in start_str:
                tz = datetime.now().astimezone().strftime("%z")
                tz_fmt = tz[:3] + ":" + tz[3:]
                start_str += tz_fmt
                end_str += tz_fmt
            body["start"] = {"dateTime": start_str}
            body["end"] = {"dateTime": end_str}
        reminder = event.get("reminder", 0)
        if reminder > 0:
            body["reminders"] = {
                "useDefault": False,
                "overrides": [{"method": "popup", "minutes": reminder}],
            }
        return body


# ── CalDAV provider ───────────────────────────────────────────────

class CalDAVProvider:
    """Handles CalDAV calendar operations."""

    def __init__(self, account_data, tokens):
        self.account_id = account_data["id"]
        self.url = account_data.get("url", "")
        self.tokens = tokens
        # NOTE: DAVClient is intentionally NOT cached.
        # A cached client becomes stale after network interruptions and raises
        # connection errors on subsequent calls with no way to recover.
        # DAVClient creation is cheap (no TCP connection until the first request).

    def _get_client(self):
        import caldav
        from requests.auth import HTTPBasicAuth
        tok = self.tokens.get("caldav", {}).get(self.account_id, {})
        username = tok.get("username", "")
        password = tok.get("password", "")
        # Strip embedded whitespace/control chars (may survive from initial paste → storage)
        url = re.sub(r'\s', '', self.url)
        if not url.endswith("/"):
            url += "/"
        return caldav.DAVClient(
            url=url,
            username=username,
            password=password,
            auth=HTTPBasicAuth(username, password),
            ssl_verify_cert=True,
        )

    def _find_calendar(self, client, calendar_id):
        """Return the caldav Calendar object for *calendar_id*, or None."""
        try:
            principal = client.principal()
            for cal in principal.calendars():
                if str(cal.url) == calendar_id:
                    return cal
        except Exception:
            pass
        return None

    def list_calendars(self):
        try:
            client = self._get_client()
            principal = client.principal()
            cals = []
            colors = ["#50fa7b", "#ff79c6", "#8be9fd", "#ffb86c", "#bd93f9"]
            for i, cal in enumerate(principal.calendars()):
                cal_id = str(cal.url)
                name = cal.name or "Calendar"
                cals.append({
                    "id": cal_id,
                    "accountId": self.account_id,
                    "name": name,
                    "color": colors[i % len(colors)],
                    "enabled": True,
                })
            return cals
        except Exception as e:
            emit({"type": "error", "message": f"CalDAV list calendars: {e}"})
            return []

    def fetch_events(self, calendar_id, time_min, time_max):
        try:
            from icalendar import Calendar as iCalendar
            client = self._get_client()
            cal = self._find_calendar(client, calendar_id)
            if not cal:
                return []

            start_dt = datetime.fromisoformat(time_min.replace("Z", "+00:00"))
            end_dt = datetime.fromisoformat(time_max.replace("Z", "+00:00"))
            results = cal.search(start=start_dt, end=end_dt, event=True, expand=True)

            events = []
            for item in results:
                try:
                    ical = iCalendar.from_ical(item.data)
                except Exception:
                    continue
                for component in ical.walk():
                    if component.name != "VEVENT":
                        continue
                    dtstart = component.get("dtstart")
                    dtend = component.get("dtend")
                    if not dtstart:
                        continue
                    start_val = dtstart.dt
                    end_val = dtend.dt if dtend else start_val
                    all_day = not hasattr(start_val, "hour")
                    events.append({
                        "id": str(component.get("uid", "")),
                        "calendarId": calendar_id,
                        "title": str(component.get("summary", "")),
                        "description": str(component.get("description", "")),
                        "location": str(component.get("location", "")),
                        "meetLink": self._extract_caldav_meet_link(component),
                        "start": start_val.isoformat() if hasattr(start_val, "isoformat") else str(start_val),
                        "end": end_val.isoformat() if hasattr(end_val, "isoformat") else str(end_val),
                        "allDay": all_day,
                        "reminder": self._extract_reminder(component),
                    })
            return events
        except Exception as e:
            emit({"type": "error", "message": f"CalDAV fetch events: {e}"})
            return []

    # Conference link URL patterns we recognise as "Meet-like" (worth showing a button)
    _CONF_PATTERNS = (
        "meet.google.com",
        "zoom.us",
        "teams.microsoft.com",
        "webex.com",
        "telemost.yandex",
        "whereby.com",
        "jitsi",
        "gotomeet",
        "meet.",
    )

    def _extract_caldav_meet_link(self, component):
        """Return the first conference / video URL from a VEVENT component, or ''."""
        # 1. Standard iCal URL property
        url_prop = component.get("url")
        if url_prop:
            url = str(url_prop).strip()
            if url.startswith("https://") and any(p in url for p in self._CONF_PATTERNS):
                return url

        # 2. RFC 7986 CONFERENCE property (used by many modern CalDAV servers)
        conf_prop = component.get("conference")
        if conf_prop:
            val = str(conf_prop).strip()
            if val.startswith("https://"):
                return val

        # 3. X-GOOGLE-CONFERENCE / X-TELEMOST-URL and similar vendor extensions
        for key in component.keys():
            if key.upper().startswith("X-") and ("CONF" in key.upper() or
                                                    "MEET" in key.upper() or
                                                    "TELEMOST" in key.upper()):
                val = str(component[key]).strip()
                if val.startswith("https://"):
                    return val

        # 4. Scan description for a bare conference URL on its own line
        desc = str(component.get("description", "") or "")
        for line in desc.splitlines():
            line = line.strip()
            if line.startswith("https://") and any(p in line for p in self._CONF_PATTERNS):
                return line

        return ""

    def _extract_reminder(self, component):
        for alarm in component.walk():
            if alarm.name == "VALARM":
                trigger = alarm.get("trigger")
                if trigger and hasattr(trigger.dt, "total_seconds"):
                    return abs(int(trigger.dt.total_seconds() // 60))
        return 0

    def _build_vevent(self, event, uid):
        """Build an icalendar Event component from an event dict."""
        from icalendar import Event as iEvent, Alarm
        vevent = iEvent()
        vevent.add("uid", uid)
        vevent.add("summary", event.get("title", ""))
        vevent.add("description", event.get("description", ""))
        if event.get("location"):
            vevent.add("location", event["location"])
        meet = (event.get("meetLink") or "").strip()
        if meet and meet != "request" and meet.startswith("https://"):
            vevent.add("url", meet)
        if event.get("allDay"):
            from datetime import date
            vevent.add("dtstart", date.fromisoformat(event["start"][:10]))
            vevent.add("dtend", date.fromisoformat(event["end"][:10]))
        else:
            dtstart = datetime.fromisoformat(event["start"])
            dtend = datetime.fromisoformat(event["end"])
            if dtstart.tzinfo is None:
                dtstart = dtstart.astimezone()
            if dtend.tzinfo is None:
                dtend = dtend.astimezone()
            vevent.add("dtstart", dtstart)
            vevent.add("dtend", dtend)
        if event.get("reminder", 0) > 0:
            alarm = Alarm()
            alarm.add("action", "DISPLAY")
            alarm.add("trigger", timedelta(minutes=-event["reminder"]))
            alarm.add("description", event.get("title", "Reminder"))
            vevent.add_component(alarm)
        return vevent

    def create_event(self, event):
        try:
            from icalendar import Calendar as iCalendar
            import uuid
            client = self._get_client()
            cal = self._find_calendar(client, event["calendarId"])
            if not cal:
                return None

            uid = str(uuid.uuid4())
            ical = iCalendar()
            ical.add("prodid", "-//Ambxst//Calendar//EN")
            ical.add("version", "2.0")
            ical.add_component(self._build_vevent(event, uid))
            cal.save_event(ical.to_ical().decode("utf-8"))
            return uid
        except Exception as e:
            emit({"type": "error", "message": f"CalDAV create event: {e}"})
            return None

    def update_event(self, event):
        """Update an existing CalDAV event in-place via PUT, preserving its UID.

        The old delete-then-create approach is dangerous: if create fails the
        event is silently lost and the new UID diverges from the cached one,
        producing duplicates after the next sync.
        """
        try:
            from icalendar import Calendar as iCalendar
            client = self._get_client()
            cal = self._find_calendar(client, event["calendarId"])
            if not cal:
                return False

            uid = event.get("id", "")
            target_ev = None
            for ev in cal.events():
                try:
                    ical = iCalendar.from_ical(ev.data)
                except Exception:
                    continue
                for component in ical.walk():
                    if component.name == "VEVENT" and str(component.get("uid", "")) == uid:
                        target_ev = ev
                        break
                if target_ev:
                    break

            if not target_ev:
                # Event not on server yet — create it (keeps same UID via create_event path)
                return self.create_event(event) is not None

            # Replace the iCal data in-place (same URL/UID, server does a PUT)
            new_ical = iCalendar()
            new_ical.add("prodid", "-//Ambxst//Calendar//EN")
            new_ical.add("version", "2.0")
            new_ical.add_component(self._build_vevent(event, uid))
            target_ev.data = new_ical.to_ical().decode("utf-8")
            target_ev.save()
            return True
        except Exception as e:
            emit({"type": "error", "message": f"CalDAV update event: {e}"})
            return False

    def delete_event(self, calendar_id, event_id):
        try:
            from icalendar import Calendar as iCalendar
            client = self._get_client()
            cal = self._find_calendar(client, calendar_id)
            if not cal:
                return False
            for ev in cal.events():
                try:
                    ical = iCalendar.from_ical(ev.data)
                except Exception:
                    continue
                for component in ical.walk():
                    if component.name == "VEVENT" and str(component.get("uid", "")) == event_id:
                        ev.delete()
                        return True
            return False
        except Exception as e:
            emit({"type": "error", "message": f"CalDAV delete event: {e}"})
            return False


# ── Calendar Service ──────────────────────────────────────────────

class CalendarService:
    def __init__(self, sync_interval=15, default_reminder=15,
                 sound_on_arrival=True, arrival_sound_path="", blink_on_arrival=True):
        self.sync_interval = sync_interval  # minutes
        self.default_reminder = default_reminder
        self.sound_on_arrival = sound_on_arrival
        self.arrival_sound_path = arrival_sound_path or ""
        self.blink_on_arrival = blink_on_arrival
        self.tokens = load_json(TOKENS_PATH, {"google": {}, "caldav": {}})
        self.cache = load_json(CACHE_PATH, {
            "last_sync": "",
            "accounts": [],
            "calendars": [],
            "events": [],
        })
        self.providers = {}
        self._stop = threading.Event()
        self._lock = threading.Lock()       # guards self.cache and self._notified*
        # Notification keys are strings  "<event_id>:<start_iso>:<kind>"  where
        # kind is "reminder" or "arrive".  Including start_iso means rescheduled
        # events will always fire again regardless of their previous notification state.
        # Load persisted notification keys so restarts don't re-fire today's alerts.
        persisted = load_json(NOTIFIED_PATH, [])
        self._notified = set(persisted) if isinstance(persisted, list) else set()
        self._init_providers()

    def _init_providers(self):
        for acc in self.cache.get("accounts", []):
            self._create_provider(acc)

    def _create_provider(self, account):
        if account["provider"] == "google":
            self.providers[account["id"]] = GoogleProvider(account, self.tokens)
        elif account["provider"] == "caldav":
            self.providers[account["id"]] = CalDAVProvider(account, self.tokens)

    def run(self):
        # Emit initial state
        self._emit_static()
        self._emit_events()
        # Check for gcalcli token availability
        self._check_gcalcli()

        # Start sync & notification threads
        sync_thread = threading.Thread(target=self._sync_loop, daemon=True)
        sync_thread.start()
        notify_thread = threading.Thread(target=self._notify_loop, daemon=True)
        notify_thread.start()

        # Read commands from stdin
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                cmd = json.loads(line)
                self._handle_command(cmd)
            except json.JSONDecodeError:
                emit({"type": "error", "message": "Invalid JSON command"})
            except Exception as e:
                emit({"type": "error", "message": str(e)})

    def _handle_command(self, cmd):
        action = cmd.get("cmd", "")
        if action == "sync":
            self._do_sync()
        elif action == "create":
            self._create_event(cmd.get("event", {}))
        elif action == "update":
            self._update_event(cmd.get("event", {}))
        elif action == "delete":
            self._delete_event(cmd.get("calendarId", ""), cmd.get("eventId", ""))
        elif action == "auth_google":
            self._auth_google(cmd.get("client_id", ""), cmd.get("client_secret", ""))
        elif action == "import_gcalcli":
            self._import_gcalcli()
        elif action == "auth_caldav":
            self._auth_caldav(cmd)
        elif action == "remove_account":
            self._remove_account(cmd.get("accountId", ""))
        elif action == "set_sync_interval":
            self.sync_interval = cmd.get("interval", 15)
        elif action == "set_calendar_enabled":
            self._set_calendar_enabled(cmd.get("calendarId", ""), cmd.get("enabled", True))

    # ── Auth ──

    def _account_exists(self, account_id):
        return any(a["id"] == account_id for a in self.cache.get("accounts", []))

    def _check_gcalcli(self):
        """Check if gcalcli token exists and report to QML."""
        found = os.path.isfile(GCALCLI_TOKEN_PATH)
        emit({"type": "gcalcli_status", "found": found})

    def _import_gcalcli(self):
        """Import Google credentials from gcalcli."""
        if not os.path.isfile(GCALCLI_TOKEN_PATH):
            emit({"type": "auth_error", "message": "gcalcli token not found"})
            return
        try:
            import pickle
            with open(GCALCLI_TOKEN_PATH, "rb") as f:
                creds = pickle.load(f)

            # Refresh if expired
            if creds.expired and creds.refresh_token:
                from google.auth.transport.requests import Request
                creds.refresh(Request())

            # Get user email from calendar API
            from googleapiclient.discovery import build
            service = build("calendar", "v3", credentials=creds)
            cal_list = service.calendarList().list().execute()
            primary = next((c for c in cal_list.get("items", []) if c.get("primary")), None)
            email = primary["id"] if primary else "unknown"

            account_id = f"google_{email}"
            if self._account_exists(account_id):
                emit({"type": "auth_error", "message": f"Google account {email} is already connected. Remove it first to re-add."})
                return
            # Store tokens with gcalcli's client_id/secret for refresh
            if "google" not in self.tokens:
                self.tokens["google"] = {}
            self.tokens["google"][account_id] = {
                "access_token": creds.token,
                "refresh_token": creds.refresh_token,
                "client_id": creds.client_id,
                "client_secret": creds.client_secret,
                "token_expiry": creds.expiry.isoformat() if creds.expiry else None,
            }
            save_json(TOKENS_PATH, self.tokens)

            # Add account
            account = {"id": account_id, "provider": "google", "email": email}
            accounts = [a for a in self.cache.get("accounts", []) if a["id"] != account_id]
            accounts.append(account)
            self.cache["accounts"] = accounts

            # Create provider & discover calendars
            self._create_provider(account)
            provider = self.providers[account_id]
            new_cals = provider.list_calendars()
            existing = [c for c in self.cache.get("calendars", []) if c.get("accountId") != account_id]
            existing.extend(new_cals)
            self.cache["calendars"] = existing

            self._save_cache()
            emit({"type": "auth_complete", "provider": "google", "account": account})
            self._emit_static()
            self._do_sync()
        except Exception as e:
            emit({"type": "auth_error", "message": f"gcalcli import failed: {e}"})

    def _resolve_google_client(self):
        """Get Google OAuth client_id and client_secret.
        Priority: hardcoded constants > gcalcli token > None."""
        if GOOGLE_CLIENT_ID:
            return GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
        # Try to extract from gcalcli token
        if os.path.isfile(GCALCLI_TOKEN_PATH):
            try:
                import pickle
                with open(GCALCLI_TOKEN_PATH, "rb") as f:
                    creds = pickle.load(f)
                if creds.client_id and creds.client_secret:
                    return creds.client_id, creds.client_secret
            except Exception:
                pass
        return None, None

    def _auth_google(self, config_client_id="", config_client_secret=""):
        # Priority: config-provided > hardcoded > gcalcli fallback
        client_id = config_client_id or GOOGLE_CLIENT_ID
        client_secret = config_client_secret or GOOGLE_CLIENT_SECRET
        if not client_id:
            client_id, client_secret = self._resolve_google_client()
        if not client_id:
            emit({"type": "auth_error", "message": "Google OAuth credentials not configured. Enter your Client ID and Secret in settings, or import from gcalcli."})
            return

        try:
            from google_auth_oauthlib.flow import InstalledAppFlow
            flow = InstalledAppFlow.from_client_config(
                {
                    "installed": {
                        "client_id": client_id,
                        "client_secret": client_secret,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": ["http://localhost"],
                    }
                },
                scopes=GOOGLE_SCOPES,
            )
            creds = flow.run_local_server(port=0, open_browser=True)

            # Get user info
            from googleapiclient.discovery import build
            service = build("calendar", "v3", credentials=creds)
            cal_list = service.calendarList().list().execute()
            primary = next((c for c in cal_list.get("items", []) if c.get("primary")), None)
            email = primary["id"] if primary else "unknown"

            account_id = f"google_{email}"
            if self._account_exists(account_id):
                emit({"type": "auth_error", "message": f"Google account {email} is already connected. Remove it first to re-add."})
                return
            # Store tokens with client credentials for refresh
            if "google" not in self.tokens:
                self.tokens["google"] = {}
            self.tokens["google"][account_id] = {
                "access_token": creds.token,
                "refresh_token": creds.refresh_token,
                "client_id": client_id,
                "client_secret": client_secret,
                "token_expiry": creds.expiry.isoformat() if creds.expiry else None,
            }
            save_json(TOKENS_PATH, self.tokens)

            # Add account
            account = {"id": account_id, "provider": "google", "email": email}
            accounts = [a for a in self.cache.get("accounts", []) if a["id"] != account_id]
            accounts.append(account)
            self.cache["accounts"] = accounts

            # Create provider & discover calendars
            self._create_provider(account)
            provider = self.providers[account_id]
            new_cals = provider.list_calendars()
            existing = [c for c in self.cache.get("calendars", []) if c.get("accountId") != account_id]
            existing.extend(new_cals)
            self.cache["calendars"] = existing

            self._save_cache()
            emit({"type": "auth_complete", "provider": "google", "account": account})
            self._emit_static()
            self._do_sync()
        except Exception as e:
            emit({"type": "auth_error", "message": f"Google auth failed: {e}"})

    def _auth_caldav(self, cmd):
        import requests as _requests
        from requests.auth import HTTPBasicAuth

        # Strip ALL whitespace/control characters (including embedded \n from paste)
        url = re.sub(r'\s', '', cmd.get("url") or "")
        username = (cmd.get("user") or "").strip()
        password = cmd.get("pass") or ""

        if not url:
            emit({"type": "auth_error", "message": "CalDAV URL is required"})
            return
        if not username:
            emit({"type": "auth_error", "message": "CalDAV username is required"})
            return

        # Normalise URL: ensure it ends with '/' so that relative paths resolve correctly
        if not url.endswith("/"):
            url += "/"

        # Yandex displays app passwords with spaces for readability (e.g. "abcd efgh …")
        # but the server expects them without spaces.  Strip silently so users can
        # paste directly from the Yandex ID page.
        parsed_host = (urlparse(url).hostname or "").lower()
        if "yandex" in parsed_host:
            password = password.replace(" ", "")
            # Yandex login should not include the domain part
            if "@" in username:
                username = username.split("@")[0]

        try:
            import caldav

            host = parsed_host or "caldav"
            account_id = f"caldav_{host}_{username}"
            if self._account_exists(account_id):
                emit({"type": "auth_error", "message": f"CalDAV account {username}@{host} is already connected. Remove it first to re-add."})
                return

            # Pre-flight: verify credentials with a plain PROPFIND before involving
            # the caldav library, so we can surface a clear 401 message early.
            auth = HTTPBasicAuth(username, password)
            try:
                resp = _requests.request(
                    "PROPFIND", url,
                    auth=auth,
                    headers={"Depth": "0", "Content-Type": "application/xml"},
                    data='<?xml version="1.0"?><D:propfind xmlns:D="DAV:"><D:prop><D:resourcetype/></D:prop></D:propfind>',
                    timeout=15,
                    verify=True,
                )
                if resp.status_code == 401:
                    is_yandex = "yandex" in host
                    hint = (
                        " Make sure you are using an app password (not your main password). "
                        "For Yandex: go to id.yandex.ru → Security → App passwords, "
                        "create a password for 'Mail', paste it WITHOUT spaces, "
                        "and use your Yandex login without @yandex.ru."
                        if is_yandex else
                        " Make sure you are using the correct username and password for this CalDAV server."
                    )
                    emit({"type": "auth_error", "message": f"Authentication failed (401 Unauthorized).{hint}"})
                    return
                if resp.status_code not in (200, 207, 301, 302):
                    emit({"type": "auth_error", "message": f"CalDAV server returned unexpected status {resp.status_code} for {url}"})
                    return
            except _requests.exceptions.SSLError as e:
                emit({"type": "auth_error", "message": f"SSL certificate error connecting to {host}: {e}"})
                return
            except _requests.exceptions.ConnectionError as e:
                emit({"type": "auth_error", "message": f"Cannot connect to {url}: {e}"})
                return
            except _requests.exceptions.Timeout:
                emit({"type": "auth_error", "message": f"Connection to {url} timed out"})
                return

            # Pass auth only via the auth= kwarg; passing username+password alongside
            # auth= can cause double-encoding in some caldav library versions.
            client = caldav.DAVClient(url=url, auth=auth, ssl_verify_cert=True)
            try:
                principal = client.principal()
                principal.calendars()  # verify full CalDAV access
            except Exception as e:
                raise Exception(f"CalDAV connection failed: {e}") from e
            # Use user-supplied name; fall back to "Provider (username)"
            custom_name = (cmd.get("name") or "").strip()
            if custom_name:
                account_name = custom_name
            else:
                provider_name = {
                    "caldav.yandex.ru": "Yandex",
                    "caldav.icloud.com": "iCloud",
                    "dav.fastmail.com": "Fastmail",
                    "caldav.fastmail.com": "Fastmail",
                }.get(host, host.split(".")[0].capitalize() if "." in host else host)
                account_name = f"{provider_name} ({username})"

            if "caldav" not in self.tokens:
                self.tokens["caldav"] = {}
            self.tokens["caldav"][account_id] = {
                "url": url,
                "username": username,
                "password": password,
            }
            save_json(TOKENS_PATH, self.tokens)

            account = {"id": account_id, "provider": "caldav", "name": account_name, "url": url}
            accounts = [a for a in self.cache.get("accounts", []) if a["id"] != account_id]
            accounts.append(account)
            self.cache["accounts"] = accounts

            self._create_provider(account)
            provider = self.providers[account_id]
            new_cals = provider.list_calendars()
            existing = [c for c in self.cache.get("calendars", []) if c.get("accountId") != account_id]
            existing.extend(new_cals)
            self.cache["calendars"] = existing

            self._save_cache()
            emit({"type": "auth_complete", "provider": "caldav", "account": account})
            self._emit_static()
            self._do_sync()
        except Exception as e:
            emit({"type": "auth_error", "message": f"CalDAV auth failed: {e}"})

    def _remove_account(self, account_id):
        with self._lock:
            self.cache["events"] = [e for e in self.cache.get("events", []) if not self._event_belongs_to_account(e, account_id)]
            self.cache["calendars"] = [c for c in self.cache.get("calendars", []) if c.get("accountId") != account_id]
            self.cache["accounts"] = [a for a in self.cache.get("accounts", []) if a["id"] != account_id]
            self.providers.pop(account_id, None)

        # Remove tokens
        for provider_type in ["google", "caldav"]:
            if provider_type in self.tokens:
                self.tokens[provider_type].pop(account_id, None)
        save_json(TOKENS_PATH, self.tokens)

        with self._lock:
            self._save_cache()
        self._emit_static()
        self._emit_events()

    def _event_belongs_to_account(self, event, account_id):
        cal_id = event.get("calendarId", "")
        for cal in self.cache.get("calendars", []):
            if cal["id"] == cal_id and cal.get("accountId") == account_id:
                return True
        return False

    # ── CRUD ──

    def _create_event(self, event):
        cal_id = event.get("calendarId", "")
        provider = self._provider_for_calendar(cal_id)
        if not provider:
            emit({"type": "cmd_result", "cmd": "create", "success": False,
                  "message": f"No provider for calendar {cal_id}"})
            return

        emit({"type": "cmd_start", "cmd": "create"})
        new_id = provider.create_event(event)
        if new_id:
            event["id"] = new_id
            with self._lock:
                self.cache.setdefault("events", []).append(event)
                self._save_cache()
            self._emit_events()
            emit({"type": "cmd_result", "cmd": "create", "success": True})
            # Sync in background to pick up server-side values (e.g. real meetLink
            # after Google processes the conference request asynchronously).
            threading.Thread(target=self._do_sync, daemon=True).start()
        else:
            emit({"type": "cmd_result", "cmd": "create", "success": False,
                  "message": "Failed to save event — check your connection or credentials"})

    def _update_event(self, event):
        cal_id = event.get("calendarId", "")
        provider = self._provider_for_calendar(cal_id)
        if not provider:
            emit({"type": "cmd_result", "cmd": "update", "success": False,
                  "message": f"No provider for calendar {cal_id}"})
            return

        emit({"type": "cmd_start", "cmd": "update"})
        if provider.update_event(event):
            with self._lock:
                events = self.cache.get("events", [])
                for i, e in enumerate(events):
                    if e["id"] == event["id"]:
                        events[i] = event
                        break
                self._save_cache()
            self._emit_events()
            emit({"type": "cmd_result", "cmd": "update", "success": True})
            threading.Thread(target=self._do_sync, daemon=True).start()
        else:
            emit({"type": "cmd_result", "cmd": "update", "success": False,
                  "message": "Failed to update event — check your connection or credentials"})

    def _delete_event(self, calendar_id, event_id):
        provider = self._provider_for_calendar(calendar_id)
        if not provider:
            emit({"type": "cmd_result", "cmd": "delete", "success": False,
                  "message": f"No provider for calendar {calendar_id}"})
            return

        emit({"type": "cmd_start", "cmd": "delete"})
        if provider.delete_event(calendar_id, event_id):
            with self._lock:
                self.cache["events"] = [e for e in self.cache.get("events", []) if e["id"] != event_id]
                self._save_cache()
            self._emit_events()
            emit({"type": "cmd_result", "cmd": "delete", "success": True})
        else:
            emit({"type": "cmd_result", "cmd": "delete", "success": False,
                  "message": "Failed to delete event — check your connection or credentials"})

    def _set_calendar_enabled(self, calendar_id, enabled):
        with self._lock:
            for cal in self.cache.get("calendars", []):
                if cal["id"] == calendar_id:
                    cal["enabled"] = enabled
                    break
            self._save_cache()
        self._emit_static()
        self._emit_events()

    # ── Sync ──

    def _sync_loop(self):
        # Sync immediately on startup so cached data (e.g. meetLinks) is refreshed
        # right away rather than waiting a full sync_interval before first fetch.
        self._do_sync()
        while not self._stop.wait(self.sync_interval * 60):
            self._do_sync()

    def _do_sync(self):
        emit({"type": "sync_status", "syncing": True})
        now = datetime.now().astimezone()
        time_min = (now - timedelta(days=30)).isoformat(timespec="seconds")
        time_max = (now + timedelta(days=90)).isoformat(timespec="seconds")

        all_events = []

        with self._lock:
            calendars_snapshot = list(self.cache.get("calendars", []))

        for cal in calendars_snapshot:
            if not cal.get("enabled", True):
                continue
            provider = self.providers.get(cal.get("accountId"))
            if not provider:
                continue
            try:
                events = provider.fetch_events(cal["id"], time_min, time_max)
                all_events.extend(events)
            except Exception as e:
                emit({"type": "error", "message": f"Sync error for {cal['name']}: {e}"})

        with self._lock:
            self.cache["events"] = all_events
            self.cache["last_sync"] = iso_now()
            self._save_cache()
        self._emit_events()
        emit({"type": "sync_status", "syncing": False})

    # ── Notifications ──

    def _notify_loop(self):
        while not self._stop.wait(5):  # check every 5 seconds for near-minute accuracy
            self._check_notifications()

    def _check_notifications(self):
        now = datetime.now().astimezone()
        past_cutoff = now - timedelta(days=1)

        with self._lock:
            events_snapshot = list(self.cache.get("events", []))
            # Prune keys whose start time is more than 1 day in the past so
            # the set doesn't grow unbounded over a long session.
            def _key_start(key):
                parts = key.split(":", 2)
                return parts[1] if len(parts) >= 2 else ""

            stale = set()
            for key in self._notified:
                start_str = _key_start(key)
                if not start_str:
                    stale.add(key)
                    continue
                try:
                    s = datetime.fromisoformat(start_str)
                    if s.tzinfo is None:
                        s = s.astimezone()
                    if s < past_cutoff:
                        stale.add(key)
                except (ValueError, TypeError):
                    stale.add(key)
            self._notified -= stale
            notified_snapshot = set(self._notified)

        to_remind = []   # (event, key) — reminder before start
        to_arrive = []   # (event, key) — event starting right now

        for event in events_snapshot:
            event_id = event.get("id", "")
            start_str = event.get("start", "")
            if not start_str or event.get("allDay"):
                continue
            try:
                start = datetime.fromisoformat(start_str)
                if start.tzinfo is None:
                    start = start.astimezone()
            except (ValueError, TypeError):
                continue

            # ── Arrival: event starts within the next 60 seconds ────────────
            arrive_key = f"{event_id}:{start_str}:arrive"
            if arrive_key not in notified_snapshot:
                if start <= now < start + timedelta(minutes=1):
                    to_arrive.append((event, arrive_key))

            # ── Reminder: N minutes before start ─────────────────────────────
            reminder = event.get("reminder", 0)
            if reminder > 0:
                remind_key = f"{event_id}:{start_str}:reminder"
                if remind_key not in notified_snapshot:
                    notify_time = start - timedelta(minutes=reminder)
                    if notify_time <= now < start:
                        to_remind.append((event, remind_key))

        for event, key in to_remind:
            self._send_notification(event, arrive=False)
            with self._lock:
                self._notified.add(key)
                self._save_notified()
            emit({"type": "notify", "event": event})

        for event, key in to_arrive:
            self._send_notification(event, arrive=True)
            with self._lock:
                self._notified.add(key)
                self._save_notified()
            emit({"type": "notify_arrive", "event": event})

    def _send_notification(self, event, arrive=False):
        """Send a D-Bus desktop notification for *event*.

        arrive=True  → event is starting right now: critical urgency, attention sound.
        arrive=False → advance reminder N min before start: normal urgency, gentle sound.

        Sound plays for BOTH types when sound_on_arrival is enabled, so the user
        actually hears *something* regardless of which window fires first.
        """
        title = event.get("title", "Calendar Event")
        start = event.get("start", "")
        meet_link = (event.get("meetLink") or "").strip()
        location = (event.get("location") or "").strip()

        try:
            time_str = datetime.fromisoformat(start).strftime("%H:%M")
        except (ValueError, TypeError):
            time_str = start or "?"

        if arrive:
            body = "Starting now"
            urgency = "critical"
        else:
            reminder = event.get("reminder", 0)
            body = f"In {reminder} min — starting at {time_str}" if reminder else f"Starting at {time_str}"
            urgency = "normal"

        # D-Bus sound hint — the notification daemon (dunst, mako, swaync …) plays
        # the named sound from the current XDG theme.  This is the correct way to
        # request sounds per the freedesktop Notification spec; no separate process needed.
        sound_id = ("complete" if self.sound_on_arrival else "message-new-instant") if arrive else "message-new-instant"
        custom_sound = self.arrival_sound_path if (arrive and self.sound_on_arrival) else ""
        # Build notify-send command.  Action buttons require libnotify >= 1.8 /
        # dunst / mako with action support.  When present, notify-send BLOCKS
        # and writes the clicked action key to stdout — so we must run it in a
        # separate thread and react to the output there.
        cmd = ["notify-send", "-a", "Ambxst Calendar", "-i", "x-office-calendar",
               "-u", urgency,
               "--hint", f"string:sound-name:{sound_id}",
               title, body]
        # Also pass sound-file hint so daemons that support it use the exact file
        if custom_sound and os.path.exists(custom_sound):
            cmd += ["--hint", f"string:sound-file:{custom_sound}"]

        # Map action key → URL to open.  Only validated https:// URLs are included.
        action_map = {}
        if meet_link and meet_link.startswith("https://") and meet_link != "request":
            cmd += ["--action", "meet=Join Meet"]
            action_map["meet"] = meet_link
        if location:
            if location.startswith("http://") or location.startswith("https://"):
                cmd += ["--action", "location=Open Location"]
                action_map["location"] = location
            else:
                # Plain text address — map to a Google Maps search
                import urllib.parse
                maps_url = "https://maps.google.com/maps?q=" + urllib.parse.quote(location)
                cmd += ["--action", "location=Open Location"]
                action_map["location"] = maps_url

        def _run_and_handle(cmd, action_map):
            """Block until the user dismisses the notification, then open any URL."""
            try:
                result = subprocess.run(
                    cmd, capture_output=True, text=True,
                    timeout=300,  # 5 minutes — plenty of time to act on a reminder
                )
                clicked = result.stdout.strip()
                url = action_map.get(clicked)
                if url:
                    subprocess.run(["xdg-open", url],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   timeout=10)
            except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
                pass
            except Exception:
                pass

        # Always run in a daemon thread so the notification loop is never blocked.
        t = threading.Thread(target=_run_and_handle, args=(cmd, action_map), daemon=True)
        t.start()

        # Always play a sound.  For arrivals, soundOnArrival controls whether
        # the sound is the attention-grabbing variant (urgent=True) or the same
        # gentle tone used for reminders.  Reminders are always gentle.
        if arrive:
            custom = self.arrival_sound_path if self.sound_on_arrival else ""
            self._play_sound(custom, urgent=self.sound_on_arrival)
        else:
            self._play_sound("", urgent=False)

    # ── Helpers ──

    def _provider_for_calendar(self, calendar_id):
        with self._lock:
            calendars = list(self.cache.get("calendars", []))
        for cal in calendars:
            if cal["id"] == calendar_id:
                return self.providers.get(cal.get("accountId"))
        return None

    def _save_cache(self):
        save_json(CACHE_PATH, self.cache)

    def _save_notified(self):
        """Persist _notified set so process restarts don't re-fire today's alerts.
        Called under self._lock — must not acquire it again.
        """
        save_json(NOTIFIED_PATH, list(self._notified))

    def _emit_static(self):
        with self._lock:
            accounts = list(self.cache.get("accounts", []))
            calendars = list(self.cache.get("calendars", []))
        emit({"type": "static", "accounts": accounts, "calendars": calendars})

    def _emit_events(self):
        with self._lock:
            enabled_cals = {c["id"] for c in self.cache.get("calendars", []) if c.get("enabled", True)}
            events = [e for e in self.cache.get("events", []) if e.get("calendarId") in enabled_cals]
        emit({"type": "events", "data": events})

    def stop(self):
        self._stop.set()

    # ── Sound ────────────────────────────────────────────────────────

    # Soft: gentle reminder a few minutes before.
    _REMINDER_CANBERRA_IDS = ("message-new-instant", "complete", "message", "bell")
    _REMINDER_FALLBACK_SOUNDS = [
        BUNDLED_SOUND,
        "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga",
        "/usr/share/sounds/freedesktop/stereo/complete.oga",
        "/usr/share/sounds/freedesktop/stereo/message.oga",
        "/usr/share/sounds/freedesktop/stereo/dialog-information.oga",
        "/usr/share/sounds/sound-icons/prompt.wav",
        "/usr/share/sounds/alsa/Front_Center.wav",
    ]
    # Urgent: event is starting right now — use theme's alarm/warning sounds first.
    _ARRIVAL_CANBERRA_IDS = ("complete", "message-new-instant", "bell")
    _ARRIVAL_FALLBACK_SOUNDS = [
        "/usr/share/sounds/freedesktop/stereo/complete.oga",
        BUNDLED_SOUND,
        "/usr/share/sounds/freedesktop/stereo/complete.oga",
        "/usr/share/sounds/sound-icons/prompt.wav",
        "/usr/share/sounds/alsa/Front_Center.wav",
    ]

    def _play_sound(self, path=None, urgent=False):
        """Play a notification sound asynchronously.

        If *path* is provided and exists, play it directly.
        Otherwise try named-sound players (canberra, theme-aware) then
        file-based fallbacks.  *urgent=True* picks a more attention-grabbing
        sound suitable for "event starting now" notifications.
        """
        custom = path.strip() if path else ""
        canberra_ids = self._ARRIVAL_CANBERRA_IDS if urgent else self._REMINDER_CANBERRA_IDS
        fallback_sounds = self._ARRIVAL_FALLBACK_SOUNDS if urgent else self._REMINDER_FALLBACK_SOUNDS

        def _try_play():
            # ── 1. Custom file supplied by user ─────────────────────────
            if custom and os.path.exists(custom):
                for player in ("paplay", "pw-play", "aplay", "ffplay"):
                    try:
                        r = subprocess.run(
                            [player, custom] if player != "ffplay"
                            else ["ffplay", "-nodisp", "-autoexit", custom],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            timeout=15,
                        )
                        if r.returncode == 0:
                            return
                    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                        continue

            # ── 2. canberra-gtk-play — uses the current GTK/desktop sound theme,
            #       no file path required; most reliable on modern Linux desktops.
            for sound_id in canberra_ids:
                try:
                    env = dict(os.environ)
                    # canberra needs a display; prefer Wayland, fall back to X11
                    if "DISPLAY" not in env and "WAYLAND_DISPLAY" not in env:
                        env.setdefault("DISPLAY", ":0")
                    r = subprocess.run(
                        ["canberra-gtk-play", f"--id={sound_id}"],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        timeout=10, env=env,
                    )
                    if r.returncode == 0:
                        return
                except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                    break  # canberra not installed — fall through to file-based

            # ── 3. File-based fallbacks ──────────────────────────────────
            sound_file = next(
                (p for p in fallback_sounds if os.path.exists(p)), None
            )
            if not sound_file:
                return
            for player in ("paplay", "pw-play", "aplay"):
                try:
                    r = subprocess.run(
                        [player, sound_file],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                        timeout=15,
                    )
                    if r.returncode == 0:
                        return
                except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
                    continue

        threading.Thread(target=_try_play, daemon=True).start()


# ── Main ──────────────────────────────────────────────────────────

def main():
    # argv: sync_interval default_reminder sound_on_arrival arrival_sound_path blink_on_arrival
    def _int_arg(idx, default, lo=None, hi=None):
        try:
            v = int(sys.argv[idx]) if len(sys.argv) > idx else default
            if lo is not None: v = max(lo, v)
            if hi is not None: v = min(hi, v)
            return v
        except (ValueError, OverflowError):
            return default

    sync_interval      = _int_arg(1, 15, lo=1, hi=1440)
    default_reminder   = _int_arg(2, 15, lo=0, hi=1440)
    sound_on_arrival   = (sys.argv[3].lower() not in ("0", "false")) if len(sys.argv) > 3 else True
    arrival_sound_path = sys.argv[4] if len(sys.argv) > 4 else ""
    blink_on_arrival   = (sys.argv[5].lower() not in ("0", "false")) if len(sys.argv) > 5 else True

    service = CalendarService(
        sync_interval=sync_interval,
        default_reminder=default_reminder,
        sound_on_arrival=sound_on_arrival,
        arrival_sound_path=arrival_sound_path,
        blink_on_arrival=blink_on_arrival,
    )

    def handle_signal(signum, frame):
        service.stop()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    service.run()


if __name__ == "__main__":
    main()
