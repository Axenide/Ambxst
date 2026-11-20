.pragma library
// Line-art icons for the skwd-paper transitions.
// draw(ctx, key, t, w, h, line, accent) paints one frame of `key` at
// progress t (0..1). Everything is drawn in a 64 x 40 virtual canvas that is
// scaled to fit w x h. `line` = frame, old image (45 deg hatch) and neutral
// strokes; `accent` = the new image (mountain + sun), moving parts, grains.
// Qt Quick Context2D only: roundedRect (no roundRect), ellipse(x, y, w, h)
// takes a bounding box, dashes are drawn by hand.

var ctx = null;
var LINE = "white";
var ACC = "white";
var PI = Math.PI;
var TAU = 2 * Math.PI;
var F = { x: 4, y: 4, w: 56, h: 32 };
var C = { x: 32, y: 20 };
var LW = 1.25;

// ── maths ────────────────────────────────────────────────────────────────
function cl(x, a, b) {
    if (a === undefined) { a = 0; b = 1; }
    return x < a ? a : (x > b ? b : x);
}
function ss(a, b, x) {
    var k = cl((x - a) / (b - a));
    return k * k * (3 - 2 * k);
}
function rng(i) {
    var s = Math.sin(i * 12.9898 + 78.233) * 43758.5453;
    return s - Math.floor(s);
}
function lerp(a, b, k) { return a + (b - a) * k; }
function expo(t) { return t < 0.5 ? 0.5 * Math.pow(2, 20 * t - 10) : 1 - 0.5 * Math.pow(2, 10 - 20 * t); }
function quad(a, b, c, e) {
    var x1 = lerp(a.x, b.x, e), y1 = lerp(a.y, b.y, e);
    var x2 = lerp(b.x, c.x, e), y2 = lerp(b.y, c.y, e);
    return { x: lerp(x1, x2, e), y: lerp(y1, y2, e) };
}
function rot(p, ang) {
    var c = Math.cos(ang), s = Math.sin(ang), dx = p.x - C.x, dy = p.y - C.y;
    return { x: C.x + dx * c - dy * s, y: C.y + dx * s + dy * c };
}

// ── drawing helpers ──────────────────────────────────────────────────────
function useLine() { ctx.strokeStyle = LINE; ctx.fillStyle = LINE; }
function useAcc() { ctx.strokeStyle = ACC; ctx.fillStyle = ACC; }

function frame() {
    ctx.save();
    ctx.globalAlpha = 1;
    ctx.lineWidth = LW;
    useLine();
    ctx.beginPath();
    ctx.roundedRect(F.x, F.y, F.w, F.h, 3, 3);
    ctx.stroke();
    ctx.restore();
}
function clipF() {
    ctx.beginPath();
    ctx.rect(F.x, F.y, F.w, F.h);
    ctx.clip();
}
function within(pathFn, drawFn) {
    ctx.save();
    ctx.beginPath();
    pathFn();
    ctx.clip();
    drawFn();
    ctx.restore();
}
// clear what is under the current clip (inside the frame)
function wipe() { ctx.clearRect(F.x - 2, F.y - 2, F.w + 4, F.h + 4); }
// "dark fill": the line colour at low alpha
function dark(a) {
    ctx.save();
    ctx.globalAlpha *= (a === undefined ? 0.16 : a);
    useLine();
    ctx.fillRect(F.x, F.y, F.w, F.h);
    ctx.restore();
}
function circ(x, y, r) { return function () { ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, TAU, false); }; }
function rectP(x, y, w, h) { return function () { ctx.rect(x, y, w, h); }; }
function ell(cx, cy, rx, ry) { ctx.ellipse(cx - rx, cy - ry, 2 * rx, 2 * ry); }

// Image placement. Qt's Context2D intersects a new clip with the previous one
// in the CURRENT user space, so clipping across a translate/scale goes wrong.
// Moved or scaled copies of the images are therefore mapped by hand:
// T = {sx, sy, ax, ay, bx, by} maps p -> b + (p - a) * s.
function shift(dx, dy) { return { sx: 1, sy: 1, ax: 0, ay: 0, bx: dx, by: dy }; }
function scaleAt(s, cx, cy, dx, dy) { return { sx: s, sy: s, ax: cx, ay: cy, bx: cx + (dx || 0), by: cy + (dy || 0) }; }
function mx(T, x) { return T ? T.bx + (x - T.ax) * T.sx : x; }
function my(T, y) { return T ? T.by + (y - T.ay) * T.sy : y; }
function clipT(T) {
    ctx.beginPath();
    ctx.rect(mx(T, F.x), my(T, F.y), F.w * (T ? T.sx : 1), F.h * (T ? T.sy : 1));
    ctx.clip();
}
function lwT(T, lw) { return T ? lw * cl((T.sx + T.sy) / 2, 0.6, 1) : lw; }

// OLD image: light 45 degree hatch
function old(a, T) {
    if (a === undefined) a = 1;
    if (a <= 0.004) return;
    ctx.save();
    clipT(T);
    ctx.globalAlpha *= 0.5 * a;
    ctx.lineWidth = lwT(T, 1);
    useLine();
    ctx.beginPath();
    for (var x = F.x - F.h; x < F.x + F.w; x += 5)
        seg(mx(T, x), my(T, F.y + F.h), mx(T, x + F.h), my(T, F.y));
    ctx.stroke();
    ctx.restore();
}
// NEW image: mountain zigzag + sun
var MTN = [[0, 0.85], [0.3, 0.45], [0.48, 0.68], [0.7, 0.3], [1, 0.8]];
var SUN = [0.22, 0.28, 0.11]; // u, v, r (in F.h)
function mtnPts() {
    var p = [];
    for (var i = 0; i < MTN.length; i++) p.push({ x: F.x + MTN[i][0] * F.w, y: F.y + MTN[i][1] * F.h });
    return p;
}
function sunC() { return { x: F.x + SUN[0] * F.w, y: F.y + SUN[1] * F.h, r: SUN[2] * F.h }; }
function neu(a, T) {
    if (a === undefined) a = 1;
    if (a <= 0.004) return;
    ctx.save();
    clipT(T);
    ctx.globalAlpha *= a;
    ctx.lineWidth = lwT(T, LW);
    useAcc();
    var p = mtnPts();
    ctx.beginPath();
    ctx.moveTo(mx(T, p[0].x), my(T, p[0].y));
    for (var i = 1; i < p.length; i++) ctx.lineTo(mx(T, p[i].x), my(T, p[i].y));
    ctx.stroke();
    var s = sunC();
    ctx.beginPath();
    ell(mx(T, s.x), my(T, s.y), s.r * (T ? T.sx : 1), s.r * (T ? T.sy : 1));
    ctx.stroke();
    ctx.restore();
}
// warped versions: every polyline subdivided every `step` px and passed
// through warp(x, y, i) -> {x, y}
function subdiv(pts, step) {
    var out = [pts[0]];
    for (var i = 1; i < pts.length; i++) {
        var a = pts[i - 1], b = pts[i];
        var n = Math.max(1, Math.ceil(Math.hypot(b.x - a.x, b.y - a.y) / step));
        for (var k = 1; k <= n; k++) out.push({ x: lerp(a.x, b.x, k / n), y: lerp(a.y, b.y, k / n) });
    }
    return out;
}
function polyW(pts, warp, idx) {
    for (var i = 0; i < pts.length; i++) {
        var q = warp(pts[i].x, pts[i].y, idx);
        if (i === 0) ctx.moveTo(q.x, q.y); else ctx.lineTo(q.x, q.y);
    }
}
function oldW(a, warp, step) {
    if (a <= 0.004) return;
    ctx.save();
    clipF();
    ctx.globalAlpha *= 0.5 * a;
    ctx.lineWidth = 1;
    useLine();
    ctx.beginPath();
    var i = 0;
    for (var x = F.x - F.h; x < F.x + F.w; x += 5, i++)
        polyW(subdiv([{ x: x, y: F.y + F.h }, { x: x + F.h, y: F.y }], step), warp, i);
    ctx.stroke();
    ctx.restore();
}
function neuW(a, warp, step) {
    if (a <= 0.004) return;
    ctx.save();
    clipF();
    ctx.globalAlpha *= a;
    ctx.lineWidth = LW;
    useAcc();
    ctx.beginPath();
    polyW(subdiv(mtnPts(), step), warp, 0);
    var s = sunC(), sp = [];
    for (var k = 0; k <= 16; k++) sp.push({ x: s.x + s.r * Math.cos(k * TAU / 16), y: s.y + s.r * Math.sin(k * TAU / 16) });
    polyW(sp, warp, 1);
    ctx.stroke();
    ctx.restore();
}

