{
  perSystem = { inputs', self', pkgs, ... }: {
    packages.ambxst-cli = pkgs.writeShellApplication {
      name = "ambxst";
      
      runtimeInputs = [
        inputs'.quickshell.packages.default 
        self'.packages.ambxst              
        pkgs.jq                            
        pkgs.procps                        
        pkgs.gawk                          
        pkgs.libnotify                     
        pkgs.hyprland                      
      ];
      
      text = ''
        # Ambxst CLI
        
        # Configuration
        QS_BIN="ambxst-shell"
        # shellcheck disable=SC2034
        BRIGHTNESS_SAVE_FILE="/tmp/ambxst_brightness_saved.txt"

        find_ambxst_pid() {
            # Nix wrappers often rename the binary to .quickshell-wrapped
            # We look for the process that has 'shell.qml' in its arguments
            local pid
            pid=$(pgrep -f "shell.qml" | head -1)
            
            # Fallback: look for the common Nix wrapper names
            if [ -z "''${pid}" ]; then
                pid=$(pgrep -f ".quickshell-wrapped" | head -1)
            fi
            
            echo "''${pid}"
        }

        case "''${1:-}" in
            lock)
                PID=$(find_ambxst_pid)
                if [ -z "''${PID}" ]; then 
                    echo "Error: Ambxst process not found. (Looked for shell.qml or .quickshell-wrapped)"
                    exit 1
                fi
                echo "Found Ambxst PID: ''${PID}"
                "''${QS_BIN}" ipc --pid "''${PID}" call lockscreen lock
                ;;
            brightness)
                PID=$(find_ambxst_pid)
                if [ -z "''${PID}" ]; then 
                    echo "Error: Ambxst process not found."
                    exit 1 
                fi
                
                ARG2="''${2:-}"
                ARG3="''${3:-}"
                
                if [ "''${ARG2}" = "-l" ]; then
                    hyprctl monitors -j | jq -r '.[] | "  \(.name)"'
                    exit 0
                fi

                if [[ "''${ARG2}" =~ ^[+-][0-9]+$ ]]; then
                    NORMALIZED=$(awk "BEGIN {printf \"%.2f\", ''${ARG2} / 100}")
                    "''${QS_BIN}" ipc --pid "''${PID}" call brightness adjust "''${NORMALIZED}" "''${ARG3}"
                elif [[ "''${ARG2}" =~ ^[0-9]+$ ]]; then
                    NORMALIZED=$(awk "BEGIN {printf \"%.2f\", ''${ARG2} / 100}")
                    "''${QS_BIN}" ipc --pid "''${PID}" call brightness set "''${NORMALIZED}" "''${ARG3}"
                fi
                ;;
            "")
                echo "Launching Ambxst..."
                exec "''${QS_BIN}"
                ;;
            *)
                echo "Usage: ambxst [lock | brightness <val>]"
                exit 1
                ;;
        esac
      '';
    };
  };
}
