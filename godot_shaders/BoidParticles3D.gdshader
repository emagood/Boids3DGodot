shader_type particles;

uniform sampler2D boid_data;
uniform sampler2D boid_quat;

uniform float scale = .5;

vec4 texel_color(sampler2D data, uint index) {
	ivec2 pos_image_size = textureSize(data, 0);
	ivec2 texel_pos = ivec2(int(mod(float(index), float(pos_image_size.x))),
							int(float(index) / float(pos_image_size.x)));
	vec4 data_color = texelFetch(data, texel_pos, 0);
	return data_color;
}

void process() {
	vec4 boid_pos_rot = texel_color(boid_data, INDEX);
	vec4 boid_vel_vec = texel_color(boid_quat, INDEX);
	float epsilon = 1e-5;
	
	vec3 v = boid_vel_vec.xyz;
	vec3 F = normalize(v);
	
	if (length(v) < epsilon) {
		TRANSFORM = mat4(1.0);
	} else {
		vec3 U0 = vec3(0.0, 1.0, 0.0);
		vec3 R = normalize(cross(U0, F));
		
		if (length(R) < epsilon) {
			U0 = vec3(1.0, 0.0, 0.0);
			R = normalize(cross(U0, F));
		}
		
		vec3 U = cross(F, R);
		
		mat4 scale_rot_mat = mat4(
			vec4(R * scale, 0.0),
			vec4(U * scale, 0.0),
			vec4(F * scale, 0.0),
			vec4(0.0, 0.0, 0.0, 1.0)
		);
		
		TRANSFORM[0].xyzw = scale_rot_mat[0];
		TRANSFORM[1].xyzw = scale_rot_mat[1];
		TRANSFORM[2].xyzw = scale_rot_mat[2];
		TRANSFORM[3].xyz = vec3(boid_pos_rot.x, boid_pos_rot.y, boid_pos_rot.z);
	}
}