function seg(x1, y1, x2, y2) { ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); }
// line with an arrow head at (x2, y2), accent colour
function arrow(x1, y1, x2, y2, hs, alpha) {
    var an = Math.atan2(y2 - y1, x2 - x1);
    hs = hs || 2.2;
    ctx.save();
    if (alpha !== undefined) ctx.globalAlpha *= alpha;
    useAcc();
    ctx.lineWidth = LW;
    ctx.beginPath();
    seg(x1, y1, x2, y2);
    ctx.moveTo(x2 - hs * Math.cos(an - 0.6), y2 - hs * Math.sin(an - 0.6));
    ctx.lineTo(x2, y2);
    ctx.lineTo(x2 - hs * Math.cos(an + 0.6), y2 - hs * Math.sin(an + 0.6));
    ctx.stroke();
    ctx.restore();
}
function dashed(x1, y1, x2, y2, d, g) {
    var len = Math.hypot(x2 - x1, y2 - y1), ux = (x2 - x1) / len, uy = (y2 - y1) / len;
    for (var s = 0; s < len; s += d + g) {
        var e = Math.min(len, s + d);
        seg(x1 + ux * s, y1 + uy * s, x1 + ux * e, y1 + uy * e);
    }
}

// ── grains (sand family) ─────────────────────────────────────────────────
var GR = null;
function grains() {
    if (GR) return GR;
    GR = [];
    for (var row = 0; row < 7; row++)
        for (var col = 0; col < 12; col++) {
            var k = row * 12 + col, u = (col + 0.5) / 12, v = (row + 0.5) / 7;
            var dx = u - 0.5, dy = v - 0.5, dl = Math.hypot(dx, dy);
            var nd = 0.75 * Math.min(1, 2 * Math.max(Math.abs(dx), Math.abs(dy))) + 0.25 * Math.min(1, 1.414 * dl);
            GR.push({
                k: k, row: row, col: col, u: u, v: v,
                x: F.x + u * F.w, y: F.y + v * F.h,
                h: rng(k), h2: rng(k + 99), h3: rng(k + 199),
                dx: dx, dy: dy, dl: dl, rim: Math.pow(nd, 1.5),
                a: Math.atan2(dy, dx)
            });
        }
    return GR;
}
// batches grains into a few paths: ticks (old at home), old dots, new dots,
// each in three alpha buckets
var B = null;
function bStart() { B = { t: [[], [], []], o: [[], [], []], n: [[], [], []] }; }
function bucket(al) { return al === undefined || al > 0.8 ? 2 : (al > 0.5 ? 1 : 0); }
function tick(x, y, al) { B.t[bucket(al)].push(x, y); }
function odot(x, y, al) { B.o[bucket(al)].push(x, y); }
function ndot(x, y, al) { B.n[bucket(al)].push(x, y); }
var BA = [0.35, 0.65, 1];
function bFlush() {
    ctx.save();
    clipF();
    for (var b = 0; b < 3; b++) {
        var L = B.t[b], i;
        if (L.length) {
            ctx.globalAlpha = 0.6 * BA[b];
            useLine();
            ctx.lineWidth = 0.9;
            ctx.beginPath();
            for (i = 0; i < L.length; i += 2) seg(L[i] - 1, L[i + 1] + 1, L[i] + 1, L[i + 1] - 1);
            ctx.stroke();
        }
        L = B.o[b];
        if (L.length) {
            ctx.globalAlpha = 0.85 * BA[b];
            useLine();
            ctx.beginPath();
            for (i = 0; i < L.length; i += 2) { ctx.moveTo(L[i] + 0.85, L[i + 1]); ctx.arc(L[i], L[i + 1], 0.85, 0, TAU, false); }
            ctx.fill();
        }
        L = B.n[b];
        if (L.length) {
            ctx.globalAlpha = BA[b];
            useAcc();
            ctx.beginPath();
            for (i = 0; i < L.length; i += 2) { ctx.moveTo(L[i] + 0.95, L[i + 1]); ctx.arc(L[i], L[i + 1], 0.95, 0, TAU, false); }
            ctx.fill();
        }
    }
    ctx.restore();
}
function guide(alpha, pathFn) {
    if (alpha <= 0.01) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    useLine();
    ctx.lineWidth = 1;
    ctx.beginPath();
    pathFn();
    ctx.stroke();
    ctx.restore();
}
function dir(a) { return { x: Math.cos(a), y: 0.9 * Math.sin(a) }; }
function off(p, d, s) { return { x: p.x + d.x * s, y: p.y + d.y * s }; }

// bloom / maelstrom: old grains peel off, new grains fly in and land
function sandFlow(t, maelstrom) {
    var G = grains(), R0 = 0.5 * F.h;
    bStart();
    for (var i = 0; i < G.length; i++) {
        var g = G[i], home = { x: g.x, y: g.y };
        // old population
        var oa = maelstrom ? g.h * TAU : g.a;
        var tt = cl(t * 3.45 - (1 - g.rim) * 0.65 - g.h * 0.2);
        if (tt <= 0) tick(g.x, g.y);
        else if (tt < 0.99) {
            var w = maelstrom ? { x: C.x + 0.4 * F.h * Math.cos(oa + 0.9), y: C.y + 0.4 * F.h * 0.85 * Math.sin(oa + 0.9) }
                              : off(C, dir(oa + 1.1), R0);
            var p = quad(home, w, off(C, dir(oa + 2.2), F.w), ss(0, 1, tt));
            odot(p.x, p.y);
        }
        // new population
        var na = maelstrom ? g.h2 * TAU : g.a;
        var pb = (t - 0.2) / 0.62;
        var nt = cl((pb - 0.04) * 2.3 - g.rim * 0.65 - g.h * 0.2);
        if (nt >= 1) ndot(g.x, g.y);
        else if (nt >= 0.02) {
            var w2 = maelstrom ? { x: C.x + 0.4 * F.h * Math.cos(na + 0.9), y: C.y + 0.4 * F.h * 0.85 * Math.sin(na + 0.9) }
                               : off(C, dir(na - 1.1), R0);
            var q = quad(off(C, dir(na - 2.2), F.w), w2, home, ss(0, 1, nt));
            ndot(q.x, q.y);
        }
    }
    if (maelstrom) guide(0.22, function () { ell(C.x, C.y, 0.4 * F.h, 0.34 * F.h); });
    bFlush();
}

// shared "form a shape, recolour, return home" timing (galaxy family)
function formL(g, t) { return (t - (g.rim * 0.8 + g.h * 0.2) * 0.6) / 0.4; }
function formF(L) { return L <= 0 ? 0 : (L < 0.3 ? ss(0, 0.3, L) : (L < 0.62 ? 1 : (L < 1 ? 1 - ss(0.62, 1, L) : 0))); }
// spFn(g, t, L) -> {x, y, al}; returns average formation for guides
function sandShape(t, spFn, swirl) {
    var G = grains(), fs = 0;
    bStart();
    for (var i = 0; i < G.length; i++) {
        var g = G[i], L = formL(g, t);
        if (L <= 0) { tick(g.x, g.y); continue; }
        if (L >= 1) { ndot(g.x, g.y); continue; }
        var f = formF(L), sp = spFn(g, t, L);
        fs += f;
        var p = { x: lerp(g.x, sp.x, f), y: lerp(g.y, sp.y, f) };
        if (swirl) p = rot(p, Math.sin(PI * f) * (0.5 + g.h2 * 1.1));
        var al = sp.al === undefined ? 1 : lerp(1, sp.al, f);
        if (L > 0.46) ndot(p.x, p.y, al); else odot(p.x, p.y, al);
    }
    return fs / G.length;
}

// ── recipes ──────────────────────────────────────────────────────────────
var R = {};

R["crossfade"] = function (t) {
    var e = ss(0, 1, t);
    old(1 - e); neu(e); frame();
};

