pragma Singleton
pragma ComponentBehavior: Bound

import QtQml.Models
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.config

Singleton {
    id: root

    // --- Properties ---
    property var trackedPlayer: null
    property var filteredPlayers: {
        const filtered = Mpris.players.values.filter(player => {
            const dbusName = (player.dbusName || "").toLowerCase();
            if (!Config.bar.enableFirefoxPlayer && dbusName.includes("firefox")) {
                return false;
            }
            return true;
        });
        return filtered;
    }

    property var activePlayer: trackedPlayer ? trackedPlayer : (filteredPlayers.length > 0 ? filteredPlayers[0] : null)
    
    property bool isInitializing: true
    property string cachedDbusName: ""

    property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    property bool canTogglePlaying: activePlayer ? activePlayer.canTogglePlaying : false
    property bool canGoPrevious: activePlayer ? activePlayer.canGoPrevious : false
    property bool canGoNext: activePlayer ? activePlayer.canGoNext : false
    property bool canChangeVolume: activePlayer && activePlayer.volumeSupported && activePlayer.canControl
    property bool loopSupported: activePlayer && activePlayer.loopSupported && activePlayer.canControl
    property var loopState: activePlayer ? activePlayer.loopState : (typeof MprisLoopState !== 'undefined' ? MprisLoopState.None : 0)
    property bool shuffleSupported: activePlayer && activePlayer.shuffleSupported && activePlayer.canControl
    property bool hasShuffle: activePlayer ? activePlayer.shuffle : false

    // --- Handlers ---
    onFilteredPlayersChanged: {
        if (root.isInitializing && root.cachedDbusName && root.filteredPlayers.length > 0) {
            for (let i = 0; i < root.filteredPlayers.length; i++) {
                const player = root.filteredPlayers[i];
                if (player.dbusName === root.cachedDbusName) {
                    root.trackedPlayer = player;
                    root.isInitializing = false;
                    return;
                }
            }
        }
    }

    Component.onCompleted: {
        root.cachedDbusName = StateService.get("lastPlayerDbusName", "");
        if (StateService.initialized) {
            root.loadLastPlayer();
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.cachedDbusName = StateService.get("lastPlayerDbusName", "");
            root.loadLastPlayer();
        }
    }

    // --- Functions ---
    function loadLastPlayer() {
        if (!root.cachedDbusName) {
            root.isInitializing = false;
            return;
        }

        for (let i = 0; i < root.filteredPlayers.length; i++) {
            const player = root.filteredPlayers[i];
            if (player.dbusName === root.cachedDbusName) {
                root.trackedPlayer = player;
                root.isInitializing = false;
                return;
            }
        }
    }

    function saveLastPlayer() {
        if (!root.trackedPlayer || root.isInitializing)
            return;

        StateService.set("lastPlayerDbusName", root.trackedPlayer.dbusName);
    }

    function togglePlaying() {
        if (root.canTogglePlaying)
            root.activePlayer.togglePlaying();
    }

    function previous() {
        if (root.canGoPrevious) {
            root.activePlayer.previous();
        }
    }

    function next() {
        if (root.canGoNext) {
            root.activePlayer.next();
        }
    }

    function setLoopState(loopState) {
        if (root.loopSupported) {
            root.activePlayer.loopState = loopState;
        }
    }

    function setShuffle(shuffle) {
        if (root.shuffleSupported) {
            root.activePlayer.shuffle = shuffle;
        }
    }

    function setActivePlayer(player) {
        const targetPlayer = player ? player : (root.filteredPlayers.length > 0 ? root.filteredPlayers[0] : null);

        root.trackedPlayer = targetPlayer;
        root.saveLastPlayer();
    }

    function cyclePlayer(direction) {
        const players = root.filteredPlayers;
        if (players.length === 0)
            return;

        const currentIndex = players.indexOf(root.activePlayer);
        let newIndex;

        if (direction > 0) {
            newIndex = (currentIndex + 1) % players.length;
        } else {
            newIndex = (currentIndex - 1 + players.length) % players.length;
        }

        root.trackedPlayer = players[newIndex];
        root.saveLastPlayer();
    }

    // --- Components ---
    Instantiator {
        model: Mpris.players

        Connections {
            required property var modelData
            target: modelData

            Component.onCompleted: {
                const dbusName = (modelData.dbusName || "").toLowerCase();
                const shouldIgnore = !Config.bar.enableFirefoxPlayer && dbusName.includes("firefox");

                if (!shouldIgnore && (root.trackedPlayer == null || modelData.isPlaying)) {
                    root.trackedPlayer = modelData;
                }
            }

            Component.onDestruction: {
                if (root.trackedPlayer === modelData) {
                    for (let i = 0; i < root.filteredPlayers.length; i++) {
                        const player = root.filteredPlayers[i];
                        if (player.playbackState.isPlaying) {
                            root.trackedPlayer = player;
                            break;
                        }
                    }

                    if (root.trackedPlayer === modelData) {
                        root.trackedPlayer = root.filteredPlayers.length > 0 ? root.filteredPlayers[0] : null;
                    }
                }
            }

            function onPlaybackStateChanged() {
                // Comentado para evitar cambio automático de player
                // if (root.trackedPlayer !== modelData) root.trackedPlayer = modelData
            }
        }
    }
}
