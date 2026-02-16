shader_type spatial;
render_mode unshaded, cull_front, depth_draw_always;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0); // Default Yellow
uniform float outline_width : hint_range(0.0, 10.0) = 4.0;
uniform bool pulse = true;

void vertex() {
	// Calculate extrusion amount
	float width = outline_width * 0.01;
	
	if (pulse) {
		width *= 0.8 + 0.2 * sin(TIME * 5.0);
	}

	// Simple normal extrusion (breaks corners on sharp meshes)
	// VERTEX += NORMAL * width;
	
	// Position-based extrusion (scales from center) - fixes corners on convex shapes
	// This assumes the mesh is roughly centered at (0,0,0) locally.
	// For better results on complex meshes, a second pass with smooth normals is needed,
	// but scaling works great for simple primitives like boxes/spheres.
	VERTEX += normalize(VERTEX) * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
