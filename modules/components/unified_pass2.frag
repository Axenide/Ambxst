#version 440
precision mediump float;

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    vec2 texelSize;
    float borderWidth;
    vec4 borderColor;
    vec4 shadowColor;
    vec2 shadowOffset;
    float maskEnabled;
    float maskInverted;
    float drawSource;
} ubuf;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D intermediate;
layout(binding = 3) uniform sampler2D maskSource;

void main() {
    vec4 srcColor = texture(source, qt_TexCoord0);
    float srcAlpha = srcColor.a;
    
    // Vertical blur for shadow
    float blurredAlpha = 0.0;
    float r = clamp(ubuf.radius, 1.0, 16.0); // Restored range
    float totalWeight = 0.0;
    
    vec2 shadowCoord = qt_TexCoord0 - ubuf.shadowOffset * ubuf.texelSize;
    
    for (int i = -16; i <= 16; i++) {
        float fi = float(i);
        if (fi < -r || fi > r) continue;
        
        float weight = exp(-0.5 * pow(fi * 3.0 / r, 2.0));
        blurredAlpha += texture(intermediate, shadowCoord + vec2(0.0, fi * ubuf.texelSize.y)).a * weight;
        totalWeight += weight;
    }
    blurredAlpha /= totalWeight;
    
    // Dilation for border
    float dilatedAlpha = 0.0;
    float bw = max(ubuf.borderWidth, 0.0);
    if (bw > 0.0) {
        // Optimized: 16 iterations (compromise between 24 and 12)
        for (int i = 0; i < 16; i++) {
            float angle = float(i) * (2.0 * 3.14159265 / 16.0);
            vec2 offset = vec2(cos(angle), sin(angle)) * bw;
            dilatedAlpha = max(dilatedAlpha, texture(source, qt_TexCoord0 + offset * ubuf.texelSize).a);
        }
    } else {
        dilatedAlpha = srcAlpha;
    }
    
    // Composition using 'over' blending principles
    vec4 result = ubuf.drawSource > 0.5 ? srcColor : vec4(0.0);
    
    // Border: Only outside the source
    // Precision fix: Ensure border doesn't draw on semi-transparent source pixels
    // Use a threshold for "inside" to keep border on the outside
    float isInside = step(0.1, srcAlpha); 
    float borderMask = clamp(dilatedAlpha - isInside, 0.0, 1.0);
    
    vec4 border = ubuf.borderColor * borderMask;
    result = result + border * (1.0 - result.a);
    
    // Shadow: Only outside the dilated border
    float shadowMask = clamp(blurredAlpha - dilatedAlpha, 0.0, 1.0);
    vec4 shadow = ubuf.shadowColor * shadowMask;
    result = result + shadow * (1.0 - result.a);
    
    // Handle external mask if enabled
    if (ubuf.maskEnabled > 0.5) {
        float m = texture(maskSource, qt_TexCoord0).a;
        if (ubuf.maskInverted > 0.5) m = 1.0 - m;
        result *= m; // Apply mask to final result
    }
    
    fragColor = result * ubuf.qt_Opacity;
}
    
    fragColor = result * ubuf.qt_Opacity;
}
    
    // Border: Only outside the source
    float borderMask = clamp(dilatedAlpha - srcAlpha, 0.0, 1.0);
    vec4 border = ubuf.borderColor * borderMask;
    result = result + border * (1.0 - result.a);
    
    // Shadow: Only outside the dilated border
    float shadowMask = clamp(blurredAlpha - dilatedAlpha, 0.0, 1.0);
    vec4 shadow = ubuf.shadowColor * shadowMask;
    result = result + shadow * (1.0 - result.a);
    
    // Handle external mask if enabled
    if (ubuf.maskEnabled > 0.5) {
        float m = texture(maskSource, qt_TexCoord0).a;
        if (ubuf.maskInverted > 0.5) m = 1.0 - m;
        result *= m; // Apply mask to final result
    }
    
    fragColor = result * ubuf.qt_Opacity;
}
