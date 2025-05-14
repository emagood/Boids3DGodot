shader_type spatial;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

uniform float time : hint_range(0, 100);
uniform float strength = 0.02; // distortion strength
uniform float edge_fade = 2.5; // higher = distortion only at the edges
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    vec2 uv = SCREEN_UV;

    // Distance from center of screen (0 = center, 1 = edge)
    float dist = distance(uv, vec2(0.5));

    // Fade effect: stronger at edges
    float fade = pow(dist, edge_fade);

    // Create sine-wave distortion
    vec2 offset;
    offset.x = sin(uv.y * 20.0 + time * 2.0) * strength * fade;
    offset.y = cos(uv.x * 25.0 + time * 1.5) * strength * fade;

    ALBEDO = texture(screen_texture, uv + offset).rgb;
}
