pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string todoFilePath: Quickshell.statePath("todo.json")
    property var tasks: []
    property bool fileReady: false
    property bool loaded: false

    readonly property int openCount: {
        let count = 0;
        for (let i = 0; i < tasks.length; i++) {
            if (!tasks[i].completed) {
                count++;
            }
        }
        return count;
    }

    readonly property int completedCount: tasks.length - openCount

    signal tasksLoaded()

    Process {
        id: ensureTodoFile
        running: true
        command: ["bash", "-c", "mkdir -p \"$(dirname '" + root.todoFilePath + "')\" && if [ ! -f '" + root.todoFilePath + "' ]; then printf '[]' > '" + root.todoFilePath + "'; fi"]
        onExited: {
            root.fileReady = true;
            Qt.callLater(() => todoFile.reload());
        }
    }

    FileView {
        id: todoFile
        path: root.fileReady ? root.todoFilePath : ""
        watchChanges: true

        onLoaded: root.loadTasks()
        onFileChanged: reload()
    }

    Component.onCompleted: {
        Qt.callLater(() => todoFile.reload());
    }

    function normalizeTask(task) {
        return {
            id: String(task && task.id ? task.id : Date.now() + "-" + Math.floor(Math.random() * 100000)),
            text: String(task && task.text ? task.text : ""),
            completed: Boolean(task && task.completed),
            createdAt: Number(task && task.createdAt ? task.createdAt : Date.now())
        };
    }

    function loadTasks() {
        try {
            const content = todoFile.text();
            if (!content || content.trim() === "") {
                root.tasks = [];
            } else {
                const parsed = JSON.parse(content);
                root.tasks = Array.isArray(parsed) ? parsed.map(normalizeTask) : [];
            }
        } catch (e) {
            console.warn("TodoService: Failed to parse todo.json:", e);
            root.tasks = [];
        }

        root.loaded = true;
        root.tasksLoaded();
    }

    function saveTasks() {
        if (!root.fileReady) {
            return;
        }

        todoFile.setText(JSON.stringify(root.tasks, null, 2));
    }

    function addTask(text) {
        const trimmed = String(text || "").trim();
        if (!trimmed) {
            return false;
        }

        const nextTasks = root.tasks.slice();
        nextTasks.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 100000),
            text: trimmed,
            completed: false,
            createdAt: Date.now()
        });
        root.tasks = nextTasks;
        saveTasks();
        return true;
    }

    function toggleTask(id) {
        const nextTasks = root.tasks.slice();
        for (let i = 0; i < nextTasks.length; i++) {
            if (nextTasks[i].id === id) {
                nextTasks[i] = {
                    id: nextTasks[i].id,
                    text: nextTasks[i].text,
                    completed: !nextTasks[i].completed,
                    createdAt: nextTasks[i].createdAt
                };
                root.tasks = nextTasks;
                saveTasks();
                return;
            }
        }
    }

    function removeTask(id) {
        root.tasks = root.tasks.filter(task => task.id !== id);
        saveTasks();
    }

    function clearCompleted() {
        root.tasks = root.tasks.filter(task => !task.completed);
        saveTasks();
    }
}
