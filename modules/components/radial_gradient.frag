#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float centerX;
    float centerY;
    float canvasWidth;
    float canvasHeight;
    int numStops;
    // implicit std140 padding to 16-byte alignment before first vec4
    vec4 stopColor0;
    vec4 stopColor1;
    vec4 stopColor2;
    vec4 stopColor3;
    vec4 stopColor4;
    vec4 stopColor5;
    vec4 stopColor6;
    vec4 stopColor7;
    vec4 stopPositionsPack0; // positions 0-3 in xyzw
    vec4 stopPositionsPack1; // positions 4-7 in xyzw
} ubuf;

float getStopPos(int i) {
    if (i < 4) {
        if (i == 0) return ubuf.stopPositionsPack0.x;
        if (i == 1) return ubuf.stopPositionsPack0.y;
        if (i == 2) return ubuf.stopPositionsPack0.z;
        return ubuf.stopPositionsPack0.w;
    } else {
        if (i == 4) return ubuf.stopPositionsPack1.x;
        if (i == 5) return ubuf.stopPositionsPack1.y;
        if (i == 6) return ubuf.stopPositionsPack1.z;
        return ubuf.stopPositionsPack1.w;
    }
}

vec4 getStopColor(int i) {
    if (i == 0) return ubuf.stopColor0;
    if (i == 1) return ubuf.stopColor1;
    if (i == 2) return ubuf.stopColor2;
    if (i == 3) return ubuf.stopColor3;
    if (i == 4) return ubuf.stopColor4;
    if (i == 5) return ubuf.stopColor5;
    if (i == 6) return ubuf.stopColor6;
    return ubuf.stopColor7;
}

void main() {
    vec2 pos = qt_TexCoord0;
    vec2 center = vec2(ubuf.centerX, ubuf.centerY);
    vec2 d = pos - center;

    float dist = length(d);
    float t = clamp(dist, 0.0, 1.0);

    // Antialiasing: pixel-width smoothing for sharp transitions
    float fw = fwidth(t) * 0.5;

    // Procedural gradient: interpolate between stops with AA
    vec4 color = getStopColor(0);
    for (int i = 1; i < 8; i++) {
        if (i >= ubuf.numStops) break;
        float posI = getStopPos(i);
        float posPrev = getStopPos(i - 1);
        float range = posI - posPrev;
        float localT = smoothstep(posPrev - fw, posI + fw, t);
        if (range > fw * 2.0) {
            localT = clamp((t - posPrev) / range, 0.0, 1.0);
        }
        color = mix(color, getStopColor(i), localT);
    }

    fragColor = color * ubuf.qt_Opacity;
}
