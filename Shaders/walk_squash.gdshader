shader_type canvas_item;

uniform float movement_amount : hint_range(0.0, 1.0) = 0.0;
uniform float squash_strength : hint_range(0.0, 0.25) = 0.08;
uniform float walk_speed : hint_range(0.0, 30.0) = 12.0;
uniform float bottom_anchor = 0.0;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	float step = abs(sin(TIME * walk_speed));
	float squash = step * squash_strength * movement_amount;

	VERTEX.y = mix(VERTEX.y, bottom_anchor, squash);
}

void fragment() {
	vec4 texture_color = texture(TEXTURE, UV) * COLOR;
	COLOR = mix(texture_color, flash_color, flash_amount * texture_color.a);
}
