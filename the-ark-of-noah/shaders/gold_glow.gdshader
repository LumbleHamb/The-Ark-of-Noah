shader_type canvas_item;

// Gold Glow Shader
// Provides a short golden pulse effect when a button is pressed.
// Drive glow_intensity from script: set_shader_parameter("glow_intensity", 1.0)
// and animate it back to 0.0 over ~0.2s.

uniform float glow_intensity: hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color: source_color = vec4(1.0, 0.84, 0.0, 1.0); // Gold
uniform float glow_radius: hint_range(0.0, 0.5) = 0.15;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	
	// Compute distance from UV center for a radial glow
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	
	// Glow intensity falls off from center to edges
	float glow_falloff = 1.0 - smoothstep(0.0, glow_radius, dist);
	
	// Only apply glow on visible pixels (skip transparent areas)
	float alpha_mask = tex_color.a;
	
	// Blend: base texture + golden glow overlay
	vec3 glow_rgb = glow_color.rgb * glow_intensity * glow_falloff * alpha_mask;
	vec3 final_rgb = tex_color.rgb + glow_rgb;
	
	COLOR = vec4(final_rgb, tex_color.a);
}
