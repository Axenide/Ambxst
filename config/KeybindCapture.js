.pragma library

// Map Qt.Key codes → axctl / Hyprland-style XKB key names used in binds.json.
// Names follow existing Ambxst[+] conventions (PERIOD, TAB, XF86…, Super_L).

// Qt::Key values (stable across Qt 5/6 for these)
var Key_Escape = 0x01000000;
var Key_Tab = 0x01000001;
var Key_Backtab = 0x01000002;
var Key_Backspace = 0x01000003;
var Key_Return = 0x01000004;
var Key_Enter = 0x01000005;
var Key_Insert = 0x01000006;
var Key_Delete = 0x01000007;
var Key_Pause = 0x01000008;
var Key_Print = 0x01000009;
var Key_SysReq = 0x0100000a;
var Key_Clear = 0x0100000b;
var Key_Home = 0x01000010;
var Key_End = 0x01000011;
var Key_Left = 0x01000012;
var Key_Up = 0x01000013;
var Key_Right = 0x01000014;
var Key_Down = 0x01000015;
var Key_PageUp = 0x01000016;
var Key_PageDown = 0x01000017;
var Key_Shift = 0x01000020;
var Key_Control = 0x01000021;
var Key_Meta = 0x01000022;
var Key_Alt = 0x01000023;
var Key_CapsLock = 0x01000024;
var Key_NumLock = 0x01000025;
var Key_ScrollLock = 0x01000026;
var Key_F1 = 0x01000030;
var Key_Super_L = 0x01000053;
var Key_Super_R = 0x01000054;
var Key_Menu = 0x01000055;
var Key_Hyper_L = 0x01000056;
var Key_Hyper_R = 0x01000057;
var Key_Help = 0x01000058;
var Key_Space = 0x20;
var Key_Exclam = 0x21;
var Key_QuoteDbl = 0x22;
var Key_NumberSign = 0x23;
var Key_Dollar = 0x24;
var Key_Percent = 0x25;
var Key_Ampersand = 0x26;
var Key_Apostrophe = 0x27;
var Key_ParenLeft = 0x28;
var Key_ParenRight = 0x29;
var Key_Asterisk = 0x2a;
var Key_Plus = 0x2b;
var Key_Comma = 0x2c;
var Key_Minus = 0x2d;
var Key_Period = 0x2e;
var Key_Slash = 0x2f;
var Key_Colon = 0x3a;
var Key_Semicolon = 0x3b;
var Key_Less = 0x3c;
var Key_Equal = 0x3d;
var Key_Greater = 0x3e;
var Key_Question = 0x3f;
var Key_At = 0x40;
var Key_BracketLeft = 0x5b;
var Key_Backslash = 0x5c;
var Key_BracketRight = 0x5d;
var Key_AsciiCircum = 0x5e;
var Key_Underscore = 0x5f;
var Key_QuoteLeft = 0x60;
var Key_BraceLeft = 0x7b;
var Key_Bar = 0x7c;
var Key_BraceRight = 0x7d;
var Key_AsciiTilde = 0x7e;
var Key_VolumeDown = 0x01000070;
var Key_VolumeMute = 0x01000071;
var Key_VolumeUp = 0x01000072;
var Key_MediaPlay = 0x01000080;
var Key_MediaStop = 0x01000081;
var Key_MediaPrevious = 0x01000082;
var Key_MediaNext = 0x01000083;
var Key_MediaRecord = 0x01000084;
var Key_MediaPause = 0x01000085;
var Key_MediaTogglePlayPause = 0x01000086;
var Key_Standby = 0x01000093;
var Key_LaunchMail = 0x010000a0;
var Key_LaunchMedia = 0x010000a1;
var Key_MonBrightnessUp = 0x010000b2;
var Key_MonBrightnessDown = 0x010000b3;
var Key_KeyboardBrightnessUp = 0x010000b5;
var Key_KeyboardBrightnessDown = 0x010000b6;
var Key_PowerOff = 0x010000b7;
var Key_WakeUp = 0x010000b8;
var Key_AudioRewind = 0x010000c5;
var Key_Calculator = 0x010000cb;
var Key_AudioForward = 0x01000102;
var Key_Sleep = 0x01020004;

// Qt::KeyboardModifier
var ShiftModifier = 0x02000000;
var ControlModifier = 0x04000000;
var AltModifier = 0x08000000;
var MetaModifier = 0x10000000;
var KeyboardModifierMask = ShiftModifier | ControlModifier | AltModifier | MetaModifier;

