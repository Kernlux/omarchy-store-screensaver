#version 440
// Omarchy Store Screensaver: Mystify on the GPU.
// Every corner bounces around the screen (a triangle wave of start + velocity * time), so the shader
// can work out each shape and each fading echo itself: the CPU only sends the time each frame.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;          // seconds (already multiplied by speed)
    float aspect;     // width / height
    float shapes;     // 1..3
    float lw;         // line half-width, in screen heights
    float ncol;       // colours used in the palette (2..6)
    vec4 c0; vec4 c1; vec4 c2; vec4 c3; vec4 c4; vec4 c5;
    vec4 bg0; vec4 bg1;
    vec4 p0; vec4 p1; vec4 p2; vec4 p3; vec4 p4; vec4 p5;
    vec4 p6; vec4 p7; vec4 p8; vec4 p9; vec4 p10; vec4 p11;
};

const int ECHOES = 7;
const float GAP = 0.16;      // seconds between echoes

vec3 pal(float ph) {
    vec3 c[6] = vec3[6](c0.rgb, c1.rgb, c2.rgb, c3.rgb, c4.rgb, c5.rgb);
    int n = int(ncol);
    float x = fract(ph) * float(n);
    int i = int(floor(x));
    float f = smoothstep(0.0, 1.0, x - float(i));
    vec3 a = c[0], b = c[0];
    for (int k = 0; k < 6; k++) {
        if (k == i % n) a = c[k];
        if (k == (i + 1) % n) b = c[k];
    }
    return mix(a, b, f);
}

float tri(float u) { return 1.0 - abs(mod(u, 2.0) - 1.0); }

vec2 corner(vec4 p, float tt) {
    return vec2((0.03 + 0.94 * tri(p.x + p.z * tt)) * aspect, 0.04 + 0.92 * tri(p.y + p.w * tt));
}

float seg(vec2 q, vec2 a, vec2 b) {
    vec2 pa = q - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 q = vec2(uv.x * aspect, uv.y);

    // background + two slow aurora glows
    vec3 col = mix(bg0.rgb, bg1.rgb, uv.y);
    for (int b = 0; b < 2; b++) {
        vec2 c = vec2((0.5 + 0.32 * sin(t * 0.13 + float(b) * 2.4)) * aspect, 0.5 + 0.28 * cos(t * 0.11 + float(b) * 1.7));
        float d = length(q - c);
        col += pal(t * 0.02 + float(b) * 0.5) * 0.16 * smoothstep(0.9, 0.0, d);
    }

    vec4 P[12] = vec4[12](p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11);
    vec3 acc = vec3(0.0);
    int ns = int(shapes);
    for (int s = 0; s < 3; s++) {
        if (s >= ns) break;
        for (int e = 0; e < ECHOES; e++) {
            float tt = t - float(e) * GAP;
            vec2 a = corner(P[s * 4 + 0], tt), b = corner(P[s * 4 + 1], tt);
            vec2 c = corner(P[s * 4 + 2], tt), d = corner(P[s * 4 + 3], tt);
            float dist = min(min(seg(q, a, b), seg(q, b, c)), min(seg(q, c, d), seg(q, d, a)));
            float fade = 1.0 - float(e) / float(ECHOES + 1);
            float core = smoothstep(lw * (e == 0 ? 1.6 : 1.0), 0.0, dist);
            float glow = exp(-dist * dist / (lw * lw * 60.0)) * 0.22;
            acc += pal(t * 0.05 + float(s) / 3.0 + float(e) * 0.012) * (core * (e == 0 ? 1.0 : 0.6) + glow) * fade;
        }
    }
    col += acc;
    col = 1.0 - exp(-col * 1.15);       // soft highlight roll-off, no harsh clipping
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
