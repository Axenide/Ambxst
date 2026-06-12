#version 440

#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D paletteTexture;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    int paletteSize;
    float sharpness;
    float mixStrength;
    float texWidth;
    float texHeight;
} ubuf;

void main() {
    vec4 tex = texture(source, qt_TexCoord0);
    vec3 color = tex.rgb;
    
    if (tex.a < 0.001) {
        fragColor = vec4(0.0);
        return;
    }
    
    int size = ubuf.paletteSize;
    if (size <= 0 || ubuf.mixStrength <= 0.0) {
        fragColor = tex * ubuf.qt_Opacity;
        return;
    }
    
    mediump vec3 accum = vec3(0.0);
    mediump float sumW = 0.0;
    
    const float invLn2 = 1.44269504;
    float sharpness = ubuf.sharpness;
    
    // Loop bound = 32 (max palette size is 26, gives margin)
    // Previously 128 — the GLSL compiler would unroll ALL 128 iterations
    // wasting GPU cycles on break checks. 32 fits in 1-2 warp/wavefront.
    for (int i = 0; i < 32; ++i) {
        if (i >= size) break;
        
        vec3 pColor = texelFetch(paletteTexture, ivec2(i, 0), 0).rgb;
        vec3 diff = color - pColor;
        mediump float distSq = dot(diff, diff);
        mediump float w = exp2(-sharpness * distSq * invLn2);
        
        accum += pColor * w;
        sumW  += w;
    }
    
    vec3 finalColor = accum / (sumW + 1e-5);
    vec3 mixed = mix(color, finalColor, ubuf.mixStrength);
    
    fragColor = vec4(mixed * tex.a, tex.a) * ubuf.qt_Opacity;
}