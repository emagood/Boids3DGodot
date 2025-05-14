shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform float chroma_strength : hint_range(0.0, 0.05) = 0.01;
uniform float barrel_strength : hint_range(0.0, 0.5) = 0.1;

// where the chroma/warp start fading in (0=center, 1=edge)
uniform float effect_falloff_start : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    // get UV and center it
    vec2 uv = SCREEN_UV;
    vec2 centered = uv - 0.5;

    // correct for non-square screens
    float aspect = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
    vec2 adj = vec2(centered.x * aspect, centered.y);

    // normalized radius [0 at center, 1 at furthest corner]
    float r = length(adj) / length(vec2(0.5 * aspect, 0.5));

    // smooth mask: 0 until falloff_start, ramps to 1 at edge
    float mask = smoothstep(effect_falloff_start, 1.0, r);

    // barrel (fisheye) distortion: r' = r * (1 + k * r^2)
    float k = barrel_strength;
    float r2 = r * r;
    float factor = (1.0 + k * r2);
    vec2 warped = centered * factor + 0.5;

    // chromatic offsets
    vec2 chroma_off = centered * (chroma_strength * mask);

    // sample each channel with its own offset
    float red   = textureLod(SCREEN_TEXTURE, warped + chroma_off, 0.0).r;
    float green = textureLod(SCREEN_TEXTURE, warped,                 0.0).g;
    float blue  = textureLod(SCREEN_TEXTURE, warped - chroma_off,   0.0).b;

    COLOR = vec4(red, green, blue, 1.0);
}