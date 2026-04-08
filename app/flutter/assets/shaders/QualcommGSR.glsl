// Qualcomm GSR — Edge-Adaptive Upscaler for Adreno
//
// Implements gradient-based edge detection with
// directional interpolation, optimized for mobile
// GPUs (Adreno 600+). Based on Qualcomm's Game
// Super Resolution approach.
//
// Usage: mpv --glsl-shaders=QualcommGSR.glsl
//
// See docs/video_upscaling_spec.md Phase 4.

//!HOOK MAIN
//!BIND HOOKED
//!DESC Qualcomm GSR Edge-Adaptive Upscaler

#define SHARPNESS 0.5
#define EDGE_THRESHOLD 0.05

vec4 hook() {
    vec2 pos = HOOKED_pos;
    vec2 pt = HOOKED_pt;

    // Sample 3x3 neighborhood (luma).
    float tl = dot(HOOKED_texOff(vec2(-1, -1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float tc = dot(HOOKED_texOff(vec2( 0, -1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float tr = dot(HOOKED_texOff(vec2( 1, -1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float ml = dot(HOOKED_texOff(vec2(-1,  0)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float mc = dot(HOOKED_texOff(vec2( 0,  0)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float mr = dot(HOOKED_texOff(vec2( 1,  0)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float bl = dot(HOOKED_texOff(vec2(-1,  1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float bc = dot(HOOKED_texOff(vec2( 0,  1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));
    float br = dot(HOOKED_texOff(vec2( 1,  1)).rgb,
                   vec3(0.2126, 0.7152, 0.0722));

    // Sobel gradient estimation.
    float gx = -tl - 2.0*ml - bl
               + tr + 2.0*mr + br;
    float gy = -tl - 2.0*tc - tr
               + bl + 2.0*bc + br;

    float mag = sqrt(gx * gx + gy * gy);

    vec4 color;

    if (mag > EDGE_THRESHOLD) {
        // Edge detected — interpolate along edge
        // direction to avoid crossing it.
        float angle = atan(gy, gx);

        // Compute two sample points along the edge.
        vec2 dir = vec2(cos(angle + 1.5708),
                        sin(angle + 1.5708));
        dir *= pt;

        vec4 s1 = HOOKED_tex(pos + dir * 0.5);
        vec4 s2 = HOOKED_tex(pos - dir * 0.5);
        color = mix(s1, s2, 0.5);
    } else {
        // Smooth region — use 4-tap Lanczos2 kernel
        // for clean upscale.
        vec4 sum = vec4(0.0);
        float wt = 0.0;

        for (int y = -1; y <= 2; y++) {
            for (int x = -1; x <= 2; x++) {
                vec2 off = vec2(float(x), float(y));
                vec2 d = fract(pos / pt) - off;
                float lx = d.x == 0.0 ? 1.0 :
                    sin(3.14159 * d.x) *
                    sin(3.14159 * d.x / 2.0) /
                    (3.14159 * 3.14159 *
                     d.x * d.x / 2.0);
                float ly = d.y == 0.0 ? 1.0 :
                    sin(3.14159 * d.y) *
                    sin(3.14159 * d.y / 2.0) /
                    (3.14159 * 3.14159 *
                     d.y * d.y / 2.0);
                float w = lx * ly;
                sum += HOOKED_texOff(off) * w;
                wt += w;
            }
        }
        color = sum / wt;
    }

    // Optional sharpening pass.
    if (SHARPNESS > 0.0) {
        vec4 center = HOOKED_texOff(vec2(0, 0));
        vec4 blur = (
            HOOKED_texOff(vec2(-1, 0)) +
            HOOKED_texOff(vec2( 1, 0)) +
            HOOKED_texOff(vec2( 0,-1)) +
            HOOKED_texOff(vec2( 0, 1))
        ) * 0.25;
        color += (center - blur) * SHARPNESS;
    }

    return clamp(color, 0.0, 1.0);
}
