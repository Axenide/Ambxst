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

// Distancia a la curva de la onda usando búsqueda directa (método robusto)
float distanceToWave(vec2 pos, float centerY) {
    // --- PASO 1: Definir la ventana de búsqueda ---
    // El punto más cercano en la onda no estará más lejos horizontalmente
    // que la amplitud. Usamos un margen de seguridad (ej. 1.2).
    float searchRadius = ubuf.amplitude * 1.2 + ubuf.lineWidth;
    float searchStart = max(0.0, pos.x - searchRadius);
    float searchEnd = min(ubuf.canvasWidth, pos.x + searchRadius);

    // --- PASO 2: Muestrear puntos y encontrar la distancia mínima ---
    // Número fijo de pasos. 16 da ~2px de precisión en la onda.
    // 40 era el valor anterior — cada paso ejecuta un sin() y un dot(),
    // reducirlo a la mitad ahorra ~60% de cómputo por píxel.
    const int numSteps = 16;
    
    float minDistanceSq = 1.0e+20; // Empezar con un número muy grande

    for (int i = 0; i <= numSteps; ++i) {
        float t = float(i) / float(numSteps);
        float sampleX = mix(searchStart, searchEnd, t);
        
        vec2 wavePoint = vec2(sampleX, waveY(sampleX, centerY));
        
        // Calcular la distancia al cuadrado (más rápido dentro de un bucle)
        vec2 vecToPixel = pos - wavePoint;
        float distSq = dot(vecToPixel, vecToPixel);
        
        // Actualizar el mínimo
        minDistanceSq = min(minDistanceSq, distSq);
    }

    // Devolver la distancia real (raíz cuadrada)
    return sqrt(minDistanceSq);
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
