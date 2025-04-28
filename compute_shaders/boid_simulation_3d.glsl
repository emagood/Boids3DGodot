#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec4 data[];
} boid_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity{
    vec4 data[];
} boid_vel;

layout(set = 0, binding = 2, std430) restrict buffer Params{
    float num_boids;
    float image_size;
    float friend_radius;
    float avoid_radius;
    float min_vel;
    float max_vel;
    float alignment_factor;
    float cohesion_factor;
    float separation_factor;
    float world_size_x;
    float world_size_y;
    float delta_time;
} params;

layout(rgba16f, binding = 3) uniform image2D boid_data;

layout(rgba16f, binding = 4) uniform image2D boid_quat;

void main() {
    int my_index = int(gl_GlobalInvocationID.x);

    if (my_index >= int(params.num_boids)) { return; }

    vec3 my_pos = boid_pos.data[my_index].xyz;
    vec3 my_vel = boid_vel.data[my_index].xyz;
    vec3 my_vel_prev = my_vel;
    vec3 avg_vel = vec3(0,0,0);
    vec3 midpoint = vec3(0,0,0);
    vec3 seperation_vec = vec3(0,0,0);
    int avoids = 0;
    int friends = 0;

    for (int i = 0; i < int(params.num_boids); i++){
        if (i != my_index) {
            vec3 other_pos = boid_pos.data[i].xyz;
            vec3 other_vel = boid_vel.data[i].xyz;
            float dist = distance(my_pos, other_pos);
            
            if (dist < params.friend_radius) {
                avg_vel += other_vel;
                midpoint += other_pos;
                friends++;
                if (dist < params.avoid_radius) {
                    seperation_vec += my_pos - other_pos;
                    avoids++;
                }
            }
        }
    }

    if (friends > 0) {
        avg_vel /= float(friends);
        my_vel += normalize(avg_vel) * params.alignment_factor;

        midpoint /= float(friends);
        my_vel += normalize(midpoint - my_pos) * params.cohesion_factor;

        if (avoids > 0) {
            seperation_vec /= float(avoids);
            my_vel += normalize(seperation_vec) * params.separation_factor;
        }
    }

    float vel_mag = length(my_vel);
    vel_mag = clamp(vel_mag, params.min_vel, params.max_vel);
    my_vel = normalize(my_vel) * vel_mag;

    my_pos += my_vel * params.delta_time;
    my_pos = vec3(
        mod(my_pos.x, params.world_size_x),
        mod(my_pos.y, params.world_size_y),
        mod(my_pos.z, params.world_size_x)
    );

    boid_vel.data[my_index] = vec4(my_vel, 0.0);
    boid_pos.data[my_index] = vec4(my_pos, 0.0);

    ivec2 pixel_pos = ivec2(
        int(mod(my_index, params.image_size)),
        int(my_index / params.image_size)
    );

    vec3 prev_lerp = imageLoad(boid_quat, pixel_pos).xyz;
    prev_lerp = prev_lerp + (my_vel - prev_lerp) * 3. * params.delta_time;

    imageStore(boid_data, pixel_pos, vec4(my_pos.x, my_pos.y, my_pos.z, 1));
    imageStore(boid_quat, pixel_pos, vec4(prev_lerp.x, prev_lerp.y, prev_lerp.z, 1));
}