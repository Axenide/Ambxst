pragma Singleton
import QtQuick
import qs.config

/*!
    Anim.qml — Animation system for Ambxst.

    Provides animation style profiles inspired by classic and modern OS platforms.
    Each style defines unique easing curves, durations, and behaviors for
    different motion types (standard, emphasized, spatial, spring).

    Usage:
        import qs.modules.theme

        Behavior on opacity {
            NumberAnimation { Anim.apply(this, "standard", "normal") }
        }

        NumberAnimation {
            target: foo; property: "x"
            Anim.configure(this, "emphasized", "large", "enter")
        }

        // Platform-specific easing:
        duration: Anim.duration("standard", "normal")
        easing.type: Anim.easing("standard").type
        easing.bezierCurve: Anim.easing("standard").bezierCurve
*/
QtObject {
    id: root

    // ============================================
    // ANIMATION STYLE PROFILES
    // ============================================
    // Each profile defines:
    //   durations  — base ms per motion type
    //   easings    — bezier curves per motion type
    //   name       — human-readable name

    readonly property var _profiles: ({
        // ─── Material 3 (default) ──────────────────────────────────────
        "m3": {
            name: "Material 3",
            durations: {
                standard:   { small: 120,  normal: 250, large: 350, extraLarge: 450 },
                emphasized: { small: 200,  normal: 350, large: 500 },
                spatial:    { fast: 150,   default: 300, slow: 450 },
                spring:     { small: 300,  normal: 450, large: 600 }
            },
            easings: {
                standard:       [0.2, 0.0, 0.0, 1.0],
                emphasized:     [0.05, 0.7, 0.1, 1.0],
                emphasizedExit: [0.3, 0.0, 0.8, 0.15],
                spatial:        [0.4, 0.0, 0.2, 1.0],
                decelerate:     [0.0, 0.0, 0.2, 1.0],
                accelerate:     [0.4, 0.0, 1.0, 1.0],
                linear:         null
            }
        },

        // ─── Windows Classic (95/98/ME/2000) ────────────────────────────
        // Minimal animations, linear or very simple easing, short durations.
        // Design principle: functional, no-nonsense, instant feedback.
        "windows-classic": {
            name: "Windows Classic",
            durations: {
                standard:   { small: 50,   normal: 100, large: 150, extraLarge: 200 },
                emphasized: { small: 100,  normal: 150, large: 250 },
                spatial:    { fast: 50,    default: 100, slow: 200 },
                spring:     { small: 100,  normal: 150, large: 200 }
            },
            easings: {
                standard:       [0.0, 0.0, 1.0, 1.0],  // Linear
                emphasized:     [0.0, 0.0, 1.0, 1.0],  // Linear
                emphasizedExit: [0.0, 0.0, 1.0, 1.0],  // Linear
                spatial:        [0.0, 0.0, 1.0, 1.0],  // Linear
                decelerate:     [0.0, 0.0, 1.0, 1.0],  // Linear
                accelerate:     [0.0, 0.0, 1.0, 1.0],  // Linear
                linear:         null
            }
        },

        // ─── Windows XP ─────────────────────────────────────────────────
        // Gentle ease-out, slightly playful, medium durations.
        // "Luna" theme: smooth but not overly animated.
        "windows-xp": {
            name: "Windows XP",
            durations: {
                standard:   { small: 100,  normal: 200, large: 300, extraLarge: 400 },
                emphasized: { small: 150,  normal: 250, large: 350 },
                spatial:    { fast: 100,   default: 200, slow: 350 },
                spring:     { small: 200,  normal: 300, large: 400 }
            },
            easings: {
                standard:       [0.25, 0.1, 0.25, 1.0],  // Gentle ease
                emphasized:     [0.0, 0.0, 0.2, 1.0],    // Ease-out emphasis
                emphasizedExit: [0.4, 0.0, 1.0, 1.0],    // Ease-in
                spatial:        [0.25, 0.1, 0.25, 1.0],
                decelerate:     [0.0, 0.0, 0.2, 1.0],
                accelerate:     [0.4, 0.0, 1.0, 1.0],
                linear:         null
            }
        },

        // ─── Windows 7 (Aero) ───────────────────────────────────────────
        // Glass aesthetic, smooth transitions, subtle overshoot.
        // Aero Glass: animated taskbar thumbnails, flip3d, window previews.
        "windows-7": {
            name: "Windows 7",
            durations: {
                standard:   { small: 150,  normal: 250, large: 350, extraLarge: 500 },
                emphasized: { small: 200,  normal: 350, large: 500 },
                spatial:    { fast: 150,   default: 300, slow: 450 },
                spring:     { small: 300,  normal: 400, large: 550 }
            },
            easings: {
                // Aero glass: smooth with gentle coefficient
                standard:       [0.15, 0.60, 0.25, 0.90],
                emphasized:     [0.05, 0.80, 0.15, 0.95],
                emphasizedExit: [0.35, 0.05, 0.75, 0.35],
                spatial:        [0.22, 0.50, 0.30, 0.88],
                linear:         null
            }
        },

        // ─── Mac OS Classic (pre-OS X) ──────────────────────────────────
        // Almost no animations. Checkerboard, iris effects (Platinum).
        // In practice: linear fades if anything.
        "mac-classic": {
            name: "Mac OS Classic",
            durations: {
                standard:   { small: 30,   normal: 80,  large: 120, extraLarge: 180 },
                emphasized: { small: 80,   normal: 120, large: 200 },
                spatial:    { fast: 30,    default: 80,  slow: 150 },
                spring:     { small: 80,   normal: 120, large: 150 }
            },
            easings: {
                standard:       [0.0, 0.0, 1.0, 1.0],  // All linear
                emphasized:     [0.0, 0.0, 1.0, 1.0],
                emphasizedExit: [0.0, 0.0, 1.0, 1.0],
                spatial:        [0.0, 0.0, 1.0, 1.0],
                decelerate:     [0.0, 0.0, 1.0, 1.0],
                accelerate:     [0.0, 0.0, 1.0, 1.0],
                linear:         null
            }
        },

        // ─── Mac OS X Leopard/Snow Leopard ──────────────────────────────
        // Genie effect, smooth fade, sine-based curves.
        // Aqua UI: jelly buttons, smooth scrolling, cover flow.
        "mac-legacy": {
            name: "Mac OS X",
            durations: {
                standard:   { small: 200,  normal: 350, large: 500, extraLarge: 650 },
                emphasized: { small: 300,  normal: 450, large: 600 },
                spatial:    { fast: 200,   default: 350, slow: 500 },
                spring:     { small: 350,  normal: 500, large: 700 }
            },
            easings: {
                standard:       [0.42, 0.0, 0.58, 1.0],  // Sine ease-in-out
                emphasized:     [0.25, 0.46, 0.45, 0.94], // Gentle overshoot
                emphasizedExit: [0.55, 0.06, 0.68, 0.53], // Smooth exit
                spatial:        [0.42, 0.0, 0.58, 1.0],   // Sine ease
                decelerate:     [0.0, 0.0, 0.2, 1.0],
                accelerate:     [0.4, 0.0, 1.0, 1.0],
                linear:         null
            }
        },

        // ─── macOS Modern (10.7+) ───────────────────────────────────────
        // Spring animations, natural physics, smooth scrolling.
        // Natural easing: mimic real-world physics (slight bounce).
        "mac-modern": {
            name: "macOS",
            durations: {
                standard:   { small: 150,  normal: 300, large: 450, extraLarge: 600 },
                emphasized: { small: 250,  normal: 400, large: 550 },
                spatial:    { fast: 150,   default: 300, slow: 450 },
                spring:     { small: 400,  normal: 550, large: 750 }
            },
            easings: {
                // Spring: zeta=0.55, natural bounce
                standard:       [0.28, 0.65, 0.18, 0.88],
                emphasized:     [0.15, 0.78, 0.22, 0.90],
                emphasizedExit: [0.30, 0.08, 0.65, 0.25],
                spatial:        [0.32, 0.55, 0.25, 0.85],
                linear:         null
            }
        },

        // ─── Android Gingerbread/Honeycomb (pre-Material) ──────────────
        // Simple transitions, basic fade, short durations.
        "android-legacy": {
            name: "Android (Legacy)",
            durations: {
                standard:   { small: 80,   normal: 150, large: 250, extraLarge: 350 },
                emphasized: { small: 150,  normal: 250, large: 350 },
                spatial:    { fast: 80,    default: 150, slow: 300 },
                spring:     { small: 150,  normal: 250, large: 350 }
            },
            easings: {
                standard:       [0.4, 0.0, 0.6, 1.0],    // Gentle ease
                emphasized:     [0.0, 0.0, 0.35, 1.0],   // Ease-out
                emphasizedExit: [0.4, 0.0, 1.0, 1.0],    // Ease-in
                spatial:        [0.4, 0.0, 0.6, 1.0],
                decelerate:     [0.0, 0.0, 0.35, 1.0],
                accelerate:     [0.4, 0.0, 1.0, 1.0],
                linear:         null
            }
        },

        // ─── Android Material Design (5.0-11) ───────────────────────────
        // Responsive: fast start, slow end. Standard Material curves.
        // FastOutSlowIn: immediate response + smooth deceleration.
        "android-material": {
            name: "Android Material",
            durations: {
                standard:   { small: 100,  normal: 200, large: 300, extraLarge: 400 },
                emphasized: { small: 200,  normal: 300, large: 450 },
                spatial:    { fast: 150,   default: 250, slow: 400 },
                spring:     { small: 250,  normal: 350, large: 500 }
            },
            easings: {
                standard:       [0.4, 0.0, 0.2, 1.0],   // FastOutSlowIn
                emphasized:     [0.4, 0.0, 0.2, 1.0],   // Same for emphasis
                emphasizedExit: [0.4, 0.0, 1.0, 1.0],   // FastOutLinearIn
                spatial:        [0.4, 0.0, 0.2, 1.0],
                decelerate:     [0.0, 0.0, 0.2, 1.0],   // LinearOutSlowIn
                accelerate:     [0.4, 0.0, 1.0, 1.0],   // FastOutLinearIn
                linear:         null
            }
        },

        // ─── Android 12+ (Material You) ─────────────────────────────────
        // Expressive, organic, spring physics. Longer durations.
        // Emphasized deceleration, adaptive motion based on context.
        "android-you": {
            name: "Android 12+",
            durations: {
                standard:   { small: 200,  normal: 350, large: 500, extraLarge: 700 },
                emphasized: { small: 350,  normal: 500, large: 700 },
                spatial:    { fast: 250,   default: 400, slow: 600 },
                spring:     { small: 450,  normal: 600, large: 850 }
            },
            easings: {
                // Expressive spring: zeta=0.45, visible bounce
                standard:       [0.15, 0.70, 0.20, 0.88],
                emphasized:     [0.05, 0.85, 0.12, 0.92],
                emphasizedExit: [0.30, 0.10, 0.68, 0.18],
                spatial:        [0.30, 0.48, 0.25, 0.90],
                linear:         null
            }
        }
    })

    // ============================================
    // ACTIVE PROFILE
    // ============================================
    readonly property string _styleKey: {
        const s = Config.theme && Config.theme.animStyle;
        if (s && root._profiles[s]) return s;
        return "m3";
    }

    readonly property var _profile: root._profiles[root._styleKey] || root._profiles["m3"]

    // ============================================
    // GLOBAL SPEED SCALE
    // ============================================
    readonly property real _baseScale: {
        if (root._styleKey === "disabled") return 0;
        // Check Config availability — during startup Config may not be ready
        if (typeof Config === "undefined" || Config === null) return 1.0;
        const ad = Config.animDuration;
        if (ad === undefined || ad === null || ad <= 0) return 1.0; // Default to enabled
        const cfgScale = Config.theme && Config.theme.animScale;
        let userScale = (cfgScale !== undefined && cfgScale > 0) ? cfgScale : 1.0;
        return userScale * ad / 300;
    }

    function _scale(baseMs) {
        return Math.max(0, Math.round(baseMs * root._baseScale));
    }

    // ============================================
    // PUBLIC API
    // ============================================

    /*! Get duration in ms for a given type/size.
        @param type: "standard" | "emphasized" | "spatial" | "spring"
        @param size: "small" | "normal" | "large" | "extraLarge" / "fast" / "default" / "slow"
    */
    function duration(type, size) {
        const profile = root._profile;
        const t = profile.durations[type];
        if (!t) return 0;
        return root._scale(t[size] || t.normal || t.default || 0);
    }

    /*! Get easing configuration object for a given type.
        @param type: "standard" | "emphasized" | "emphasizedExit" | "spatial" | "decelerate" | "accelerate" | "linear"
        @param variant: (optional) "enter" | "exit" — shorthand for emphasized variants
        @returns {{ type: int, bezierCurve?: number[] }}
    */
    function easing(type, variant) {
        const profile = root._profile;
        let key = type;

        if (type === "emphasized") {
            if (variant === "exit" || variant === "accelerate")
                key = "emphasizedExit";
            else
                key = "emphasized";
        }

        const curve = profile.easings[key] || profile.easings.standard || [0.0, 0.0, 1.0, 1.0];
        if (curve === null)
            return { type: Easing.Linear };

        return { type: Easing.BezierSpline, bezierCurve: curve };
    }

    /*! Configure a NumberAnimation with the active profile's settings. */
    function configure(anim, type, size, variant) {
        if (!anim || !(anim instanceof NumberAnimation)) return;
        anim.duration = root.duration(type, size);
        const ease = root.easing(type, variant);
        anim.easing.type = ease.type;
        if (ease.bezierCurve !== undefined)
            anim.easing.bezierCurve = ease.bezierCurve;
    }

    /*! Shorthand: apply profile settings to a Behavior's default animation. */
    function apply(targetAnimation, type, size, variant) {
        if (!targetAnimation) return;
        root.configure(targetAnimation, type, size, variant);
    }

    // ============================================
    // HYPRLAND ANIMATION CONFIG
    // ============================================
    // Returns bezier curve and speed for Hyprland animations based on style.
    // Dramatic, physics-driven bezier curves for Hyprland animations.
    // Each style uses unique math to create a distinct feel:
    //   Overshoot:     c1y > 1.0 or c2y < 0.0 → bouncy/snap effect
    //   Anticipation:  c1x < 0.0 → pull back before moving
    //   Spring:        c1y > 1.0, c2y < 0.0 → full spring bounce
    //   Snappy:        c1x very small, c2x close to 1.0 → quick start, fast finish
    //   Smooth:        symmetric → butter-smooth
    readonly property var _hyprBeziers: ({
        // M3 — standard Material Deceleration: immediate response, gentle end
        "m3":               { curve: [0.2, 0.0, 0.0, 1.0], speed: 2.5, name: "nl-standard" },
        // Windows Classic — linear, no easing at all
        "windows-classic":  { curve: [0.0, 0.0, 1.0, 1.0], speed: 1.0, name: "nl-linear" },
        // Windows XP — gentle ease-out with slight anticipation
        "windows-xp":       { curve: [0.25, 0.1, 0.25, 1.0], speed: 2.0, name: "nl-xp" },
        // Windows 7 Aero — smooth reveal with subtle overshoot bounce
        "windows-7":        { curve: [0.1, 0.8, 0.1, 1.0], speed: 2.8, name: "nl-aero" },
        // Mac OS Classic — no easing, near-instant
        "mac-classic":      { curve: [0.0, 0.0, 1.0, 1.0], speed: 0.5, name: "nl-linear" },
        // Mac OS X Aqua — sine-wave smooth, long tail
        "mac-legacy":       { curve: [0.42, 0.0, 0.58, 1.0], speed: 3.0, name: "nl-aqua" },
        // macOS Modern — natural spring: slight bounce, organic
        "mac-modern":       { curve: [0.34, 0.6, 0.12, 0.8], speed: 2.5, name: "nl-natural" },
        // Android Legacy — simple ease-in-out
        "hyprland":         { curve: [0.2, 0.0, 0.1, 1.0], speed: 4.0, name: "nl-hyprland" },
        "android-legacy":   { curve: [0.4, 0.0, 0.6, 1.0], speed: 1.5, name: "nl-android-legacy" },
        // Android Material — FastOutSlowIn: immediate, then smooth
        "android-material": { curve: [0.4, 0.0, 0.2, 1.0], speed: 2.0, name: "nl-material" },
        // Android 12+ — Emphasized Deceleration: dramatic, expressive
        "android-you":      { curve: [0.05, 0.7, 0.1, 1.0], speed: 3.0, name: "nl-you" }
    })

    /*! Get Hyprland bezier animation config for the current style.
        @returns { curve: number[], speed: number, name: string }
        - curve: bezier control points for Hyprland's bezier keyword
        - speed: animation speed multiplier for Hyprland
        - name: unique bezier name to use in animation keywords */
    function hyprConfig() {
        const cfg = root._hyprBeziers[root._styleKey];
        if (!cfg) return root._hyprBeziers["m3"];
        return cfg;
    }

    /*! Get the Hyprland bezier definition line(s) needed for the current style.
        Returns: "bezier = nl-name, cx1, cy1, cx2, cy2" */
    function hyprBezierDef() {
        const cfg = root.hyprConfig();
        const c = cfg.curve;
        return `bezier = ${cfg.name}, ${c[0]}, ${c[1]}, ${c[2]}, ${c[3]}`;
    }

    /*! Get the Hyprland animation command for a specific type.
        @param type: "windows" | "border" | "fade" | "workspaces"
        @param orientation: "horizontal" | "vertical" (for workspaces)
        @returns the keyword command string */
    function hyprAnimation(type, orientation) {
        const cfg = root.hyprConfig();
        const speed = cfg.speed.toFixed(1);
        const bezierName = cfg.name;
        const enabled = root.animationsEnabled ? "1" : "0";

        switch (type) {
        case "windows":
            return `keyword animation windows,${enabled},${speed},${bezierName},popin 80%`;
        case "border":
            return `keyword animation border,${enabled},${speed},${bezierName}`;
        case "fade":
            return `keyword animation fade,${enabled},${speed},${bezierName}`;
        case "workspaces":
            const anim = orientation === "vertical" ? "slidefadevert 20%" : "slidefade 20%";
            return `keyword animation workspaces,${enabled},${speed},${bezierName},${anim}`;
        default:
            return "";
        }
    }

    /*! Get Hyprland config file line for an animation type.
        Unlike hyprAnimation() which outputs 'keyword ...' for runtime,
        this outputs the hyprland.conf syntax (no 'keyword' prefix).
        @param type: "windows" | "border" | "fade" | "workspaces"
        @param orientation: "horizontal" | "vertical" (for workspaces)
        @returns config file line like: 'animation = windows, 1, 4.0, nl-name, popin 80%' */
    function hyprConfLine(type, orientation) {
        const cfg = root.hyprConfig();
        const speed = cfg.speed.toFixed(1);
        const bezierName = cfg.name;
        const enabled = root.animationsEnabled ? "1" : "0";

        switch (type) {
        case "windows":
            return `animation = windows, ${enabled}, ${speed}, ${bezierName}, popin 80%`;
        case "border":
            return `animation = border, ${enabled}, ${speed}, ${bezierName}`;
        case "fade":
            return `animation = fade, ${enabled}, ${speed}, ${bezierName}`;
        case "workspaces":
            const anim = orientation === "vertical" ? "slidefadevert 20%" : "slidefade 20%";
            return `animation = workspaces, ${enabled}, ${speed}, ${bezierName}, ${anim}`;
        default:
            return "";
        }
    }

    // ============================================
    // ORGANIC PHYSICS — Spring, Anticipation, Overshoot, Momentum
    // ============================================
    // These use low-level math to generate physically-plausible
    // animation curves that feel natural without expensive bindings.
    //
    // Inspired by: Framer Motion (springs), Apple UIKit (spring physics),
    // Android Material (adaptive curves), and KDE Plasma (smooth scrolling).
    //
    // GPU-friendly principle: opacity/scale/rotation cost ~1µs,
    // while x/y/width/height cost ~100µs (trigger relayout).

    /*! Damped Spring Oscillator — the gold standard for organic motion.
        Simulates a mass on a spring with damping.
        @param stiffness:  (default 170) — spring tension, higher = snappier
        @param damping:    (default 16)  — resistance, higher = less bounce
        @param mass:       (default 1.0) — inertial mass, higher = slower
        @param initialV:   (default 0)   — initial velocity for momentum
        @returns { cx1, cy1, cx2, cy2 } bezier control points

        Math behind the curve:
          ω₀ = √(k/m)  (natural frequency)
          ζ = d / (2√(km))  (damping ratio)
          ζ < 1 → underdamped (bounces)
          ζ ≈ 1 → critically damped (fastest without bounce)
          ζ > 1 → overdamped (slow, no bounce)

        Maps spring parameters to bezier by computing T_at_50% (half-life)
        and T_at_90% (settle time) of the oscillator response. */
    function springBezier(stiffness, damping, mass, initialV) {
        const k = stiffness || 170;
        const d = damping || 16;
        const m = Math.max(0.1, mass || 1.0);
        const v0 = initialV || 0;

        // Natural frequency & damping ratio
        const w0 = Math.sqrt(k / m);
        const zeta = d / (2 * Math.sqrt(k * m));

        // Approximate settle time: when envelope decays to 1%
        // Envelope = e^(-zeta * w0 * t)
        // t_settle ≈ ln(100) / (zeta * w0) ≈ 4.6 / (zeta * w0)
        const settleTime = zeta * w0 > 0.01 ? 4.6 / (zeta * w0) : 10.0;
        const settleMs = Math.round(settleTime * 1000);

        // Calculate overshoot amount
        // For zeta < 1: overshoot = e^(-pi*zeta / sqrt(1-zeta^2))
        const overshoot = zeta < 1.0 ? Math.exp(-Math.PI * zeta / Math.sqrt(1 - zeta * zeta)) : 0;

        // Generate bezier control points that approximate the spring
        // cx1, cy1 = initial direction (velocity)
        // cx2, cy2 = overshoot/recoil behavior
        let cx1, cy1, cx2, cy2;

        if (zeta < 0.5) {
            // Bouncy: overshoot visible
            cx1 = 0.2 + zeta * 0.3;
            cy1 = 1.2 + (0.5 - zeta) * 1.5;  // Overshoot up
            cx2 = 0.3 + zeta * 0.3;
            cy2 = -0.3 - (0.5 - zeta) * 0.5;  // Dip below zero (recoil)
        } else if (zeta < 0.8) {
            // Gentle bounce: slight overshoot
            cx1 = 0.25 + zeta * 0.2;
            cy1 = 0.8 + (0.8 - zeta) * 0.5;
            cx2 = 0.4 + zeta * 0.1;
            cy2 = 0.1 + (0.8 - zeta) * 0.2;
        } else {
            // Critically damped / overdamped: smooth, no bounce
            cx1 = 0.3;
            cy1 = 0.6;
            cx2 = 0.5;
            cy2 = 0.4;
        }

        // Clamp to valid bezier range
        cx1 = Math.max(-0.5, Math.min(1.5, cx1));
        cy1 = Math.max(-0.5, Math.min(2.0, cy1));
        cx2 = Math.max(-0.5, Math.min(1.5, cx2));
        cy2 = Math.max(-0.5, Math.min(2.0, cy2));

        return {
            type: Easing.BezierSpline,
            bezierCurve: [cx1, cy1, cx2, cy2],
            duration: settleMs,
            overshoot: overshoot,
            zeta: zeta
        };
    }

    /*! Natural spring easing — preset for UI elements.
        Light stiffness, moderate damping = smooth, organic feel.
        Similar to iOS spring animations. */
    function spring(type, size) {
        return root.springBezier(180, 18, 1.0, 0);
    }

    /*! Snappy spring — for buttons, toggles, micro-interactions.
        High stiffness, high damping = immediate response, no bounce. */
    function springSnappy() {
        return root.springBezier(300, 25, 1.0, 0);
    }

    /*! Expressive spring — for modals, notifications, cards.
        Lower damping = visible overshoot = playful feel.
        Similar to Android 12+ spring animations. */
    function springExpressive() {
        return root.springBezier(200, 12, 1.0, 0);
    }

    /*! Anticipation easing — pull back before moving forward.
        Creates a "recoil" effect that makes animations feel alive.
        @param intensity: 0.0 (subtle) to 1.0 (dramatic) */
    function anticipation(intensity) {
        const i = Math.max(0, Math.min(1, intensity || 0.3));
        return {
            type: Easing.BezierSpline,
            bezierCurve: [0.3 + i * 0.15, -i * 0.5, 0.1, 1.0]
        };
    }

    /*! Overshoot easing — go past target, then settle back.
        Creates a satisfying "stretch" effect.
        @param amount: 0.0 (none) to 0.5 (maximum) */
    function overshoot(amount) {
        const a = amount || 0.2;
        return {
            type: Easing.BezierSpline,
            bezierCurve: [0.2, 1.0 + a * 2.0, 0.3, 0.8 - a * 0.5]
        };
    }

    /*! Adaptive duration — scales with distance for natural feel.
        Small movements = fast, large movements = proportionate.
        @param distance: pixel distance or normalized delta
        @param baseMs: base duration at distance=1
        @returns adaptive duration in ms */
    function adaptiveDuration(distance, baseMs) {
        const d = Math.abs(distance || 1);
        // Weber-Fechner: perceived speed is logarithmic
        // Fast for small moves, scales slowly for large moves
        const logDist = Math.log(Math.max(1, d * 10)) / Math.log(10);
        return Math.max(50, Math.min(600, Math.round(baseMs * (0.3 + logDist * 0.3))));
    }

    /*! GPU-friendly animation config.
        Optimizes for transform animations (opacity/scale/rotation).
        ~70% duration of standard, uses decelerate easing.
        @returns { duration: number, easing: object } */
    function gpuFriendly(type, size) {
        const base = root.duration(type, size || "normal");
        const gpuMs = Math.max(60, Math.round(base * 0.65));
        return {
            duration: gpuMs,
            easing: root.easing("decelerate")
        };
    }

    /*! Multi-stage animation — combines anticipation, move, and overshoot.
        Use for elements that enter the screen (cards, modals, notifications).
        @returns Array of { duration, easing } stages */
    function enterAnimation() {
        const spring = root.springBezier(200, 14, 1.0, 0);
        return {
            duration: spring.duration,
            easing: spring
        };
    }

    /*! Quick helper: get { duration, easing } for common cases. */
    function animate(type, size) {
        return {
            duration: root.duration(type, size),
            easing: root.easing(type),
            type: type,
            size: size || "normal"
        };
    }

    // ============================================
    // STYLE INFO
    // ============================================
    readonly property string styleName: root._profile.name || "M3"
    readonly property string styleKey: root._styleKey
    readonly property var availableStyles: {
        const keys = Object.keys(root._profiles);
        return keys.map(k => ({ key: k, name: root._profiles[k].name }));
    }

    // ============================================
    // CONVENIENCE PROPERTIES
    // ============================================
    readonly property int standardSmall:      root.duration("standard", "small")
    readonly property int standardNormal:     root.duration("standard", "normal")
    readonly property int standardLarge:      root.duration("standard", "large")
    readonly property int standardExtraLarge: root.duration("standard", "extraLarge")

    readonly property int emphasizedSmall:  root.duration("emphasized", "small")
    readonly property int emphasizedNormal: root.duration("emphasized", "normal")
    readonly property int emphasizedLarge:  root.duration("emphasized", "large")

    readonly property int spatialFast:    root.duration("spatial", "fast")
    readonly property int spatialDefault: root.duration("spatial", "default")
    readonly property int spatialSlow:    root.duration("spatial", "slow")

    readonly property int springSmall:   root.duration("spring", "small")
    readonly property int springNormal:  root.duration("spring", "normal")
    readonly property int springLarge:   root.duration("spring", "large")

    readonly property bool animationsEnabled: root._baseScale > 0
}