R["chromatic-bloom"] = function (t) {
    var k = Math.sin(PI * t), a = ss(0.4, 0.6, t), sc = [1 + 0.12 * k, 1 - 0.12 * k];
    old(1 - a); neu(a);
    for (var i = 0; i < 2; i++) {
        ctx.save();
        clipF();
        ctx.globalAlpha = 0.4 * k;
        if (a < 0.5) old(1, scaleAt(sc[i], C.x, C.y)); else neu(1, scaleAt(sc[i], C.x, C.y));
        ctx.restore();
    }
    frame();
    // glow rays outside the frame
    ctx.save();
    ctx.globalAlpha = k;
    useAcc();
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (i = 0; i < 8; i++) {
        var an = i * PI / 4, c = Math.cos(an), s = Math.sin(an);
        var rx = F.w / 2 + 1.5, ry = F.h / 2 + 1.5;
        var px = C.x + c * rx, py = C.y + s * ry;
        if (i % 2) { px = C.x + Math.sign(c) * (F.w / 2 + 0.5); py = C.y + Math.sign(s) * (F.h / 2 + 0.5); }
        seg(px, py, px + c * 3.2 * k, py + s * 3.2 * k);
    }
    ctx.stroke();
    ctx.restore();
};

R["circle-crop"] = function (t) {
    var s = Math.pow(Math.abs(2 * t - 1), 3), r = Math.max(2, s * F.w);
    dark(0.22);
    within(circ(C.x, C.y, r), function () { wipe(); if (t < 0.5) old(); else neu(); });
    ctx.save(); clipF();
    useAcc(); ctx.lineWidth = LW;
    ctx.beginPath(); circ(C.x, C.y, r)(); ctx.stroke();
    ctx.restore();
    var R0 = 0.35 * F.h;
    for (var i = 0; i < 4; i++) {
        var an = PI / 4 + i * PI / 2, c = Math.cos(an) * 1.5, sn = Math.sin(an);
        var a = { x: C.x + c * (R0 + 2.5), y: C.y + sn * (R0 + 2.5) }, b = { x: C.x + c * (R0 - 2.5), y: C.y + sn * (R0 - 2.5) };
        if (t < 0.5) arrow(a.x, a.y, b.x, b.y, 1.8); else arrow(b.x, b.y, a.x, a.y, 1.8);
    }
    frame();
};

R["colour-distance"] = function (t) {
    var p = mtnPts(), s = sunC();
    function mtnPath() {
        ctx.moveTo(p[0].x, p[0].y);
        for (var i = 1; i < p.length; i++) ctx.lineTo(p[i].x, p[i].y);
        ctx.lineTo(F.x + F.w + 1, F.y + F.h + 1); ctx.lineTo(F.x - 1, F.y + F.h + 1); ctx.closePath();
    }
    function skyPath() {
        ctx.moveTo(p[0].x, p[0].y);
        for (var i = 1; i < p.length; i++) ctx.lineTo(p[i].x, p[i].y);
        ctx.lineTo(F.x + F.w + 1, F.y - 1); ctx.lineTo(F.x - 1, F.y - 1); ctx.closePath();
    }
    var sunPath = circ(s.x, s.y, s.r + 1.4);
    var regs = [[skyPath, 0.8], [mtnPath, 0.5], [sunPath, 0.25]];
    for (var i = 0; i < 3; i++) {
        var th = regs[i][1], isNew = t > th || t > 0.95;
        within(regs[i][0], function () {
            wipe();
            if (!isNew) { old(); return; }
            ctx.save(); ctx.globalAlpha = 0.12; useAcc(); ctx.fillRect(F.x, F.y, F.w, F.h); ctx.restore();
            if (t - th < 0.08) dark(0.3 * (1 - (t - th) / 0.08));
        });
    }
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = LW;
    if (t > 0.5 || t > 0.95) {
        ctx.beginPath(); ctx.moveTo(p[0].x, p[0].y);
        for (i = 1; i < p.length; i++) ctx.lineTo(p[i].x, p[i].y);
        ctx.stroke();
    }
    if (t > 0.25) { ctx.beginPath(); circ(s.x, s.y, s.r)(); ctx.stroke(); }
    ctx.restore();
    frame();
};

R["crosswarp"] = function (t) {
    var bx = F.x + F.w * (1.5 - 2 * t), bw = F.w * 0.25;
    within(rectP(F.x - 1, F.y - 1, Math.max(0, bx - bw - F.x + 1), F.h + 2), old);
    within(rectP(bx + bw, F.y - 1, Math.max(0, F.x + F.w + 1 - bx - bw), F.h + 2), neu);
    ctx.save(); clipF();
    within(rectP(bx - bw, F.y, 2 * bw, F.h), function () {
        ctx.save();
        ctx.globalAlpha = 0.5;
        neu(1, scaleAt(1.6, C.x, C.y));
        ctx.restore();
        old(0.4);
    });
    ctx.restore();
    ctx.save(); clipF();
    var vs = [0.3, 0.5, 0.7];
    for (var i = 0; i < 3; i++) {
        var y = F.y + vs[i] * F.h, l = bw * (i === 1 ? 0.9 : 0.6);
        arrow(bx + l, y, bx - l, y, 2);
    }
    ctx.restore();
    frame();
};

R["crosshatch"] = function (t) {
    old();
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = 1.3;
    ctx.beginPath();
    for (var i = 0; i < 6; i++)
        if (t > rng(i) * 0.85 + 0.05) { var y = F.y + (i + 0.5) / 6 * F.h; seg(F.x, y, F.x + F.w, y); }
    for (var j = 0; j < 9; j++)
        if (t > rng(50 + j) * 0.85 + 0.05) { var x = F.x + (j + 0.5) / 9 * F.w; seg(x, F.y, x, F.y + F.h); }
    ctx.stroke();
    ctx.restore();
    if (t > 0.9) within(rectP(F.x, F.y, F.w, F.h), function () { if (t > 0.97) wipe(); neu((t - 0.9) * 10); });
    frame();
};

R["directional"] = function (t) {
    var o = t * F.h;
    ctx.save();
    clipF();
    old(1, shift(0, -o));
    neu(1, shift(0, F.h - o));
    ctx.restore();
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = LW;
    ctx.beginPath(); seg(F.x, F.y + F.h - o, F.x + F.w, F.y + F.h - o); ctx.stroke();
    ctx.restore();
    var ax = F.x + F.w - 4;
    arrow(ax, C.y + 6, ax, C.y - 6, 2.2);
    frame();
};

R["directional-scaled"] = function (t) {
    var e = Math.pow(Math.sin(t * PI / 2), 3), s = 1 - 0.3 * Math.sin(PI * t);
    dark(0.22);
    var offs = [-e * F.h, F.h - e * F.h];
    for (var i = 0; i < 2; i++) {
        var T = scaleAt(s, C.x, C.y, 0, offs[i]);
        var cx = mx(T, F.x), cy = my(T, F.y), cw = F.w * s, ch = F.h * s;
        ctx.save();
        clipF();
        within(rectP(cx, cy, cw, ch), function () { wipe(); if (i === 0) old(1, T); else neu(1, T); });
        ctx.lineWidth = LW;
        if (i === 0) useLine(); else useAcc();
        ctx.strokeRect(cx, cy, cw, ch);
        ctx.restore();
    }
    arrow(F.x + F.w - 3, C.y + 6, F.x + F.w - 3, C.y - 6, 2);
    frame();
};

R["directional-wipe"] = function (t) {
    var c = 3 * t - 1.5;
    function X(u) { return F.x + u * F.w; }
    old();
    within(function () {
        ctx.moveTo(X(c), F.y); ctx.lineTo(X(c + 1), F.y + F.h);
        ctx.lineTo(F.x - F.w, F.y + F.h); ctx.lineTo(F.x - F.w, F.y); ctx.closePath();
    }, function () { wipe(); neu(); });
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = LW;
    ctx.beginPath(); seg(X(c), F.y, X(c + 1), F.y + F.h); ctx.stroke();
    ctx.lineWidth = 0.9;
    ctx.globalAlpha = 0.7;
    ctx.beginPath();
    dashed(X(c - 0.5), F.y, X(c + 0.5), F.y + F.h, 2, 2);
    dashed(X(c + 0.5), F.y, X(c + 1.5), F.y + F.h, 2, 2);
    ctx.stroke();
    ctx.restore();
    // arrow perpendicular to the edge, pointing to the not-yet-wiped side
    var mx = X(c + 0.5), my = C.y, nx = F.h, ny = -F.w, nl = Math.hypot(nx, ny);
    nx /= nl; ny /= nl;
    ctx.save(); clipF();
    arrow(mx - nx * 3 + 2.5, my - ny * 3, mx + nx * 6 + 2.5, my + ny * 6, 2.2);
    ctx.restore();
    frame();
};

