import os
import sys
import json
import time

def scan_vault(vault_path):
    if not os.path.exists(vault_path):
        return {"order": [], "notes": {}}

    notes_data = {}
    order = []
    
    # Scan for markdown files
    for root, _, files in os.walk(vault_path):
        for file in files:
            if file.endswith('.md'):
                file_path = os.path.join(root, file)
                
                # Use filename without extension as title and ID
                title = file[:-3]
                note_id = title # Using title as ID for easier reading in QML
                
                try:
                    stats = os.stat(file_path)
                    created = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(stats.st_ctime))
                    modified = time.strftime('%Y-%m-%dT%H:%M:%S.000Z', time.gmtime(stats.st_mtime))
                    
                    notes_data[note_id] = {
                        "id": note_id,
                        "title": title,
                        "created": created,
                        "modified": modified,
                        "isMarkdown": True
                    }
                    order.append(note_id)
                except Exception:
                    continue

    # Sort order by modified date descending (newest first)
    order.sort(key=lambda x: notes_data[x]["modified"], reverse=True)

    return {"order": order, "notes": notes_data}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"order": [], "notes": {}}))
        sys.exit(1)
        
    vault_path = sys.argv[1]
    result = scan_vault(vault_path)
    print(json.dumps(result))
