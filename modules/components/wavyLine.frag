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

// Función para suavizar los bordes laterales con forma más redondeada
float roundedEdge(float x, float width, float radius) {
    float distFromLeft = x;
    float distFromRight = width - x;
    float edgeDist = min(distFromLeft, distFromRight);
    
    // Usar una curva más suave (cuadrática) para un efecto más redondeado
    if (edgeDist >= radius) return 1.0;
    float t = edgeDist / radius;
    return t * t * (3.0 - 2.0 * t); // Smootherstep para mayor suavidad
}

// Calcula la cobertura de un punto considerando la derivada
float coverage(vec2 pos, float centerY) {
    float x = pos.x;
    float k = ubuf.frequency * 2.0 * PI / ubuf.fullLength;
    
    // Valor de la onda
    float waveValue = sin(k * x + ubuf.phase);
    float waveY = centerY + ubuf.amplitude * waveValue;
    
    // Derivada de la onda para calcular el ancho efectivo
    float derivative = abs(cos(k * x + ubuf.phase) * k * ubuf.amplitude);
    
    // El ancho efectivo aumenta con la pendiente de la onda
    float effectiveWidth = ubuf.lineWidth * 1.0 * sqrt(1.0 + derivative * derivative);
    
    // Distancia del píxel a la línea de la onda
    float dist = abs(pos.y - waveY);
    
    // Sharp cutoff for full opacity
    float halfWidth = effectiveWidth * 0.5;
    
    return step(dist, halfWidth);
}

void main() {
    vec2 pixelPos = qt_TexCoord0 * vec2(ubuf.canvasWidth, ubuf.canvasHeight);
    float centerY = ubuf.canvasHeight * 0.5;
    
    // Supersampling 3x3: muestrea 9 puntos alrededor del píxel
    float alpha = 0.0;
    float samples = 0.0;
    
    for (float dy = -0.66; dy <= 0.66; dy += 0.66) {
        for (float dx = -0.66; dx <= 0.66; dx += 0.66) {
            vec2 samplePos = pixelPos + vec2(dx, dy);
            alpha += coverage(samplePos, centerY);
            samples += 1.0;
        }
    }
    
    alpha /= samples;
    
    // No edge fading for full opacity
    
    if (alpha < 0.5) {
        discard;
    }
    
    fragColor = vec4(ubuf.shaderColor.rgb, ubuf.shaderColor.a * alpha * ubuf.qt_Opacity);
}
