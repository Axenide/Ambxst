pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string habitFilePath: Quickshell.statePath("habits.json")
    property var habits: []
    property bool fileReady: false
    property bool loaded: false

    readonly property string todayKey: formatDateKey(new Date())

    signal habitsLoaded()

    Process {
        id: ensureHabitFile
        running: true
        command: ["bash", "-c", "mkdir -p \"$(dirname '" + root.habitFilePath + "')\" && if [ ! -f '" + root.habitFilePath + "' ]; then printf '[]' > '" + root.habitFilePath + "'; fi"]
        onExited: {
            root.fileReady = true;
            Qt.callLater(() => habitFile.reload());
        }
    }

    FileView {
        id: habitFile
        path: root.fileReady ? root.habitFilePath : ""
        watchChanges: true

        onLoaded: root.loadHabits()
        onFileChanged: reload()
    }

    Component.onCompleted: {
        Qt.callLater(() => habitFile.reload());
    }

    function pad2(value) {
        return value < 10 ? "0" + value : String(value);
    }

    function formatDateKey(date) {
        return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
    }

    function dayKeyOffset(daysAgo) {
        const date = new Date();
        date.setHours(12, 0, 0, 0);
        date.setDate(date.getDate() - daysAgo);
        return formatDateKey(date);
    }

    function normalizeHabit(habit) {
        return {
            id: String(habit && habit.id ? habit.id : Date.now() + "-" + Math.floor(Math.random() * 100000)),
            name: String(habit && habit.name ? habit.name : ""),
            createdAt: Number(habit && habit.createdAt ? habit.createdAt : Date.now()),
            history: habit && habit.history && typeof habit.history === "object" ? habit.history : ({})
        };
    }

    function loadHabits() {
        try {
            const content = habitFile.text();
            if (!content || content.trim() === "") {
                root.habits = [];
            } else {
                const parsed = JSON.parse(content);
                root.habits = Array.isArray(parsed) ? parsed.map(normalizeHabit) : [];
            }
        } catch (e) {
            console.warn("HabitService: Failed to parse habits.json:", e);
            root.habits = [];
        }

        root.loaded = true;
        root.habitsLoaded();
    }

    function saveHabits() {
        if (!root.fileReady) {
            return;
        }

        habitFile.setText(JSON.stringify(root.habits, null, 2));
    }

    function addHabit(name) {
        const trimmed = String(name || "").trim();
        if (!trimmed) {
            return false;
        }

        const nextHabits = root.habits.slice();
        nextHabits.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 100000),
            name: trimmed,
            createdAt: Date.now(),
            history: ({})
        });
        root.habits = nextHabits;
        saveHabits();
        return true;
    }

    function removeHabit(id) {
        root.habits = root.habits.filter(habit => habit.id !== id);
        saveHabits();
    }

    function isDoneToday(habit) {
        if (!habit || !habit.history) {
            return false;
        }
        return Boolean(habit.history[root.todayKey]);
    }

    function toggleToday(id) {
        const nextHabits = root.habits.slice();
        for (let i = 0; i < nextHabits.length; i++) {
            if (nextHabits[i].id === id) {
                const history = Object.assign({}, nextHabits[i].history || {});
                if (history[root.todayKey]) {
                    delete history[root.todayKey];
                } else {
                    history[root.todayKey] = true;
                }
                nextHabits[i] = {
                    id: nextHabits[i].id,
                    name: nextHabits[i].name,
                    createdAt: nextHabits[i].createdAt,
                    history: history
                };
                root.habits = nextHabits;
                saveHabits();
                return;
            }
        }
    }

    function streak(habit) {
        if (!habit || !habit.history) {
            return 0;
        }

        let count = 0;
        let offset = 0;
        while (true) {
            const key = dayKeyOffset(offset);
            if (habit.history[key]) {
                count++;
                offset++;
                continue;
            }
            break;
        }
        return count;
    }

    function completedCount(daysAgo) {
        const key = dayKeyOffset(daysAgo);
        let count = 0;
        for (let i = 0; i < root.habits.length; i++) {
            if (root.habits[i].history && root.habits[i].history[key]) {
                count++;
            }
        }
        return count;
    }
}