function crescent(cx, cy, r) {
    // outer circle (cx,cy,r) minus a circle offset up-right
    var ox = cx + r * 0.55, oy = cy - r * 0.45, orr = r * 0.85;
    var d = Math.hypot(ox - cx, oy - cy);
    var a = (r * r - orr * orr + d * d) / (2 * d), hh = Math.sqrt(Math.max(0, r * r - a * a));
    var mx = cx + a * (ox - cx) / d, my = cy + a * (oy - cy) / d;
    var p1 = { x: mx + hh * (oy - cy) / d, y: my - hh * (ox - cx) / d };
    var p2 = { x: mx - hh * (oy - cy) / d, y: my + hh * (ox - cx) / d };
    var a1 = Math.atan2(p1.y - cy, p1.x - cx), a2 = Math.atan2(p2.y - cy, p2.x - cx);
    var b1 = Math.atan2(p1.y - oy, p1.x - ox), b2 = Math.atan2(p2.y - oy, p2.x - ox);
    ctx.moveTo(p1.x, p1.y);
    ctx.arc(cx, cy, r, a1, a2, true);
    ctx.arc(ox, oy, orr, b2, b1, false);
    ctx.closePath();
}

R["fadecolor"] = function (t) {
    var oA = 1 - ss(0, 0.6, t), nA = ss(0.4, 1, t), m = Math.max(oA, nA);
    dark(0.45 * (1 - m));
    old(oA); neu(nA);
    ctx.save();
    ctx.globalAlpha = 1 - m;
    useAcc();
    ctx.beginPath(); crescent(C.x, C.y, 5.5); ctx.fill();
    ctx.restore();
    frame();
};

R["glitch"] = function (t) {
    var j = Math.floor(t * 40), d = (1 - t) * 10;
    var dx = (rng(j) - 0.5) * d, dy = (rng(j + 7) - 0.5) * d;
    if (Math.abs(dx) < 0.25 * d) dx = (dx < 0 ? -0.3 : 0.3) * d;
    var ms = [0.2, 0.3, 0.5], as = [0.3, 0.35, 0.5];
    for (var i = 0; i < 3; i++) {
        var T = shift(dx * ms[i] * 3, dy * ms[i] * 3);
        ctx.save();
        clipF();
        ctx.globalAlpha = as[i];
        old(1 - t, T); neu(t, T);
        ctx.restore();
    }
    ctx.save(); ctx.globalAlpha = 0.6; old(1 - t); neu(t); ctx.restore();
    frame();
};

R["glitch-displace"] = function (t) {
    var e1 = expo(t), amp = 4 * Math.sin(PI * t);
    // grey wash
    ctx.save(); ctx.globalAlpha = 0.35 * ss(0, 0.5, t) * (1 - e1); useLine(); ctx.fillRect(F.x, F.y, F.w, F.h); ctx.restore();
    // old hatch as zigzags
    if (1 - e1 > 0.004) {
        ctx.save(); clipF();
        ctx.globalAlpha = 0.5 * (1 - e1);
        useLine(); ctx.lineWidth = 1;
        ctx.beginPath();
        var i = 0;
        for (var x = F.x - F.h; x < F.x + F.w; x += 5, i++) {
            for (var k = 0; k <= 4; k++) {
                var px = x + F.h * k / 4, py = F.y + F.h - F.h * k / 4;
                var o = (k === 0 || k === 4) ? 0 : amp * (rng(i * 5 + k) - 0.5) * 2;
                if (k === 0) ctx.moveTo(px + o * 0.7, py + o * 0.7); else ctx.lineTo(px + o * 0.7, py + o * 0.7);
            }
        }
        ctx.stroke();
        ctx.restore();
    }
    // new with jittered vertices
    if (e1 > 0.004) {
        ctx.save(); clipF();
        ctx.globalAlpha = e1;
        useAcc(); ctx.lineWidth = LW;
        var p = mtnPts();
        ctx.beginPath();
        for (var n = 0; n < p.length; n++) {
            var jx = amp * (rng(n + 30) - 0.5) * 1.5, jy = amp * (rng(n) - 0.5) * 1.5;
            if (n === 0) ctx.moveTo(p[n].x + jx, p[n].y + jy); else ctx.lineTo(p[n].x + jx, p[n].y + jy);
        }
        ctx.stroke();
        var s = sunC();
        ctx.beginPath(); circ(s.x + amp * 0.6, s.y - amp * 0.3, s.r)(); ctx.stroke();
        ctx.restore();
    }
    frame();
};

R["heat-melt"] = function (t) {
    old();
    var n = 12, cw = F.w / n, cx = F.x + F.w, cy = F.y + F.h, cols = [];
    for (var j = 0; j < n; j++) {
        var reach = t * 1.75 * (0.8 + 0.2 * Math.sin(j * 1.7)) - 0.35 * rng(j) * (1 - t), r = Math.max(0, reach) * F.w;
        var x0 = F.x + j * cw, dxx = cx - (x0 + cw / 2);
        var yf = r > dxx ? Math.max(F.y, cy - Math.sqrt(r * r - dxx * dxx)) : cy;
        cols.push([x0, yf]);
    }
    // the melted area: one rect per column down to the bottom edge
    within(function () { for (var k = 0; k < n; k++) if (cols[k][1] < cy) ctx.rect(cols[k][0], cols[k][1], cw, cy - cols[k][1] + 1); },
           function () { wipe(); neu(); });
    // ragged front with drips of the old image hanging into it
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = 1.1;
    ctx.beginPath();
    var started = false;
    for (var k = 0; k < n; k++) {
        var x = cols[k][0], y = cols[k][1];
        if (y >= cy) { started = false; continue; }
        if (!started) { ctx.moveTo(x, cy); started = true; }
        ctx.lineTo(x, y); ctx.lineTo(x + cw, y);
        if (k === n - 1 || cols[k + 1][1] >= cy) ctx.lineTo(x + cw, cy);
    }
    ctx.stroke();
    useLine(); ctx.globalAlpha = 0.7; ctx.lineWidth = 1;
    ctx.beginPath();
    for (k = 0; k < n; k++) {
        y = cols[k][1];
        if (y < cy - 3 && y > F.y + 0.5) {
            var dl = 1.5 + 3 * rng(k + 9);
            seg(cols[k][0] + cw / 2, y + 0.8, cols[k][0] + cw / 2, Math.min(cy, y + dl));
        }
    }
    ctx.stroke();
    ctx.restore();
    frame();
};

