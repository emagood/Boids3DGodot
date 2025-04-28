shader_type spatial;

render_mode blend_mix;

uniform float transparency : hint_range(0.0, 1.0) = 0.5;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float fade_strength : hint_range(0.1, 10.0) = 2.0; // how fast it fades at the edges

void fragment() {
    vec3 normal = normalize(NORMAL);
    float fade = pow(abs(normal.y), fade_strength); // based on sphere's normal direction

    ALBEDO = albedo_color.rgb;
    ALPHA = albedo_color.a * transparency * fade;
}
