shader_type canvas_item;

uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.8;
uniform vec4 glow_color : source_color = vec4(0.4, 0.2, 0.05, 1.0);

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    
    float pulse = (sin(TIME * pulse_speed) + 1.0) / 2.0;
    float glow = glow_strength * (0.7 + pulse * 0.3);
    
    vec3 final_color = mix(tex.rgb, glow_color.rgb, tex.a * 0.3);
    final_color += glow_color.rgb * glow * tex.a * 0.2;
    
    COLOR = vec4(final_color, tex.a);
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
