shader_type canvas_item;

uniform sampler2D normal_map_tex;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    vec3 normal = texture(normal_map_tex, UV).rgb;
    normal = normalize(normal * 2.0 - 1.0);
    COLOR = tex;
    NORMAL = normal;
}