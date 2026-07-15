shader_type canvas_item;

uniform float movement_amount : hint_range(0.0, 1.0) = 0.0;
uniform float squash_strength : hint_range(0.0, 0.25) = 0.08;
uniform float walk_speed : hint_range(0.0, 30.0) = 12.0;
uniform float bottom_anchor = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rarity_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rarity_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float slow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 slow_color : source_color = vec4(0.25, 0.78, 1.0, 1.0);

void vertex() {
	float step = abs(sin(TIME * walk_speed));
	float squash = step * squash_strength * movement_amount;

	VERTEX.y = mix(VERTEX.y, bottom_anchor, squash);
}

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV) * COLOR;
	float rarity_pulse = 0.82 + 0.18 * sin(TIME * 4.0);
	vec4 rarity_tinted = mix(
		texture_color,
		vec4(rarity_color.rgb, texture_color.a),
		rarity_amount * rarity_pulse * texture_color.a
	);

	float slow_band = smoothstep(
		0.35,
		1.0,
		abs(sin((UV.y + TIME * 0.55) * 18.0))
	);
	vec3 slow_rgb = mix(
		rarity_tinted.rgb,
		slow_color.rgb,
		slow_amount * (0.35 + slow_band * 0.35) * rarity_tinted.a
	);
	vec4 status_tinted = vec4(slow_rgb, rarity_tinted.a);

	COLOR = mix(status_tinted, flash_color, flash_amount * texture_color.a);
}
