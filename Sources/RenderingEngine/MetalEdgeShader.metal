#include <metal_stdlib>
using namespace metal;

struct SegmentUniforms {
    float2 resolution;
    float4 edgeRect; // x, y, width, height
    float4 color;    // r, g, b, a (DisplayP3/sRGB)
    float softness;
    float bloom;
    float cornerRadius;
};

// Signed Distance Field for a 2D rounded box centered at origin
float sdRoundedBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Multi-lobe soft falloff: ambient bloom + body + tight core highlight
fragment float4 edgeSegmentFragmentShader(
    float4 position [[position]],
    constant SegmentUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = position.xy;
    float2 rectCenter = uniforms.edgeRect.xy + uniforms.edgeRect.zw * 0.5;
    float2 rectHalfSize = uniforms.edgeRect.zw * 0.5;
    float radius = max(uniforms.cornerRadius, 1.0);
    
    float dist = sdRoundedBox(uv - rectCenter, rectHalfSize, radius);
    
    float soft = max(1.0, uniforms.softness);
    float bloom = max(1.0, uniforms.bloom);
    
    // Outer atmospheric bloom (wide, soft)
    float ambient = 1.0 - smoothstep(0.0, bloom * 2.4, dist);
    ambient = pow(saturate(ambient), 1.6) * 0.28;
    
    // Body glow (medium falloff outside, soft fill inside)
    float bodyOut = 1.0 - smoothstep(0.0, soft * 1.1, dist);
    float bodyIn  = smoothstep(-soft * 0.85, 0.0, dist);
    float body = saturate(bodyOut * bodyIn) * 0.72;
    
    // Tight core near the zero-iso (physical edge)
    float core = 1.0 - smoothstep(0.0, soft * 0.28, abs(dist));
    core = pow(saturate(core), 1.35) * 0.55;
    
    float totalAlpha = saturate(ambient + body + core) * uniforms.color.a;
    if (totalAlpha <= 0.004) {
        discard_fragment();
    }
    
    // Pre-multiplied-style additive-friendly output
    float3 rgb = uniforms.color.rgb * totalAlpha;
    return float4(rgb, totalAlpha);
}