function blob(R0, cx, cy) {
    return function () {
        for (var i = 0; i <= 16; i++) {
            var a = i * TAU / 16, r = R0 * (1 + 0.22 * Math.sin(3 * a + 1.3) + 0.1 * Math.sin(7 * a));
            var x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.closePath();
    };
}
R["ink-splash"] = function (t) {
    var R0 = (1.7 * t - 0.15) * F.h;
    old();
    if (R0 > 0) {
        var b = blob(R0, C.x, C.y);
        within(b, function () { wipe(); neu(); });
        ctx.save(); clipF();
        useAcc(); ctx.lineWidth = 2.4; ctx.lineJoin = "round";
        ctx.beginPath(); b(); ctx.stroke();
        ctx.beginPath();
        for (var i = 0; i < 6; i++) {
            var a = i * 1.05 + 0.4, rr = R0 * (1 + 0.22 * Math.sin(3 * a + 1.3) + 0.1 * Math.sin(7 * a)) + 3 + 2 * rng(i);
            circ(C.x + rr * Math.cos(a), C.y + rr * Math.sin(a), 0.8)();
        }
        ctx.fill();
        ctx.restore();
    }
    frame();
};

R["inkwell-drop"] = function (t) {
    var P = { x: F.x + 0.35 * F.w, y: F.y + 0.4 * F.h }, R0 = 1.5 * t * F.h;
    old();
    within(circ(P.x, P.y, R0), function () { wipe(); neu(); });
    ctx.save(); clipF(); useAcc();
    var rs = [R0, R0 - 3, R0 - 6], al = [1, 0.6, 0.4];
    for (var i = 0; i < 3; i++) {
        if (rs[i] <= 0) continue;
        ctx.globalAlpha = Math.max(0.25, 1 - t) * al[i];
        ctx.lineWidth = i === 0 ? 1.8 : 1;
        ctx.beginPath(); circ(P.x, P.y, rs[i])(); ctx.stroke();
    }
    if (t < 0.15) {
        ctx.globalAlpha = 1;
        ctx.beginPath(); circ(P.x, P.y - 3 + t * 20, 1.5)(); ctx.fill();
    }
    ctx.restore();
    frame();
};

R["iris"] = function (t) {
    var r = 1.2 * t * F.h;
    old();
    within(circ(C.x, C.y, r), function () { wipe(); neu(); });
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = LW;
    ctx.beginPath(); circ(C.x, C.y, r)(); ctx.stroke();
    ctx.globalAlpha = 0.4;
    ctx.beginPath(); circ(C.x, C.y, r + 1.4)(); ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var i = 0; i < 4; i++) {
        var a = PI / 4 + i * PI / 2;
        seg(C.x + Math.cos(a) * (r + 2.5), C.y + Math.sin(a) * (r + 2.5), C.x + Math.cos(a) * (r + 5), C.y + Math.sin(a) * (r + 5));
    }
    ctx.stroke();
    ctx.restore();
    frame();
};

R["morph"] = function (t) {
    ctx.save(); clipF();
    old(1 - t, shift(4 * t, 2.5 * t));
    neu(t, shift(-4 * (1 - t), -2.5 * (1 - t)));
    ctx.restore();
    var s = sunC(), a = Math.sin(PI * t);
    ctx.save(); clipF(); ctx.globalAlpha = a; useAcc(); ctx.lineWidth = 1;
    for (var i = 0; i < 2; i++) {
        var x0 = s.x + 6 + i * 4, y0 = s.y - 4 + i * 5;
        ctx.beginPath(); ctx.moveTo(x0, y0); ctx.quadraticCurveTo(x0 + 6, y0 - 1, x0 + 8, y0 + 4); ctx.stroke();
        arrow(x0 + 7.6, y0 + 3, x0 + 8, y0 + 4.2, 1.8, a);
    }
    ctx.restore();
    frame();
};

R["mosaic-tumble"] = function (t) {
    var z = 3 - 2 * Math.pow(2 * t - 1, 2), ci = 0.5 - 0.5 * Math.cos(PI * t), c = ci * ci;
    var cam = { x: 0.5 + 2 * c, y: 0.5 - c }, tw = F.w / z, th = F.h / z;
    ctx.save(); clipF();
    for (var i = -1; i <= 3; i++)
        for (var j = -2; j <= 1; j++) {
            var X = C.x + (i - cam.x) * tw, Y = C.y + (j - cam.y) * th;
            if (X > F.x + F.w || Y > F.y + F.h || X + tw < F.x || Y + th < F.y) continue;
            var special = (i === 0 && j === 0) || (i === 2 && j === -1);
            if (special) {
                var T = { sx: 1 / z, sy: 1 / z, ax: F.x, ay: F.y, bx: X, by: Y };
                if (i === 0) old(1, T); else neu(1, T);
            } else {
                var an = Math.floor(rng(i * 7 + j) * 4) * PI / 2 + PI / 4, L = Math.min(tw, th) * 0.25;
                var mx = X + tw / 2, my = Y + th / 2;
                ctx.save(); ctx.globalAlpha = 0.5; useLine(); ctx.lineWidth = 1;
                ctx.beginPath(); seg(mx - Math.cos(an) * L, my - Math.sin(an) * L, mx + Math.cos(an) * L, my + Math.sin(an) * L); ctx.stroke();
                ctx.restore();
            }
            ctx.save();
            ctx.lineWidth = 1;
            if (special && i === 2) useAcc(); else useLine();
            ctx.globalAlpha = special ? 1 : 0.6;
            ctx.strokeRect(X + 0.5, Y + 0.5, tw - 1, th - 1);
            ctx.restore();
        }
    ctx.restore();
    frame();
};

