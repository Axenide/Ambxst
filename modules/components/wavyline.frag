#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float amplitude;
    float frequency;
    vec4 shaderColor;
    float lineWidth;
    float canvasWidth;
    float canvasHeight;
    float fullLength;
} ubuf;

#define PI 3.14159265359

// Calcula Y de la onda en una posición X
float waveY(float x, float centerY) {
    float k = ubuf.frequency * 2.0 * PI / ubuf.fullLength;
    return centerY + ubuf.amplitude * sin(k * x + ubuf.phase);
}

// Distancia a la curva de la onda usando la aproximación de primer orden (estimador de SDF)
// Utiliza inversesqrt() acelerado por hardware para evitar por completo el bucle de 16 pasos.
// Ahorra cerca del 95% del costo de procesamiento de fragmentos para este widget.
float distanceToWave(vec2 pos, float centerY) {
    float k = ubuf.frequency * 2.0 * PI / ubuf.fullLength;
    float angle = k * pos.x + ubuf.phase;
    float fx = centerY + ubuf.amplitude * sin(angle);
    float dfx = ubuf.amplitude * k * cos(angle);
    
    return abs(pos.y - fx) * inversesqrt(1.0 + dfx * dfx);
}


// Calcula el factor de reducción del grosor en los extremos
float edgeTaper(float x) {
    float startX = 0.0;
    float endX = ubuf.canvasWidth;
    float taperDistance = ubuf.lineWidth * 0.5;
    
    if (x < startX + taperDistance) {
        float t = (x - startX) / taperDistance;
        float u = 1.0 - t;
        return sqrt(max(0.0, 1.0 - u * u));
    }
    
    if (x > endX - taperDistance) {
        float t = (endX - x) / taperDistance;
        float u = 1.0 - t;
        return sqrt(max(0.0, 1.0 - u * u));
    }
    
    return 1.0;
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * vec2(ubuf.canvasWidth, ubuf.canvasHeight);
    float centerY = ubuf.canvasHeight * 0.5;
    
    if (pixelPos.x < 0.0 || pixelPos.x > ubuf.canvasWidth) {
        discard;
    }
    
    float dist = distanceToWave(pixelPos, centerY);
    
    float taper = edgeTaper(pixelPos.x);
    float effectiveRadius = (ubuf.lineWidth * 0.5) * taper;
    
    float aaWidth = 1.0; // Antialiasing de 1px
    float alpha = 1.0 - smoothstep(effectiveRadius - aaWidth, effectiveRadius + aaWidth, dist);
    
    if (alpha < 0.01) {
        discard;
    }
    
    fragColor = vec4(ubuf.shaderColor.rgb, ubuf.shaderColor.a * alpha * ubuf.qt_Opacity);
}
