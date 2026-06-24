shader_type canvas_item;

// Page Curl Shader
// Animates a page curl effect from one side of the texture to the other.
// curl_amount: 0.0 = flat (no curl), 1.0 = fully curled from the edge
// curl_direction: 1.0 = right-to-left (next page), -1.0 = left-to-right (prev page)

uniform float curl_amount: hint_range(0.0, 1.0) = 0.0;
uniform float curl_direction: hint_range(-1.0, 1.0) = 1.0;
uniform float page_width: hint_range(128.0, 512.0) = 256.0;

// Shadow/lighting parameters to give the curl depth
uniform vec4 shadow_color: source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform vec4 page_bg_color: source_color = vec4(0.95, 0.88, 0.75, 1.0);

void fragment() {
	// UV coordinates: (0,0) top-left, (1,1) bottom-right
	vec2 uv = UV;
	
	// The curl starts from the right edge when direction > 0 (turning page forward)
	// or from the left edge when direction < 0 (turning page backward)
	float edge_x = 0.0;
	if (curl_direction > 0.0) {
		// Curl from right edge, moving left
		edge_x = 1.0 - curl_amount;
	} else {
		// Curl from left edge, moving right
		edge_x = curl_amount;
	}
	
	// Determine if current pixel is in the curled region
	bool is_curled = false;
	if (curl_direction > 0.0) {
		is_curled = uv.x > edge_x;
	} else {
		is_curled = uv.x < edge_x;
	}
	
	if (is_curled) {
		// In the curled area, show the page back with shadow
		// Calculate how "curled" this pixel is for shading
		float curl_dist = 0.0;
		if (curl_direction > 0.0) {
			curl_dist = (uv.x - edge_x) / (1.0 - edge_x);
		} else {
			curl_dist = (edge_x - uv.x) / edge_x;
		}
		
		// Add shadow falloff - darker near the curl edge
		float shadow_strength = pow(curl_dist, 1.5) * 0.6;
		
		// Show the back of the page with shadow
		vec4 page_color = page_bg_color;
		vec4 result = mix(page_color, shadow_color, shadow_strength);
		COLOR = result;
		
		// Fade alpha at the very edge of curl
		float edge_fade = 1.0 - smoothstep(0.0, 0.05, curl_dist);
		result.a = mix(result.a, 0.0, edge_fade);
		COLOR = result;
	} else {
		// Not curled - show the normal page content with a slight shadow 
		// gradient near the curl edge for depth
		float dist_to_curl = 0.0;
		if (curl_direction > 0.0) {
			dist_to_curl = edge_x - uv.x;
		} else {
			dist_to_curl = uv.x - edge_x;
		}
		
		// Subtle shadow gradient near the curl line
		float edge_shadow = smoothstep(0.0, 0.1, dist_to_curl);
		edge_shadow = 1.0 - edge_shadow;
		
		vec4 tex_color = texture(TEXTURE, uv);
		float shadow_factor = 1.0 - edge_shadow * 0.15;
		COLOR = tex_color * shadow_factor;
	}
}
