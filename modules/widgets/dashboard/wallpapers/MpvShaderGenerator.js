.pragma library

function generate(paletteColors) {
    // Safety check
    if (!paletteColors || paletteColors.length === 0) {
        // Return a passthrough shader if no palette
        return `//!HOOK MAIN
//!BIND HOOKED
//!DESC Ambxst[+] Passthrough
void main() {
    HOOKED_col = HOOKED_tex(HOOKED_pos);
}`;
    }

    let unrolledLogic = "";
    
    // Unroll the loop to ensure compatibility with all GLES drivers
    for (let i = 0; i < paletteColors.length; i++) {
        let color = paletteColors[i];
        
        let r = (typeof color.r === 'number' ? color.r : 0.0).toFixed(5);
        let g = (typeof color.g === 'number' ? color.g : 0.0).toFixed(5);
        let b = (typeof color.b === 'number' ? color.b : 0.0).toFixed(5);
        
        unrolledLogic += `
    {
        vec3 pColor = vec3(${r}, ${g}, ${b});
        vec3 diff = color - pColor;
        
        // Perceptual weighting (Red: 0.299, Green: 0.587, Blue: 0.114)
        // This makes the distance match human perception better than raw Euclidean
        vec3 weightedDiff = diff * vec3(0.55, 0.77, 0.34); // Sqrt of standard luma weights roughly
        float distSq = dot(weightedDiff, weightedDiff); 
        
        // Track closest color for fallback
        if (distSq < minDistSq) {
            minDistSq = distSq;
            closestColor = pColor;
        }

        float weight = exp(-distributionSharpness * distSq);
        accumulatedColor += pColor * weight;
        totalWeight += weight;
    }
`;
    }

    return `//!HOOK MAIN
//!BIND HOOKED
//!DESC Ambxst[+] Palette Tint

// Simple dithering function
float noise_random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 hook() {
    vec4 tex = HOOKED_tex(HOOKED_pos);
    vec3 color = tex.rgb;

    // Add slight dithering to input to break banding before quantization
    float noise = (noise_random(HOOKED_pos * 100.0 + sin(HOOKED_pos.x)) - 0.5) / 64.0;
    color += noise;

    vec3 accumulatedColor = vec3(0.0);
    float totalWeight = 0.0;
    float minDistSq = 1000.0;
    vec3 closestColor = vec3(0.0);
    
    // Increased sharpness for cleaner separation (was 20.0)
    // 40.0 makes it stick tighter to palette colors
    float distributionSharpness = 40.0; 

    // Unrolled palette comparison
    ${unrolledLogic}

    vec3 finalColor;

    // If we have a decent match blend, use it.
    // Otherwise snap to closest to avoid "holes" or dark spots.
    if (totalWeight > 0.0001) {
        finalColor = accumulatedColor / totalWeight;
    } else {
        finalColor = closestColor;
    }
    
    // Mix in the closest color slightly to reinforce structure if the blend is too muddy
    // finalColor = mix(finalColor, closestColor, 0.2);

    return vec4(finalColor, tex.a);
}
`;
}