R["parametric-glitch"] = function (t) {
    neu(t);
    var f = 0.9 - 0.6 * t, A = 4 * t;
    oldW(1 - t, function (x, y, i) {
        var o = A * Math.sin(x * f + i);
        return { x: x + o * 0.707, y: y + o * 0.707 };
    }, 2);
    ctx.save(); clipF(); ctx.globalAlpha = Math.sin(PI * t); useAcc(); ctx.lineWidth = 1;
    ctx.beginPath();
    var vs = [0.35, 0.7];
    for (var k = 0; k < 2; k++) {
        var y0 = F.y + vs[k] * F.h;
        for (var x = F.x; x <= F.x + F.w; x += 2) {
            var y = y0 + A * 0.6 * Math.sin(x * f + k * 2);
            if (x === F.x) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
    }
    ctx.stroke();
    ctx.restore();
    frame();
};

R["perlin"] = function (t) {
    old();
    var blobs = [], k;
    for (var i = 0; i < 9; i++) {
        var r = Math.max(0, t - rng(i + 40) * 0.7) * 0.85 * F.h;
        if (r > 0) blobs.push([F.x + (0.08 + 0.84 * rng(i + 3)) * F.w, F.y + (0.1 + 0.8 * rng(i + 20)) * F.h, r]);
    }
    // clips one blob at a time: Qt clips with an odd-even rule, so a union
    // of overlapping circles in one clip path would leave holes
    for (k = 0; k < blobs.length; k++)
        within(circ(blobs[k][0], blobs[k][1], blobs[k][2]), function () { wipe(); neu(); });
    if (blobs.length) {
        ctx.save(); clipF(); useAcc(); ctx.lineWidth = 1; ctx.globalAlpha = 0.85;
        ctx.beginPath();
        for (k = 0; k < blobs.length; k++) circ(blobs[k][0], blobs[k][1], blobs[k][2])();
        ctx.stroke();
        ctx.restore();
        // erase the arcs that fall inside another blob, leaving the union outline
        for (k = 0; k < blobs.length; k++)
            within(circ(blobs[k][0], blobs[k][1], Math.max(0, blobs[k][2] - 0.75)), function () { wipe(); neu(); });
    }
    if (t > 0.9) neu((t - 0.9) * 10);
    frame();
};

R["pixelate"] = function (t) {
    var b = 1 - Math.abs(t - 0.5) * 2, n = Math.round(16 - 10 * b), e = ss(0, 1, t);
    if (b > 0.25) {
        var cw = F.w / n, ch = F.h / n;
        // old image as checker blocks
        if (1 - e > 0.01) {
            ctx.save(); ctx.globalAlpha = 0.3 * (1 - e); useLine();
            ctx.beginPath();
            for (var i = 0; i < n; i++)
                for (var j = 0; j < n; j++)
                    if ((i + j) % 3 === 0) ctx.rect(F.x + i * cw, F.y + j * ch, cw, ch);
            ctx.fill();
            ctx.restore();
        }
        // new: staircase mountain + square sun
        if (e > 0.01) {
            var p = mtnPts();
            function yAt(x) {
                for (var k = 1; k < p.length; k++)
                    if (x <= p[k].x) return lerp(p[k - 1].y, p[k].y, (x - p[k - 1].x) / (p[k].x - p[k - 1].x));
                return p[p.length - 1].y;
            }
            ctx.save(); clipF(); ctx.globalAlpha = e; useAcc(); ctx.lineWidth = LW;
            ctx.beginPath();
            var prev = null;
            for (i = 0; i < n; i++) {
                var x0 = F.x + i * cw, yc = yAt(x0 + cw / 2);
                var y = F.y + (Math.floor((yc - F.y) / ch) + 0.5) * ch;
                if (prev === null) ctx.moveTo(x0, y); else ctx.lineTo(x0, y);
                ctx.lineTo(x0 + cw, y);
                prev = y;
            }
            ctx.stroke();
            var s = sunC();
            var sx = F.x + Math.floor((s.x - F.x) / cw) * cw, sy = F.y + Math.floor((s.y - F.y) / ch) * ch;
            ctx.fillRect(sx, sy, cw, ch);
            ctx.restore();
        }
    } else {
        old(1 - e); neu(e);
    }
    ctx.save(); ctx.globalAlpha = 0.35 * b; useLine(); ctx.lineWidth = 0.6;
    ctx.beginPath();
    for (var g = 1; g < n; g++) {
        seg(F.x + g * F.w / n, F.y, F.x + g * F.w / n, F.y + F.h);
        seg(F.x, F.y + g * F.h / n, F.x + F.w, F.y + g * F.h / n);
    }
    ctx.stroke();
    ctx.restore();
    frame();
};

R["pixelfade-wave"] = function (t) {
    var nx = 8, ny = 5, cw = F.w / nx, ch = F.h / ny, oc = [], nc = [], band = [];
    for (var i = 0; i < nx; i++)
        for (var j = 0; j < ny; j++) {
            var u = (i + 0.5) / nx, v = (j + 0.5) / ny, wp = ss(0, 1, 1.6 * t - 0.3 * (u + v));
            var r = [F.x + i * cw, F.y + j * ch, cw, ch];
            (wp > 0.5 ? nc : oc).push(r);
            if (Math.sin(PI * wp) > 0.6) band.push(r);
        }
    function P(L) { return function () { for (var k = 0; k < L.length; k++) ctx.rect(L[k][0], L[k][1], L[k][2], L[k][3]); }; }
    if (oc.length) within(P(oc), old);
    if (nc.length) within(P(nc), neu);
    if (band.length) {
        ctx.save(); ctx.globalAlpha = 0.15; useLine(); ctx.beginPath(); P(band)(); ctx.fill(); ctx.restore();
        ctx.save(); useAcc(); ctx.lineWidth = 0.9; ctx.globalAlpha = 0.9;
        for (var k = 0; k < band.length; k++) ctx.strokeRect(band[k][0] + 0.5, band[k][1] + 0.5, band[k][2] - 1, band[k][3] - 1);
        ctx.restore();
    }
    frame();
};

R["plasma-flow"] = function (t) {
    var A = 3 * Math.sin(PI * t);
    function warp(x, y) { return { x: x + A * Math.sin(y * 0.45 + t * 6), y: y + A * Math.sin(x * 0.3 + t * 5) }; }
    var a = ss(0.2, 0.8, t);
    oldW(1 - a, warp, 3);
    neuW(a, warp, 3);
    frame();
};

R["polka-dots-curtain"] = function (t) {
    old();
    var cw = F.w / 10, ch = F.h / 6, dots = [];
    for (var i = 0; i < 10; i++)
        for (var j = 0; j < 6; j++) {
            var u = (i + 0.5) / 10, v = (j + 0.5) / 6, d = Math.hypot(u, v);
            var r = cl(1.9 * t - 0.9 * d, 0, 0.5);
            if (r > 0.03) dots.push([F.x + u * F.w, F.y + v * F.h, r * cw, r * ch]);
        }
    function path() { for (var k = 0; k < dots.length; k++) ell(dots[k][0], dots[k][1], dots[k][2], dots[k][3]); }
    if (dots.length) {
        within(path, function () { wipe(); neu(); });
        ctx.save(); clipF(); useAcc(); ctx.lineWidth = 0.9; ctx.globalAlpha = 0.85;
        for (var k = 0; k < dots.length; k++) { if (dots[k][2] < 0.49 * cw) { ctx.beginPath(); ell(dots[k][0], dots[k][1], dots[k][2], dots[k][3]); ctx.stroke(); } }
        ctx.restore();
    }
    if (t > 0.9) within(rectP(F.x, F.y, F.w, F.h), function () { if (t > 0.97) wipe(); neu((t - 0.9) * 10); });
    frame();
};

R["puzzle-right"] = function (t) {
    var q = ss(0.1, 0.9, t), tw = F.w / 4, th = F.h / 4;
    for (var i = 0; i < 4; i++)
        for (var j = 0; j < 4; j++) {
            var k = i * 4 + j, r = rng(k) - 0.1, cp = ss(0, 1 - r, q), wf = Math.abs(cp - 0.5) * 2;
            var Tx = F.x + i * tw, Ty = F.y + j * th, Tcx = Tx + tw / 2;
            ctx.save(); ctx.globalAlpha = 0.25; useLine(); ctx.fillRect(Tx, Ty, tw, th); ctx.restore();
            if (wf < 0.02) continue;
            ctx.save();
            ctx.beginPath(); ctx.rect(Tcx - wf * tw / 2, Ty, wf * tw, th); ctx.clip();
            wipe();
            var T = { sx: wf, sy: 1, ax: Tcx, ay: 0, bx: Tcx, by: 0 };
            if (cp < 0.5) old(1, T); else neu(1, T);
            ctx.restore();
            if (cp > 0.02 && cp < 0.98) {
                ctx.save(); useAcc(); ctx.lineWidth = 1;
                ctx.strokeRect(Tcx - wf * tw / 2 + 0.4, Ty + 0.4, wf * tw - 0.8, th - 0.8);
                ctx.restore();
            }
        }
    var da = Math.max(0.35, ss(0, 0.1, t) * (1 - ss(0.9, 1, t)));
    if (t < 0.02 || t > 0.98) da = 0;
    ctx.save(); ctx.globalAlpha = da; useLine(); ctx.lineWidth = 0.8;
    ctx.beginPath();
    for (var g = 1; g < 4; g++) { seg(F.x + g * tw, F.y, F.x + g * tw, F.y + F.h); seg(F.x, F.y + g * th, F.x + F.w, F.y + g * th); }
    ctx.stroke();
    ctx.restore();
    frame();
};

R["randomsquares"] = function (t) {
    old();
    var nx = 8, ny = 5, cw = F.w / nx, ch = F.h / ny;
    for (var i = 0; i < nx; i++)
        for (var j = 0; j < ny; j++) {
            var k = j * nx + i, m = 1 - ss(-0.5, 0, rng(k) - t * 1.5);
            if (m <= 0.01) continue;
            var x = F.x + i * cw, y = F.y + j * ch;
            within(rectP(x, y, cw, ch), function () { wipe(); old(1 - m); neu(m); });
            if (m > 0.97) continue;
            ctx.save(); ctx.globalAlpha = 0.4 + 0.6 * Math.sin(PI * m); useAcc(); ctx.lineWidth = 0.9;
            ctx.strokeRect(x + 0.45, y + 0.45, cw - 0.9, ch - 0.9);
            ctx.restore();
        }
    frame();
};

R["smoke"] = function (t) {
    neu();
    var Rr = cl(1.2 - 1.4 * t), rx = Rr * 0.6 * F.w, ry = Rr * 0.85 * F.h;
    function rad(a) { return 1 + 0.15 * Math.sin(5 * a + t * 8); }
    function path() {
        for (var i = 0; i <= 20; i++) {
            var a = i * TAU / 20, f = rad(a), x = C.x + rx * f * Math.cos(a), y = C.y + ry * f * Math.sin(a);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.closePath();
    }
    if (Rr > 0.01) {
        within(path, function () { wipe(); old(); });
        ctx.save(); clipF(); useLine(); ctx.lineWidth = 0.9; ctx.globalAlpha = 0.6;
        ctx.beginPath(); path(); ctx.stroke();
        ctx.restore();
        // curly wisps on the edge
        var wa = [0.5, 2.6, 4.4];
        ctx.save(); clipF(); ctx.globalAlpha = Math.sin(PI * t); useAcc(); ctx.lineWidth = 1;
        ctx.beginPath();
        for (var k = 0; k < 3; k++) {
            var a = wa[k], f = rad(a), x = C.x + rx * f * Math.cos(a), y = C.y + ry * f * Math.sin(a);
            var ox = Math.cos(a), oy = Math.sin(a);
            ctx.moveTo(x, y);
            ctx.bezierCurveTo(x + ox * 4 - oy * 3, y + oy * 4 + ox * 3, x + ox * 7 + oy * 2, y + oy * 7 - ox * 2, x + ox * 5 + oy * 1, y + oy * 5 - ox * 1);
        }
        ctx.stroke();
        ctx.restore();
    }
    frame();
};

R["soft-warp-fade"] = function (t) {
    var e = ss(0.05, 0.95, t);
    e = e * e * (3 - 2 * e);
    old(1 - e); neu(e);
    var A = 1.5 * Math.sin(PI * t);
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = 1; ctx.globalAlpha = 0.25 + 0.75 * Math.sin(PI * t);
    ctx.beginPath();
    var ys = [0.15, 0.24];
    for (var k = 0; k < 2; k++) {
        for (var x = F.x + 0.45 * F.w; x <= F.x + 0.9 * F.w; x += 1.5) {
            var y = F.y + ys[k] * F.h + A * Math.sin(x * 0.6 + t * 6 + k * 1.5);
            if (x === F.x + 0.45 * F.w) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
    }
    ctx.stroke();
    ctx.restore();
    frame();
};

R["voronoi-shatter"] = function (t) {
    var nx = 4, ny = 3, P = [];
    for (var i = 0; i <= nx; i++) {
        P.push([]);
        for (var j = 0; j <= ny; j++) {
            var interior = i > 0 && i < nx && j > 0 && j < ny;
            var jx = interior ? (rng(i * 5 + j) - 0.5) * 0.7 : 0, jy = interior ? (rng(i * 5 + j + 50) - 0.5) * 0.7 : 0;
            if (!interior && (i === 0 || i === nx) && j > 0 && j < ny) jy = (rng(i * 5 + j + 50) - 0.5) * 0.6;
            if (!interior && (j === 0 || j === ny) && i > 0 && i < nx) jx = (rng(i * 5 + j) - 0.5) * 0.6;
            P[i].push({ x: F.x + (i + jx) * F.w / nx, y: F.y + (j + jy) * F.h / ny });
        }
    }
    for (i = 0; i < nx; i++)
        for (j = 0; j < ny; j++) {
            var k = i * ny + j, s = rng(k + 11), sp = ss(s * 0.5, s * 0.5 + 0.5, t), ang = rng(k + 23) * TAU;
            var q = [P[i][j], P[i + 1][j], P[i + 1][j + 1], P[i][j + 1]];
            var path = function () { ctx.moveTo(q[0].x, q[0].y); ctx.lineTo(q[1].x, q[1].y); ctx.lineTo(q[2].x, q[2].y); ctx.lineTo(q[3].x, q[3].y); ctx.closePath(); };
            within(path, function () {
                neu(ss(0, 0.6, sp));
                old(1 - ss(0, 0.5, sp), shift(Math.cos(ang) * sp * 1.5 * F.w * 0.4, Math.sin(ang) * sp * 1.5 * F.h * 0.4));
            });
            ctx.save(); ctx.globalAlpha = 0.3 + 0.7 * Math.sin(PI * sp); useAcc(); ctx.lineWidth = 0.9;
            ctx.beginPath(); path(); ctx.stroke();
            ctx.restore();
        }
    frame();
};

R["zoom-blur-pull"] = function (t) {
    var fx = F.x + F.w * (0.25 + 0.5 * t), fy = C.y, s = 0.2 * (1 - Math.cos(TAU * t)), d = expo(t);
    old(1 - d); neu(d);
    var ks = [0.5, 1];
    for (var i = 0; i < 2; i++) {
        var T = scaleAt(1 - s * ks[i], fx, fy);
        ctx.save();
        clipF();
        ctx.globalAlpha = 0.3;
        old(1 - d, T); neu(d, T);
        ctx.restore();
    }
    ctx.save(); clipF(); useAcc(); ctx.lineWidth = 0.9; ctx.globalAlpha = Math.min(1, s * 4);
    ctx.beginPath();
    for (i = 0; i < 10; i++) {
        var a = i * 0.628, c = Math.cos(a), sn = Math.sin(a);
        seg(fx + c * 6, fy + sn * 6, fx + c * (6 + 14 * s * 1.6), fy + sn * (6 + 14 * s * 1.6));
    }
    ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.beginPath(); circ(fx, fy, 1.2)(); ctx.fill();
    ctx.restore();
    frame();
};

// ── sand ─────────────────────────────────────────────────────────────────
R["sand-bloom"] = function (t) { sandFlow(t, false); frame(); };
R["sand-maelstrom"] = function (t) { sandFlow(t, true); frame(); };

R["sand-donut"] = function (t) {
    var G = grains(), spin = TAU * 0.7;
    function ring(a) { return { x: C.x + 0.35 * F.h * Math.cos(a) * 1.3, y: C.y + 0.35 * F.h * 0.82 * Math.sin(a) }; }
    bStart();
    var fs = 0;
    for (var i = 0; i < G.length; i++) {
        var g = G[i], L = (t - (g.rim * 0.8 + g.h * 0.2) * 0.6) / 0.4, p;
        if (L <= 0) { tick(g.x, g.y); continue; }
        if (L >= 1) { ndot(g.x, g.y); continue; }
        if (L < 0.3) p = { x: lerp(g.x, ring(g.a).x, ss(0, 0.3, L)), y: lerp(g.y, ring(g.a).y, ss(0, 0.3, L)) };
        else if (L < 0.62) p = ring(g.a + spin * (L - 0.3) / 0.32);
        else { var r1 = ring(g.a + spin), e = ss(0.62, 1, L); p = { x: lerp(r1.x, g.x, e), y: lerp(r1.y, g.y, e) }; }
        fs += formF(L);
        if (L > 0.46) ndot(p.x, p.y); else odot(p.x, p.y);
    }
    guide(0.12 + 0.25 * fs / G.length, function () { ell(C.x, C.y, 0.35 * F.h * 1.3, 0.35 * F.h * 0.82); });
    bFlush();
    frame();
};

R["sand-galaxy"] = function (t) {
    bStart();
    var fa = sandShape(t, function (g, tt) {
        var rad = Math.min(1, 2 * g.dl), th = g.a + tt * TAU * (0.4 + 1.3 * (1 - rad));
        return { x: C.x + Math.cos(th) * rad * 0.52 * F.h * 1.5, y: C.y + Math.sin(th) * rad * 0.52 * F.h * 0.42 };
    }, true);
    guide(0.12 + 0.3 * fa, function () { ell(C.x, C.y, 0.52 * F.h * 1.5, 0.22 * F.h); });
    bFlush();
    frame();
};

R["sand-globe"] = function (t) {
    bStart();
    var Rg = 0.47 * F.h;
    var fa = sandShape(t, function (g, tt) {
        var lon = g.u * TAU + tt * TAU * 1.3, lat = (g.v - 0.5) * PI;
        var front = Math.cos(lat) * Math.cos(lon) > 0;
        return { x: C.x + Rg * Math.cos(lat) * Math.sin(lon), y: C.y - Rg * Math.sin(lat), al: front ? 1 : 0.35 };
    }, true);
    guide(0.12 + 0.3 * fa, function () { circ(C.x, C.y, Rg)(); ell(C.x, C.y, Rg, 0.12 * F.h); });
    bFlush();
    frame();
};

R["sand-mobius"] = function (t) {
    bStart();
    var ct = Math.cos(1.15), st = Math.sin(1.15), S = 0.34 * F.h;
    var fa = sandShape(t, function (g, tt) {
        var mu = g.u * TAU + tt * PI * 1.3, mv = (g.v - 0.5) * 2, r = 1 + mv * 0.5 * Math.cos(mu / 2);
        var bx = r * Math.cos(mu), by = r * Math.sin(mu), bz = mv * 0.5 * Math.sin(mu / 2);
        return { x: C.x + S * bx * 1.35, y: C.y - S * (by * ct - bz * st), al: 0.4 + 0.6 * cl(0.5 + 0.5 * (by * st + bz * ct)) };
    }, true);
    // faint band centre line
    guide(0.1 + 0.25 * fa, function () {
        for (var k = 0; k <= 40; k++) {
            var mu = k * TAU / 40 + t * PI * 1.3;
            var x = C.x + S * Math.cos(mu) * 1.35, y = C.y - S * Math.sin(mu) * ct;
            if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
    });
    bFlush();
    frame();
};

R["sand-tornado"] = function (t) {
    bStart();
    var fa = sandShape(t, function (g, tt, L) {
        var rr = 0.44 * F.h * (0.12 + 0.88 * g.v) * 1.15, om = tt * TAU * (1.4 + (1 - g.v) * 2.2);
        var th = g.u * TAU + om + g.h * 0.3, sway = Math.sin(g.v * PI * 1.2 + L * TAU * 0.6) * 0.08 * F.w;
        return { x: C.x + rr * Math.cos(th) + sway, y: C.y - (g.v - 0.5) * 0.86 * F.h, al: 0.4 + 0.6 * (0.5 + 0.5 * Math.sin(th)) };
    }, true);
    guide(0.12 + 0.3 * fa, function () {
        var top = 0.44 * F.h * 1.15, bot = 0.05 * F.h * 1.15;
        seg(C.x - top, F.y + 0.07 * F.h, C.x - bot, F.y + 0.93 * F.h);
        seg(C.x + top, F.y + 0.07 * F.h, C.x + bot, F.y + 0.93 * F.h);
        ell(C.x, F.y + 0.07 * F.h, top, 1.6);
    });
    bFlush();
    frame();
};

R["sand-helix"] = function (t) {
    var G = grains();
    bStart();
    for (var i = 0; i < G.length; i++) {
        var g = G[i];
        var lift = (g.rim * 0.65 + g.h * 0.35) * 0.16, land = 0.62 + g.h2 * 0.16;
        var gg = ss(lift, lift + 0.18, t), sc = ss(land, land + 0.18, t), f = gg * (1 - sc);
        if (f < 0.02) { if (sc > 0.5) ndot(g.x, g.y); else tick(g.x, g.y); continue; }
        var tail = Math.pow(0.45 * g.v + 0.55 * g.h3, 2.4), strand = g.h > 0.5 ? 1 : 0;
        var s = t * 1.3 - 0.14 - tail * 0.95 + strand * 0.38 + (gg - 1 + sc) * 1.15;
        var ax = s * 2.6 * TAU + strand * PI + t * 2.86;
        var sp = { x: C.x + Math.cos(ax) * 0.19 * F.h * 1.6, y: C.y + (s - 0.5) * 0.9 * F.h };
        var p = { x: lerp(g.x, sp.x, f), y: lerp(g.y, sp.y, f) };
        var al = lerp(1, 0.5 + 0.5 * Math.sin(ax), f);
        if (p.y > C.y) ndot(p.x, p.y, al); else odot(p.x, p.y, al);
    }
    ctx.save(); ctx.globalAlpha = 0.35; useLine(); ctx.lineWidth = 0.8;
    ctx.beginPath(); dashed(F.x + 1, C.y, F.x + F.w - 1, C.y, 2, 2); ctx.stroke();
    ctx.restore();
    bFlush();
    frame();
};

R["sand-murmuration"] = function (t) {
    var G = grains();
    bStart();
    for (var i = 0; i < G.length; i++) {
        var g = G[i], home = { x: g.x, y: g.y }, sh = rng(g.row), sh2 = rng(g.row + 30);
        var la, e, p0, p2, w, p;
        // old
        var tt = cl(t * 3.45 - g.u * 0.65 - g.h * 0.2);
        if (tt <= 0) tick(g.x, g.y);
        else if (tt < 0.99) {
            e = ss(0, 1, tt);
            p0 = home; p2 = { x: F.x + F.w + 8, y: C.y + (sh - 0.5) * 1.2 * F.h };
            w = { x: lerp(p0.x, p2.x, 0.25 + sh2 * 0.5), y: C.y + (sh - 0.5) * 0.5 * F.h };
            p = quad(p0, w, p2, e); la = e * TAU * 1.5 + g.h * TAU;
            odot(p.x + Math.cos(la) * 0.25 * F.h * Math.sin(PI * e), p.y + Math.sin(la) * 0.25 * F.h * Math.sin(PI * e));
        }
        // new
        var nt = cl(((t - 0.2) / 0.62 - 0.04) * 2.3 - g.u * 0.65 - g.h * 0.2);
        if (nt >= 1) ndot(g.x, g.y);
        else if (nt >= 0.02) {
            e = ss(0, 1, nt);
            p0 = { x: F.x - 8, y: C.y + (sh2 - 0.5) * 1.2 * F.h }; p2 = home;
            w = { x: lerp(p0.x, p2.x, 0.25 + sh2 * 0.5), y: C.y + (sh - 0.5) * 0.5 * F.h };
            p = quad(p0, w, p2, e); la = e * TAU * 1.5 + g.h * TAU;
            ndot(p.x + Math.cos(la) * 0.25 * F.h * Math.sin(PI * e), p.y + Math.sin(la) * 0.25 * F.h * Math.sin(PI * e));
        }
    }
    bFlush();
    frame();
};

// ── ours ─────────────────────────────────────────────────────────────────
function pips(n) {
    var P = { 1: [[0, 0]], 2: [[-1, -1], [1, 1]], 3: [[-1, -1], [0, 0], [1, 1]], 4: [[-1, -1], [1, -1], [-1, 1], [1, 1]],
              5: [[-1, -1], [1, -1], [0, 0], [-1, 1], [1, 1]], 6: [[-1, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [1, 1]] };
    return P[n];
}
R["random"] = function (t) {
    var e = ss(0, 1, t);
    old(1 - e); neu(e);
    var n = (Math.floor(t * 9) % 6) + 1, ang = (t - 0.55) * PI * 0.9, S = 7;
    ctx.save();
    ctx.translate(C.x, C.y); ctx.rotate(ang);
    ctx.beginPath(); ctx.roundedRect(-S - 1.5, -S - 1.5, 2 * S + 3, 2 * S + 3, 3, 3);
    ctx.save(); ctx.clip(); ctx.clearRect(-S - 3, -S - 3, 2 * S + 6, 2 * S + 6); ctx.restore();
    ctx.beginPath(); ctx.roundedRect(-S, -S, 2 * S, 2 * S, 2.5, 2.5);
    useAcc(); ctx.lineWidth = LW; ctx.stroke();
    var pp = pips(n);
    ctx.beginPath();
    for (var i = 0; i < pp.length; i++) circ(pp[i][0] * S * 0.5, pp[i][1] * S * 0.5, 1.2)();
    ctx.fill();
    ctx.restore();
    frame();
};

R["instant"] = function (t) {
    if (t < 0.5) old(); else neu();
    var flash = 1 - ss(0, 0.12, Math.abs(t - 0.5));
    if (flash > 0.01) dark(0.3 * flash);
    // lightning bolt, cleared behind
    var b = [[3, -9], [-3.5, 1], [0.5, 1], [-3, 9.5], [4.5, -2], [0.5, -2], [3, -9]];
    function path() { for (var i = 0; i < b.length; i++) { if (i === 0) ctx.moveTo(C.x + b[i][0], C.y + b[i][1]); else ctx.lineTo(C.x + b[i][0], C.y + b[i][1]); } ctx.closePath(); }
    ctx.save();
    ctx.lineWidth = 4; ctx.lineJoin = "round";
    ctx.beginPath(); path();
    ctx.globalCompositeOperation = "destination-out";
    ctx.stroke(); ctx.fill();
    ctx.restore();
    ctx.save();
    useAcc(); ctx.lineWidth = 1; ctx.lineJoin = "round";
    ctx.beginPath(); path();
    ctx.globalAlpha = 0.35 + 0.65 * Math.max(flash, t >= 0.5 ? 1 : 0.4);
    ctx.fill();
    ctx.stroke();
    ctx.restore();
    frame();
};

// ── entry point ──────────────────────────────────────────────────────────
function draw(c, key, t, w, h, line, accent) {
    if (!c || w <= 0 || h <= 0) return;
    ctx = c;
    LINE = line;
    ACC = accent;
    ctx.save();
    ctx.clearRect(0, 0, w, h);
    var s = Math.min(w / 64, h / 40);
    ctx.translate((w - 64 * s) / 2, (h - 40 * s) / 2);
    ctx.scale(s, s);
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.lineWidth = LW;
    useLine();
    var fn = R[key] || R["crossfade"];
    fn(cl(t));
    ctx.restore();
    ctx = null;
}
