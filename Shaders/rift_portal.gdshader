shader_type canvas_item;

uniform float white_cutoff : hint_range(0.7, 1.0) = 0.93;
uniform float softness : hint_range(0.0, 0.2) = 0.06;
uniform float pulse_strength : hint_range(0.0, 0.2) = 0.035;
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;
	vec4 color = texture(TEXTURE, centered_uv / pulse + vec2(0.5));

	float maximum = max(color.r, max(color.g, color.b));
	float minimum = min(color.r, min(color.g, color.b));
	float saturation = maximum - minimum;
	float whiteness = minimum - saturation * 2.0;
	float background_alpha = 1.0 - smoothstep(
		white_cutoff - softness,
		white_cutoff,
		whiteness
	);

	color.a *= background_alpha;
	COLOR = color;
}
