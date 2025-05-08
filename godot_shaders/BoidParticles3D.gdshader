shader_type particles;

uniform sampler2D boid_data;
uniform sampler2D boid_velo;
uniform float scale = .5;
const float epsilon = 1e-5;

vec4 fetch_boid_data(sampler2D texture_data, uint particle_index) {
	ivec2 texture_dimensions = textureSize(texture_data, 0);
	ivec2 pixel_coordinates = ivec2(
		int(mod(float(particle_index), float(texture_dimensions.x))),
		int(float(particle_index) / float(texture_dimensions.x))
	);
	return texelFetch(texture_data, pixel_coordinates, 0);
}

void process() {
	vec3 position = fetch_boid_data(boid_data, INDEX).xyz;
	vec3 velocity = fetch_boid_data(boid_velo, INDEX).xyz;
	
	// Setting the Boid's direction as our Forward:
	vec3 forward_direction = normalize(velocity);
	
	// Default behavior in case velocity is too small:
	if (length(velocity) < epsilon) { TRANSFORM = mat4(1.0); }
	else {
		vec3 default_up_vector = vec3(0.0, 1.0, 0.0); // World UP vector
		vec3 right_direction = normalize(cross(default_up_vector, forward_direction));
		
		if (length(right_direction) < epsilon) {
			default_up_vector = vec3(1.0, 0.0, 0.0); // World RIGHT vector
			right_direction = normalize(cross(default_up_vector, forward_direction));
		}
		vec3 up_direction = cross(forward_direction, right_direction);
		
		mat4 orientation_matrix = mat4(
			vec4(right_direction   * scale, 0.0),
			vec4(up_direction      * scale, 0.0),
			vec4(forward_direction * scale, 0.0),
			vec4(position,                  1.0)
		);
		TRANSFORM = orientation_matrix;
	}
}
