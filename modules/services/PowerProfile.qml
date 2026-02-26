
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme

Singleton {
    id: root

    property var    availableProfiles: []
    property string currentProfile:    ""
    property bool   isAvailable:       false
    property string backendType:       "" // "powerprofilesctl" | "tlp"

    signal profileChanged(string profile)

    // ── Internal state ───────────────────────────────────────
    property bool   _isSettingProfile: false
    property string _pendingProfile:   ""
    // Tracks the target of an in-flight set; used to discard
    // stale reads that arrive before the backend has applied
    // the new profile.
    property string _expectedProfile:  ""
    // Distinguishes initial getProc call (should trigger listProc)
    // from rollback reads (should not re-run listProc).
    property bool   _initialLoad:      true

    Component.onCompleted: {
        console.info("PowerProfile: service starting");
        checkPowerProfilesCtl.running = true;
    }

    // ── Backend detection ─────────────────────────────────────

    // Primary: powerprofilesctl
    // Uses bash wrapper so the Process always exits cleanly even
    // when the binary is absent — a bare exec would crash silently
    // and onExited would never fire, swallowing the TLP fallback.
    Process {
        id: checkPowerProfilesCtl
        workingDirectory: "/"
        command: ["bash", "-c", "command -v powerprofilesctl"]
        running: false
        stdout: SplitParser {}
        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("PowerProfile: powerprofilesctl detected");
                backendType = "powerprofilesctl";
                isAvailable  = true;
                _initialLoad = true;
                getProc.running = true; // listProc follows in getProc.onExited
            } else {
                console.info("PowerProfile: powerprofilesctl not found, trying tlp…");
                checkTLP.running = true;
            }
        }
    }

    // Fallback: tlp / tlpctl
    // "command -v tlp" only — tlp --version may require root on
    // some distributions and would return non-zero even when tlp
    // is installed, producing a false-negative detection.
    Process {
        id: checkTLP
        workingDirectory: "/"
        command: ["bash", "-c", "command -v tlp"]
        running: false
        stdout: SplitParser {}
        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("PowerProfile: tlp detected");
                backendType       = "tlp";
                isAvailable       = true;
                availableProfiles = ["power-saver", "balanced", "performance"];
                getTLPProc.running = true;
            } else {
                console.warn("PowerProfile: no supported power management backend found");
                isAvailable = false;
            }
        }
    }

    // ── powerprofilesctl: read current profile ────────────────

    Process {
        id: getProc
        workingDirectory: "/"
        command: ["powerprofilesctl", "get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const profile = data.trim();
                if (!profile) return;
                // Discard stale reads that arrive while a set is
                // in-flight and the backend has not yet applied it.
                if (_isSettingProfile && profile !== _expectedProfile) {
                    console.info("PowerProfile: discarding stale read '" + profile +
                                 "', expected '" + _expectedProfile + "'");
                    return;
                }
                console.info("PowerProfile: current profile →", profile);
                currentProfile = profile;
                profileChanged(profile);
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("PowerProfile: powerprofilesctl get failed (exit " + exitCode + ")");
            // Trigger profile listing only on initial load, not on
            // rollback reads — avoids redundant listProc executions.
            if (backendType === "powerprofilesctl" && _initialLoad && !listProc.running) {
                _initialLoad      = false;
                listProc.fullOutput = "";
                listProc.running    = true;
            }
        }
    }

    // ── powerprofilesctl: list available profiles ─────────────

    Process {
        id: listProc
        workingDirectory: "/"
        command: ["bash", "-c", "powerprofilesctl list 2>&1"]
        running: false
        property string fullOutput: ""

        stdout: SplitParser {
            onRead: data => { listProc.fullOutput += data + "\n"; }
        }
        onExited: exitCode => {
            if (exitCode === 0 && fullOutput.trim().length > 0) {
                const lines    = fullOutput.split('\n');
                const profiles = [];
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.endsWith(':')) {
                        const name = line.replace('*', '').replace(':', '').trim();
                        if (name && profiles.indexOf(name) === -1)
                            profiles.push(name);
                    }
                }
                const order = ["power-saver", "balanced", "performance"];
                profiles.sort((a, b) => {
                    const ia = order.indexOf(a), ib = order.indexOf(b);
                    if (ia === -1) return  1;
                    if (ib === -1) return -1;
                    return ia - ib;
                });
                availableProfiles = profiles.length > 0
                    ? profiles
                    : ["power-saver", "balanced", "performance"];
                console.info("PowerProfile: available profiles →", availableProfiles);
            } else {
                // Keep powerprofilesctl as backend; just use safe defaults.
                console.warn("PowerProfile: powerprofilesctl list failed, using defaults");
                availableProfiles = ["power-saver", "balanced", "performance"];
            }
            fullOutput = "";
        }
    }

    // ── tlp: read current profile ─────────────────────────────

    Process {
        id: getTLPProc
        workingDirectory: "/"
        command: ["/sbin/tlpctl", "get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line) return;
                console.info("PowerProfile: tlpctl get →", line);
                let profile = "";
                if      (line.includes("power-saver") || line.includes("powersaver")) profile = "power-saver";
                else if (line.includes("balanced"))                                    profile = "balanced";
                else if (line.includes("performance"))                                 profile = "performance";
                if (!profile) return;
                if (_isSettingProfile && profile !== _expectedProfile) {
                    console.info("PowerProfile: discarding stale tlp read '" + profile +
                                 "', expected '" + _expectedProfile + "'");
                    return;
                }
                if (currentProfile !== profile) {
                    currentProfile = profile;
                    console.info("PowerProfile: current profile →", profile);
                    profileChanged(profile);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("PowerProfile: tlpctl get failed (exit " + exitCode + ")");
        }
    }

    // ── Set profile ───────────────────────────────────────────

    Process {
        id: setProc
        workingDirectory: "/"
        running: false
        stdout: SplitParser {}
        stderr: SplitParser {
            onRead: data => {
                const err = data.trim();
                if (err) console.warn("PowerProfile: stderr:", err);
            }
        }
        onExited: exitCode => {
            _isSettingProfile = false;
            if (exitCode === 0) {
                console.info("PowerProfile: profile applied successfully");
                // Reset expected so subsequent reads are no longer filtered.
                _expectedProfile = "";
                // Process next queued request if any.
                if (_pendingProfile !== "") {
                    const next     = _pendingProfile;
                    _pendingProfile = "";
                    setProfile(next);
                }
                // No confirmation read needed — optimistic update is correct.
                // A confirmation read issued immediately after set would race
                // against the backend applying the change and return stale data.
            } else {
                console.warn("PowerProfile: failed to apply profile (exit " + exitCode + ")");
                _pendingProfile  = "";
                _expectedProfile = "";
                // Rollback: sync currentProfile from actual backend state.
                Qt.callLater(() => {
                    if (backendType === "powerprofilesctl") {
                        if (!getProc.running) getProc.running = true;
                    } else if (backendType === "tlp") {
                        if (!getTLPProc.running) getTLPProc.running = true;
                    }
                });
            }
        }
    }

    // ── Public API ────────────────────────────────────────────

    function updateCurrentProfile() {
        if (!isAvailable || _isSettingProfile) return;
        if (backendType === "powerprofilesctl") {
            if (!getProc.running)    getProc.running    = true;
        } else if (backendType === "tlp") {
            if (!getTLPProc.running) getTLPProc.running = true;
        }
    }

    function updateAvailableProfiles() {
        if (!isAvailable) return;
        if (backendType === "powerprofilesctl" && !listProc.running) {
            availableProfiles   = [];
            listProc.fullOutput = "";
            listProc.running    = true;
        }
        // tlp profiles are static; no refresh needed.
    }

    function setProfile(profileName) {
        if (!isAvailable) {
            console.warn("PowerProfile: service not available");
            return;
        }
        if (availableProfiles.indexOf(profileName) === -1) {
            console.warn("PowerProfile: unknown profile '" + profileName + "'");
            return;
        }
        if (_isSettingProfile || setProc.running) {
            console.info("PowerProfile: queuing '" + profileName + "' (set in progress)");
            _pendingProfile = profileName;
            return;
        }
        console.info("PowerProfile: applying '" + profileName + "' via " + backendType);
        _isSettingProfile = true;
        _expectedProfile  = profileName;
        // Optimistic update so the UI reflects the change immediately.
        currentProfile = profileName;
        profileChanged(profileName);
        if (backendType === "powerprofilesctl")
            setProc.command = ["powerprofilesctl", "set", profileName];
        else if (backendType === "tlp")
            setProc.command = ["/sbin/tlpctl", "set", profileName];
        setProc.running = true;
    }

    // ── Helpers ───────────────────────────────────────────────

    function getProfileIcon(profileName) {
        if (profileName === "power-saver") return Icons.powerSave;
        if (profileName === "balanced")    return Icons.balanced;
        if (profileName === "performance") return Icons.performance;
        return Icons.balanced;
    }

    function getProfileDisplayName(profileName) {
        if (profileName === "power-saver") return "Power Save";
        if (profileName === "balanced")    return "Balanced";
        if (profileName === "performance") return "Performance";
        return profileName;
    }
}