var SPECIAL_KEYS = {};
SPECIAL_KEYS[Key_Escape] = "ESCAPE";
SPECIAL_KEYS[Key_Tab] = "TAB";
SPECIAL_KEYS[Key_Backtab] = "TAB";
SPECIAL_KEYS[Key_Backspace] = "BACKSPACE";
SPECIAL_KEYS[Key_Return] = "RETURN";
SPECIAL_KEYS[Key_Enter] = "KP_Enter";
SPECIAL_KEYS[Key_Insert] = "INSERT";
SPECIAL_KEYS[Key_Delete] = "DELETE";
SPECIAL_KEYS[Key_Pause] = "PAUSE";
SPECIAL_KEYS[Key_Print] = "PRINT";
SPECIAL_KEYS[Key_SysReq] = "Sys_Req";
SPECIAL_KEYS[Key_Clear] = "Clear";
SPECIAL_KEYS[Key_Home] = "HOME";
SPECIAL_KEYS[Key_End] = "END";
SPECIAL_KEYS[Key_Left] = "LEFT";
SPECIAL_KEYS[Key_Up] = "UP";
SPECIAL_KEYS[Key_Right] = "RIGHT";
SPECIAL_KEYS[Key_Down] = "DOWN";
SPECIAL_KEYS[Key_PageUp] = "Prior";
SPECIAL_KEYS[Key_PageDown] = "Next";
SPECIAL_KEYS[Key_CapsLock] = "Caps_Lock";
SPECIAL_KEYS[Key_NumLock] = "Num_Lock";
SPECIAL_KEYS[Key_ScrollLock] = "Scroll_Lock";
SPECIAL_KEYS[Key_Menu] = "MENU";
SPECIAL_KEYS[Key_Help] = "HELP";
SPECIAL_KEYS[Key_Space] = "SPACE";
SPECIAL_KEYS[Key_Exclam] = "EXCLAM";
SPECIAL_KEYS[Key_QuoteDbl] = "QUOTEDBL";
SPECIAL_KEYS[Key_NumberSign] = "NUMBERSIGN";
SPECIAL_KEYS[Key_Dollar] = "DOLLAR";
SPECIAL_KEYS[Key_Percent] = "PERCENT";
SPECIAL_KEYS[Key_Ampersand] = "AMPERSAND";
SPECIAL_KEYS[Key_Apostrophe] = "APOSTROPHE";
SPECIAL_KEYS[Key_ParenLeft] = "PARENLEFT";
SPECIAL_KEYS[Key_ParenRight] = "PARENRIGHT";
SPECIAL_KEYS[Key_Asterisk] = "ASTERISK";
SPECIAL_KEYS[Key_Plus] = "PLUS";
SPECIAL_KEYS[Key_Comma] = "COMMA";
SPECIAL_KEYS[Key_Minus] = "MINUS";
SPECIAL_KEYS[Key_Period] = "PERIOD";
SPECIAL_KEYS[Key_Slash] = "SLASH";
SPECIAL_KEYS[Key_Colon] = "COLON";
SPECIAL_KEYS[Key_Semicolon] = "SEMICOLON";
SPECIAL_KEYS[Key_Less] = "LESS";
SPECIAL_KEYS[Key_Equal] = "EQUAL";
SPECIAL_KEYS[Key_Greater] = "GREATER";
SPECIAL_KEYS[Key_Question] = "QUESTION";
SPECIAL_KEYS[Key_At] = "AT";
SPECIAL_KEYS[Key_BracketLeft] = "BRACKETLEFT";
SPECIAL_KEYS[Key_Backslash] = "BACKSLASH";
SPECIAL_KEYS[Key_BracketRight] = "BRACKETRIGHT";
SPECIAL_KEYS[Key_AsciiCircum] = "ASCIICIRCUM";
SPECIAL_KEYS[Key_Underscore] = "UNDERSCORE";
SPECIAL_KEYS[Key_QuoteLeft] = "GRAVE";
SPECIAL_KEYS[Key_BraceLeft] = "BRACELEFT";
SPECIAL_KEYS[Key_Bar] = "BAR";
SPECIAL_KEYS[Key_BraceRight] = "BRACERIGHT";
SPECIAL_KEYS[Key_AsciiTilde] = "ASCIITILDE";
SPECIAL_KEYS[Key_VolumeMute] = "XF86AudioMute";
SPECIAL_KEYS[Key_MicMute] = "XF86AudioMicMute";
SPECIAL_KEYS[Key_VolumeDown] = "XF86AudioLowerVolume";
SPECIAL_KEYS[Key_VolumeUp] = "XF86AudioRaiseVolume";
SPECIAL_KEYS[Key_MediaPlay] = "XF86AudioPlay";
SPECIAL_KEYS[Key_MediaStop] = "XF86AudioStop";
SPECIAL_KEYS[Key_MediaPrevious] = "XF86AudioPrev";
SPECIAL_KEYS[Key_MediaNext] = "XF86AudioNext";
SPECIAL_KEYS[Key_MediaPause] = "XF86AudioPause";
SPECIAL_KEYS[Key_MediaTogglePlayPause] = "XF86AudioPlay";
SPECIAL_KEYS[Key_MediaRecord] = "XF86AudioRecord";
SPECIAL_KEYS[Key_AudioRewind] = "XF86AudioRewind";
SPECIAL_KEYS[Key_AudioForward] = "XF86AudioForward";
SPECIAL_KEYS[Key_Calculator] = "XF86Calculator";
SPECIAL_KEYS[Key_LaunchMail] = "XF86Mail";
SPECIAL_KEYS[Key_LaunchMedia] = "XF86AudioMedia";
SPECIAL_KEYS[Key_MonBrightnessUp] = "XF86MonBrightnessUp";
SPECIAL_KEYS[Key_MonBrightnessDown] = "XF86MonBrightnessDown";
SPECIAL_KEYS[Key_KeyboardBrightnessUp] = "XF86KbdBrightnessUp";
SPECIAL_KEYS[Key_KeyboardBrightnessDown] = "XF86KbdBrightnessDown";
SPECIAL_KEYS[Key_PowerOff] = "XF86PowerOff";
SPECIAL_KEYS[Key_Sleep] = "XF86Sleep";
SPECIAL_KEYS[Key_WakeUp] = "XF86WakeUp";
SPECIAL_KEYS[Key_Standby] = "XF86Standby";

