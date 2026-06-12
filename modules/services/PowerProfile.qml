pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.theme

Singleton {
    id: root

    property var availableProfiles: []
    property string currentProfile: ""
    property bool isAvailable: false
    property string backendType: "" // "powerprofilesctl" atau "tlp"

    signal profileChanged(string profile)

    Timer {
        id: startupDelay
        interval: 2000
        running: true
        onTriggered: initialize()
    }

    property bool _initialized: false

    function initialize() {
        if (_initialized) return;
        _initialized = true;
        console.info("PowerProfile: Component initialized");
        checkPowerProfilesCtl.running = true;
    }

    // ============================================
    // POWERPROFILESCTL CHECK
    // ============================================
    Process {
        id: checkPowerProfilesCtl
        workingDirectory: "/"
        command: ["powerprofilesctl", "version"]
        running: false
        stdout: SplitParser {}

        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("PowerProfile: powerprofilesctl detected");
                backendType = "powerprofilesctl";
                isAvailable = true;

                // Delay untuk ensure process ready
                Qt.callLater(() => {
                    console.info("PowerProfile: Getting profiles...");
                    getProc.running = true;
                });

                Qt.callLater(() => {
                    console.info("PowerProfile: Listing profiles...");
                    listProc.running = true;
                }, 100);
            } else {
                console.info("PowerProfile: powerprofilesctl not available, trying tlp...");
                checkTLP.running = true;
            }
        }
    }

    // ============================================
    // TLP CHECK (FALLBACK)
    // ============================================
    Process {
        id: checkTLP
        workingDirectory: "/"
        command: ["/sbin/tlp", "--version"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const output = data.trim();
                if (output && output.length > 0) {
                    console.info("PowerProfile: " + output);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("PowerProfile: ✓ TLP detected");
                backendType = "tlp";
                isAvailable = true;
                availableProfiles = ["power-saver", "balanced", "performance"];
                getTLPProc.running = true;
            } else {
                console.warn("PowerProfile: Neither powerprofilesctl nor tlp available");
                isAvailable = false;
            }
        }
    }

    // ============================================
    // POWERPROFILESCTL - Get current profile
    // ============================================
    Process {
        id: getProc
        workingDirectory: "/"
        command: ["powerprofilesctl", "get"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const profile = data.trim();
                if (profile && profile.length > 0) {
                    console.info("PowerProfile: Current profile:", profile);
                    currentProfile = profile;
                    profileChanged(profile);
                }
            }
        }
    }

    // ============================================
    // POWERPROFILESCTL - List available profiles
    // ============================================
    Process {
        id: listProc
        workingDirectory: "/"
        command: ["bash", "-c", "powerprofilesctl list 2>&1"]
        running: false

        property string fullOutput: ""

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                listProc.fullOutput += data + "\n";
            }
        }

        onExited: exitCode => {
            console.info("PowerProfile: listProc exit code:", exitCode);

            if (exitCode === 0 && fullOutput.trim().length > 0) {
                console.info("PowerProfile: Full output:", fullOutput);
                const lines = fullOutput.split('\n');
                const profiles = [];

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (line.endsWith(':')) {
                        const profileName = line.replace('*', '').replace(':', '').trim();
                        if (profileName && profileName.length > 0 && profiles.indexOf(profileName) === -1) {
                            profiles.push(profileName);
                        }
                    }
                }

                const order = ["power-saver", "balanced", "performance"];
                profiles.sort((a, b) => {
                    const indexA = order.indexOf(a);
                    const indexB = order.indexOf(b);
                    if (indexA === -1)
                        return 1;
                    if (indexB === -1)
                        return -1;
                    return indexA - indexB;
                });

                availableProfiles = profiles;
                console.info("PowerProfile: powerprofilesctl profiles loaded:", availableProfiles);
            } else {
                // Fallback ke TLP jika powerprofilesctl gagal
                console.warn("PowerProfile: powerprofilesctl list failed, falling back to TLP...");
                backendType = "";
                isAvailable = false;
                checkTLP.running = true;
            }
            fullOutput = "";
        }
    }

    // ============================================
    // TLP - Get current profile
    // ============================================
    Process {
        id: getTLPProc
        workingDirectory: "/"
        command: ["bash", "-c", "/sbin/tlp-stat -p 2>/dev/null | grep -i 'Active profile' | head -1"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                console.info("PowerProfile: tlp-stat output:", line);
                let profile = "";

                if (line.includes("power-saver") || line.includes("powersaver")) {
                    profile = "power-saver";
                } else if (line.includes("balanced")) {
                    profile = "balanced";
                } else if (line.includes("performance")) {
                    profile = "performance";
                }

                if (profile && currentProfile !== profile) {
                    currentProfile = profile;
                    console.info("PowerProfile: ✓ Current profile set to:", profile);
                    profileChanged(profile);
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PowerProfile: Failed to get TLP profile");
            }
        }
    }

    // ============================================
    // SET PROFILE - Support both backends
    // ============================================
    Process {
        id: setProc
        workingDirectory: "/"
        running: false
        stdout: SplitParser {}
        stderr: SplitParser {
            onRead: data => {
                const err = data.trim();
                if (err && err.length > 0) {
                    console.warn("PowerProfile: Error:", err);
                }
            }
        }

        onExited: exitCode => {
            if (exitCode === 0) {
                console.info("PowerProfile: Profile changed successfully");
                Qt.callLater(() => {
                    if (backendType === "powerprofilesctl") {
                        getProc.running = true;
                    } else if (backendType === "tlp") {
                        getTLPProc.running = true;
                    }
                });
            } else {
                console.warn("PowerProfile: Failed to set profile");
            }
        }
    }

    function updateCurrentProfile() {
        if (!isAvailable)
            return;

        if (backendType === "powerprofilesctl") {
            getProc.running = true;
        } else if (backendType === "tlp") {
            getTLPProc.running = true;
        }
    }

    function updateAvailableProfiles() {
        if (!isAvailable)
            return;

        if (backendType === "powerprofilesctl") {
            availableProfiles = [];
            listProc.running = true;
        } else if (backendType === "tlp") {
            // TLP profiles sudah hardcoded
            console.info("PowerProfile: Available profiles:", availableProfiles);
        }
    }

    function setProfile(profileName) {
        if (!isAvailable) {
            console.warn("PowerProfile: Cannot set profile - service not available");
            return;
        }

        let found = false;
        for (let i = 0; i < availableProfiles.length; i++) {
            if (availableProfiles[i] === profileName) {
                found = true;
                break;
            }
        }

        if (!found) {
            console.warn("PowerProfile: Profile not available:", profileName);
            return;
        }

        console.info("PowerProfile: Setting profile to:", profileName, "using", backendType);

        currentProfile = profileName;
        console.info("PowerProfile: ✓ UI updated to:", profileName);

        if (backendType === "powerprofilesctl") {
            setProc.command = ["powerprofilesctl", "set", profileName];
        } else if (backendType === "tlp") {
            setProc.command = ["sudo", "/sbin/tlp", profileName];
        }

        setProc.running = true;
    }

    function getProfileIcon(profileName) {
        if (profileName === "power-saver")
            return Icons.powerSave;
        if (profileName === "balanced")
            return Icons.balanced;
        if (profileName === "performance")
            return Icons.performance;
        return Icons.balanced;
    }

    function getProfileDisplayName(profileName) {
        if (profileName === "power-saver")
            return "Power Save";
        if (profileName === "balanced")
            return "Balanced";
        if (profileName === "performance")
            return "Performance";
        return profileName;
    }
}
