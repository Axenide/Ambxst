pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/*!
    Calculator.qml — Math calculation via libqalculate (qalc CLI).

    Evaluates mathematical expressions and returns formatted results.

    Usage:
        Calculator.evaluate("2 + 2")
        // result via onResultReady signal

    Requires: libqalculate (provides 'qalc' command)
*/
Singleton {
    id: root

    signal resultReady(string expression, string result)
    signal error(string expression, string error)

    property bool isAvailable: false

    property Process _checkProcess: Process {
        command: ["sh", "-c", "command -v qalc"]
        running: true
        onExited: (code) => {
            root.isAvailable = code === 0;
        }
    }

    function evaluate(expression) {
        if (!expression || expression.trim() === "") return;
        if (!root.isAvailable) {
            root.error(expression, "qalc not installed");
            return;
        }

        calcProcess.command = ["qalc", "-nocolor", "-t", expression];
        calcProcess.running = true;
        _pendingExpr = expression;
    }

    property string _pendingExpr: ""

    property Process calcProcess: Process {
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    const result = data.trim().replace(/\n/g, " → ");
                    if (result && result !== root._pendingExpr) {
                        root.resultReady(root._pendingExpr, result);
                    }
                }
            }
        }
    }
}
