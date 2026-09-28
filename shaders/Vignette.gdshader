shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color: source_color = vec4(1.0, 0.0, 0.0, 1.0);
void fragment() {
    vec2 uv = UV;
    float vignette = uv.x * (1.0 - uv.x) * uv.y * (1.0 - uv.y);
    vignette = clamp(pow(vignette * 15.0, 0.25), 0.0, 1.0);
    float final_intensity = intensity * (1.0 - vignette);
    COLOR = vec4(vignette_color.rgb, final_intensity * 0.7);
}