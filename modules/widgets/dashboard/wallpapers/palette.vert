#version 440

// Input vertex attributes from Qt/OpenGL
layout(location = 0) in vec4 qt_Vertex;        // Vertex position
layout(location = 1) in vec2 qt_MultiTexCoord0; // Original texture coordinates

// Outputs to fragment shader
layout(location = 0) out vec2 qt_TexCoord0;     // Pass-through texture coords
layout(location = 1) out vec4 qt_UVAdjustment;  // UV transform for aspect-crop (xy = offset, zw = scale)

// Uniform buffer matching the Qt Quick ShaderEffect interface
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;      // Model-view-projection matrix (includes viewport transform)
    float qt_Opacity;    // Global opacity from QML
    float paletteSize;   // Number of colors in the palette (user parameter)
    float texWidth;      // Actual width of the source texture in pixels
    float texHeight;     // Actual height of the source texture in pixels
} ubuf;

void main() {
    // Pass the texture coordinate straight to the fragment shader.
    // The fragment shader will then apply the UV adjustment for aspect-crop.
    qt_TexCoord0 = qt_MultiTexCoord0;

    // Compute aspect ratios.
    // The source image aspect is simply width/height.
    // The viewport aspect can be approximated from the matrix's X and Y scale components.
    // Note: This is a common approximation; a more robust method would use separate viewport dimensions,
    // but for ShaderEffect with preserveAspectCrop, this works.
    float imageAspect = ubuf.texWidth / ubuf.texHeight;
    float viewportAspect = ubuf.qt_Matrix[0][0] / ubuf.qt_Matrix[1][1]; // ratio of X scale to Y scale

    vec2 scale = vec2(1.0);
    vec2 offset = vec2(0.0);

    // Determine how to scale UVs to achieve "PreserveAspectCrop" behavior.
    // If the image is wider than the viewport, we need to scale the X coordinate down
    // (so the image fits vertically) and then offset to center the crop.
    if (imageAspect > viewportAspect) {
        // Image is wider: crop left/right.
        scale.x = viewportAspect / imageAspect;
        offset.x = (1.0 - scale.x) * 0.5;
    } else {
        // Image is taller or equal: crop top/bottom.
        scale.y = imageAspect / viewportAspect;
        offset.y = (1.0 - scale.y) * 0.5;
    }

    // Pack the offset and scale into a single vec4 for the fragment shader.
    qt_UVAdjustment = vec4(offset, scale);

    // Transform the vertex position by the matrix.
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}