for (var f = 0; f < 24; f++) {
    SPECIAL_KEYS[Key_F1 + f] = "F" + (f + 1);
}

function isModifierKey(key) {
    return key === Key_Shift
        || key === Key_Control
        || key === Key_Meta
        || key === Key_Alt
        || key === Key_Super_L
        || key === Key_Super_R
        || key === Key_Hyper_L
        || key === Key_Hyper_R;
}

function modifiersFromEvent(modifiers) {
    var mods = [];
    if (modifiers & MetaModifier)
        mods.push("SUPER");
    if (modifiers & ControlModifier)
        mods.push("CTRL");
    if (modifiers & AltModifier)
        mods.push("ALT");
    if (modifiers & ShiftModifier)
        mods.push("SHIFT");
    return mods;
}

function keyNameFromQtKey(key, text) {
    if (SPECIAL_KEYS[key])
        return SPECIAL_KEYS[key];

    // A–Z
    if (key >= 0x41 && key <= 0x5a)
        return String.fromCharCode(key);
    // a–z
    if (key >= 0x61 && key <= 0x7a)
        return String.fromCharCode(key - 0x20);
    // 0–9
    if (key >= 0x30 && key <= 0x39)
        return String.fromCharCode(key);

    if (text && text.length === 1) {
        var ch = text.toUpperCase();
        if (/^[A-Z0-9]$/.test(ch))
            return ch;
    }

    return "";
}

function modifierKeyBind(key) {
    if (key === Key_Meta || key === Key_Super_L)
        return { modifiers: ["SUPER"], key: "Super_L" };
    if (key === Key_Super_R)
        return { modifiers: ["SUPER"], key: "Super_R" };
    if (key === Key_Control)
        return { modifiers: ["CTRL"], key: "Control_L" };
    if (key === Key_Alt)
        return { modifiers: ["ALT"], key: "Alt_L" };
    if (key === Key_Shift)
        return { modifiers: ["SHIFT"], key: "Shift_L" };
    return null;
}

/**
 * Interpret a Keys.onPressed event for hotkey recording.
 * Returns { type: "cancel"|"ignore"|"capture", modifiers?, key? }
 */
function interpretKeyPress(key, modifiers, text) {
    var modsHeld = modifiers & KeyboardModifierMask;

    // Escape alone cancels recording
    if (key === Key_Escape && modsHeld === 0)
        return { type: "cancel" };

    if (isModifierKey(key))
        return { type: "ignore" };

    var name = keyNameFromQtKey(key, text || "");
    if (!name)
        return { type: "ignore" };

    return {
        type: "capture",
        modifiers: modifiersFromEvent(modifiers),
        key: name
    };
}

/**
 * Lone modifier release (e.g. tap Super) → bind that modifier key.
 */
function interpretModifierRelease(key, modifiers) {
    var remaining = modifiers & KeyboardModifierMask;
    if (remaining !== 0)
        return { type: "ignore" };

    var bind = modifierKeyBind(key);
    if (!bind)
        return { type: "ignore" };
    return { type: "capture", modifiers: bind.modifiers, key: bind.key };
}

/** Linux BTN_* codes used by Hyprland / axctl mouse binds */
function mouseButtonKey(button) {
    // Qt.LeftButton=1, RightButton=2, MiddleButton=4, Back=8, Forward=16
    if (button === 1)
        return "mouse:272";
    if (button === 2)
        return "mouse:273";
    if (button === 4)
        return "mouse:274";
    if (button === 8)
        return "mouse:275";
    if (button === 16)
        return "mouse:276";
    return "";
}

function interpretMousePress(button, modifiers) {
    var name = mouseButtonKey(button);
    if (!name)
        return { type: "ignore" };
    return {
        type: "capture",
        modifiers: modifiersFromEvent(modifiers),
        key: name
    };
}

function formatBind(modifiers, key) {
    var parts = (modifiers || []).slice();
    if (key)
        parts.push(key);
    return parts.join(" + ");
}
