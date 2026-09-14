import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import vm from "node:vm";

const repoRoot = path.resolve(import.meta.dirname, "..");

function loadQmlLibrary(relativePath) {
    const filePath = path.join(repoRoot, relativePath);
    const source = fs.readFileSync(filePath, "utf8").replace(/^\.pragma library\s*$/gm, "");
    const sandbox = {};
    vm.createContext(sandbox);
    vm.runInContext(source, sandbox, { filename: filePath });
    return sandbox;
}

function plain(value) {
    return JSON.parse(JSON.stringify(value));
}

test("ConfigValidator preserves arbitrary monitor keys inside screenPositions maps", () => {
    const validator = loadQmlLibrary("config/ConfigValidator.js");

    const current = {
        position: "bottom",
        screenPositions: {
            "eDP-1": "top",
            "DP-3": "bottom"
        }
    };
    const defaults = {
        position: "top",
        screenPositions: {}
    };

    assert.deepEqual(plain(validator.validate(current, defaults)), current);
});

test("ScreenPositions resolves a per-screen override before falling back to global position", () => {
    const screenPositions = loadQmlLibrary("config/ScreenPositions.js");
    const allowed = ["top", "bottom", "left", "right"];
    const config = {
        position: "top",
        screenPositions: {
            "eDP-1": "bottom",
            "DP-3": "sideways"
        }
    };

    assert.equal(screenPositions.positionForScreen(config, "eDP-1", "top", allowed), "bottom");
    assert.equal(screenPositions.positionForScreen(config, "HDMI-A-1", "top", allowed), "top");
    assert.equal(screenPositions.positionForScreen(config, "DP-3", "top", allowed), "top");
    assert.equal(screenPositions.positionForScreen({ position: "sideways" }, "DP-3", "top", allowed), "top");
});
