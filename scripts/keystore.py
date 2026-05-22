#!/usr/bin/env python3
import sqlite3
import json
import sys
import os
from pathlib import Path


def get_machine_id():
    try:
        with open("/etc/machine-id", "r") as f:
            return f.read().strip().encode("utf-8")
    except Exception:
        return b"ambxst-fallback-salt-82741"


def xor_crypt(data, key):
    return bytes([b ^ key[i % len(key)] for i, b in enumerate(data)])


def encrypt(text, key):
    encrypted = xor_crypt(text.encode("utf-8"), key)
    return encrypted.hex()


def decrypt(hex_str, key):
    try:
        encrypted = bytes.fromhex(hex_str)
        return xor_crypt(encrypted, key).decode("utf-8")
    except Exception:
        return ""


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "Usage: <db_path> <cmd> [args...]"}), flush=True)
        sys.exit(1)

    db_path = Path(os.path.expanduser(sys.argv[1]))
    cmd = sys.argv[2]
    args = sys.argv[3:]

    # Ensure parent directory exists
    db_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        conn = sqlite3.connect(str(db_path))
        # Secure the file
        os.chmod(str(db_path), 0o600)

        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS api_keys (
                provider TEXT PRIMARY KEY,
                api_key TEXT NOT NULL,
                endpoint TEXT DEFAULT '',
                custom_curl TEXT DEFAULT ''
            )
        """)
        conn.commit()

        machine_key = get_machine_id()

        if cmd == "set":
            if len(args) < 2:
                print(
                    json.dumps(
                        {
                            "error": "set requires <provider> <key> [endpoint] [custom_curl]"
                        }
                    ),
                    flush=True,
                )
                sys.exit(1)

            provider = args[0]
            api_key = encrypt(args[1], machine_key)
            endpoint = args[2] if len(args) > 2 else ""
            custom_curl = args[3] if len(args) > 3 else ""

            cursor.execute(
                "INSERT OR REPLACE INTO api_keys VALUES (?, ?, ?, ?)",
                (provider, api_key, endpoint, custom_curl),
            )
            conn.commit()
            print(json.dumps({"status": "ok"}), flush=True)

        elif cmd == "get":
            if not args:
                print(json.dumps({"error": "get requires <provider>"}), flush=True)
                sys.exit(1)

            cursor.execute("SELECT * FROM api_keys WHERE provider = ?", (args[0],))
            row = cursor.fetchone()
            if row:
                res = {
                    "provider": row[0],
                    "api_key": decrypt(row[1], machine_key),
                    "endpoint": row[2],
                    "custom_curl": row[3],
                }
                print(json.dumps(res), flush=True)
            else:
                print(
                    json.dumps({"error": f"Provider '{args[0]}' not found"}), flush=True
                )
                sys.exit(1)

        elif cmd == "delete":
            if not args:
                print(json.dumps({"error": "delete requires <provider>"}), flush=True)
                sys.exit(1)
            cursor.execute("DELETE FROM api_keys WHERE provider = ?", (args[0],))
            conn.commit()
            print(json.dumps({"status": "ok"}), flush=True)

        elif cmd == "list":
            cursor.execute("SELECT * FROM api_keys")
            rows = cursor.fetchall()
            results = []
            for row in rows:
                results.append(
                    {
                        "provider": row[0],
                        "api_key": decrypt(row[1], machine_key),
                        "endpoint": row[2],
                        "custom_curl": row[3],
                    }
                )
            print(json.dumps(results), flush=True)

        elif cmd == "has":
            if not args:
                print(json.dumps({"error": "has requires <provider>"}), flush=True)
                sys.exit(1)
            cursor.execute("SELECT 1 FROM api_keys WHERE provider = ?", (args[0],))
            print(json.dumps(cursor.fetchone() is not None), flush=True)

        else:
            print(json.dumps({"error": f"Unknown command: {cmd}"}), flush=True)
            sys.exit(1)

        conn.close()

    except Exception as e:
        print(json.dumps({"error": str(e)}), flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
