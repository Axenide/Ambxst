#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float blendFactor;
    vec2 iResolution;
    int blockSize;
    int searchRadius;
    float motionThreshold;
    int debugMode;
    int isOriginalFrame;
    int frameCounter;
} ubuf;

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}