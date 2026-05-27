#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float angle;
    float canvasWidth;
    float canvasHeight;
    int numStops;
    vec4 stopColor0;
    vec4 stopColor1;
    vec4 stopColor2;
    vec4 stopColor3;
    vec4 stopColor4;
    vec4 stopColor5;
    vec4 stopColor6;
    vec4 stopColor7;
    vec4 stopPositionsPack0;
    vec4 stopPositionsPack1;
} ubuf;

void main() {
    qt_TexCoord0 = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
