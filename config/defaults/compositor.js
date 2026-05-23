.pragma library

var data = {
    // === Borders & Rounding ===
    "showBorder": true,
    "activeBorderColor": ["primary"],
    "borderAngle": 45,
    "inactiveBorderColor": ["surface"],
    "inactiveBorderAngle": 45,
    "borderSize": 2,
    "rounding": 16,
    "roundingPower": 2.0,
    "syncRoundness": true,
    "syncBorderWidth": false,
    "syncBorderColor": false,
    "syncShadowOpacity": false,
    "syncShadowColor": false,
    "resizeOnBorder": false,
    "extendBorderGrabArea": 15,
    "hoverIconOnBorder": true,

    // === Gaps & Layout ===
    "gapsIn": 2,
    "gapsOut": 4,
    "layout": "dwindle",
    "allowTearing": false,

    // === Snap ===
    "snapEnabled": true,
    "snapWindowGap": 10,
    "snapMonitorGap": 10,
    "snapBorderOverlap": false,
    "snapRespectGaps": false,

    // === Opacity & Dim ===
    "activeOpacity": 1.0,
    "inactiveOpacity": 1.0,
    "fullscreenOpacity": 1.0,
    "dimInactive": false,
    "dimStrength": 0.5,
    "dimAround": 0.4,
    "dimSpecial": 0.2,

    // === Shadow ===
    "shadowEnabled": true,
    "shadowRange": 8,
    "shadowRenderPower": 3,
    "shadowSharp": false,
    "shadowIgnoreWindow": true,
    "shadowColor": "shadow",
    "shadowColorInactive": "shadow",
    "shadowOpacity": 0.5,
    "shadowOffset": "0 0",
    "shadowScale": 1.0,

    // === Blur ===
    "blurEnabled": true,
    "blurSize": 4,
    "blurPasses": 2,
    "blurIgnoreOpacity": true,
    "blurExplicitIgnoreAlpha": false,
    "blurIgnoreAlphaValue": 0.2,
    "blurNewOptimizations": true,
    "blurXray": false,
    "blurNoise": 0.0,
    "blurContrast": 1.0,
    "blurBrightness": 1.0,
    "blurVibrancy": 0.0,
    "blurVibrancyDarkness": 0.0,
    "blurSpecial": true,
    "blurPopups": false,
    "blurPopupsIgnorealpha": 0.2,
    "blurInputMethods": false,
    "blurInputMethodsIgnorealpha": 0.2,

    // === Animations ===
    "animationsEnabled": true,

    // === Input: Keyboard ===
    "kbLayout": "us",
    "kbVariant": "",
    "kbOptions": "",
    "numlockByDefault": false,
    "repeatRate": 25,
    "repeatDelay": 600,

    // === Input: Mouse ===
    "mouseSensitivity": 0.0,
    "mouseAccelProfile": "",
    "followMouse": 1,
    "mouseNaturalScroll": false,
    "mouseScrollFactor": 1.0,
    "mouseLeftHanded": false,
    "mouseRefocus": false,
    "floatSwitchOverrideFocus": 0,

    // === Input: Touchpad ===
    "touchpadDisableWhileTyping": true,
    "touchpadNaturalScroll": true,
    "touchpadTapToClick": true,
    "touchpadClickfingerBehavior": false,
    "touchpadTapButtonMap": "",
    "touchpadMiddleButtonEmulation": false,
    "touchpadDragLock": 0,
    "touchpadScrollFactor": 1.0,

    // === Cursor ===
    "noHardwareCursors": false,
    "enableHyprcursor": true,
    "noWarps": false,
    "persistentWarps": false,
    "warpOnChangeWorkspace": false,
    "cursorZoomFactor": 1.0,
    "cursorInactiveTimeout": 0,
    "cursorHideOnKeyPress": false,
    "cursorHideOnTouch": false,
    "cursorHideOnTablet": false,

    // === Gestures ===
    "workspaceSwipeCreateNew": true,
    "workspaceSwipeForever": false,
    "workspaceSwipeCancelRatio": 0.5,
    "workspaceSwipeMinSpeedToForce": 30,
    "workspaceSwipeDirectionLock": true,
    "workspaceSwipeUseR": false,
    "workspaceSwipeDistance": 300,
    "workspaceSwipeInvert": true,
    "workspaceSwipeTouch": false,
    "workspaceSwipeTouchInvert": false,

    // === Dwindle Layout ===
    "dwindlePreserveSplit": true,
    "dwindlePseudotile": false,
    "dwindleForceSplit": 0,
    "dwindleSmartSplit": true,
    "dwindleDefaultSplitRatio": 1.0,
    "dwindleSplitWidthMultiplier": 1.0,
    "dwindlePermanentDirectionOverride": false,
    "dwindleUseActiveForSplits": true,
    "dwindleSmartResizing": true,
    "dwindleSpecialScaleFactor": 0.8,

    // === Master Layout ===
    "masterOrientation": "left",
    "masterMfact": 0.55,
    "masterNewStatus": "slave",
    "masterNewOnTop": false,
    "masterNewOnActive": "none",
    "masterSmartResizing": true,
    "masterSpecialScaleFactor": 0.8,
    "masterAllowSmallSplit": false,

    // === Scrolling Layout ===
    "scrollingColumnWidth": 0.3,
    "scrollingExplicitColumnWidths": "",
    "scrollingDirection": "right",
    "scrollingFullscreenOnOneColumn": true,
    "scrollingFocusFitMethod": "center",
    "scrollingFollowFocus": true,
    "scrollingFollowMinVisible": 0.1,

    // === XWayland ===
    "xwaylandEnabled": true,
    "xwaylandForceZeroScaling": false,
    "xwaylandUseNearestNeighbor": true,

    // === Monitor Globals ===
    "vrr": 0,
    "vfr": true,
    "mouseMoveEnablesDpms": false,
    "keyPressEnablesDpms": false,

    // === Misc ===
    "disableAutoreload": false,
    "focusOnActivate": false,
    "animateManualResizes": false,
    "animateMouseWindowdragging": true,
    "disableHyprlandLogo": true,
    "disableSplashRendering": false,
    "forceDefaultWallpaper": -1,

    // === Ecosystem ===
    "noUpdateNews": true,
    "noDonationNag": true,
    "enforcePermissions": false
}
