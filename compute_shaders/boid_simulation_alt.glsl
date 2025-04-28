#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} boid_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity{
    vec2 data[];
} boid_vel;

layout(set = 0, binding = 2, std430) restrict buffer Params{
    float num_boids;
    float image_size;
    float friend_radius;
    float avoid_radius;
    float min_vel;
    float max_vel;
    float max_steer_force;
    float alignment_factor;
    float cohesion_factor;
    float separation_factor;
    float viewport_x;
    float viewport_y;
    float delta_time;
} params;

layout(rgba16f, binding = 3) uniform image2D boid_data;

vec2 steer_towards(vec2 target, vec2 heading) {
    float tlen = length(target);
    if (tlen < 1e-5)       // no meaningful target → no steer
        return vec2(0.0);

    vec2 desired = (target / tlen) * params.max_vel;
    vec2 v = desired - heading;
    float mag = length(v);
    // clamp the steering magnitude:
    v = (mag > 1e-5)
        ? normalize(v) * min(mag, params.max_steer_force)
        : vec2(0.0);
    return v;
}


void main() {
    int my_index = int(gl_GlobalInvocationID.x);
    if (my_index >= int(params.num_boids)) { return; }

    vec2 my_pos = boid_pos.data[my_index];
    vec2 my_vel = boid_vel.data[my_index];
    vec2 flock_heading = vec2(0,0);
    vec2 flock_center = vec2(0,0);
    vec2 seperation_vec = vec2(0,0);
    int flockmates = 0;

    for (int i = 0; i < int(params.num_boids); i++){
        if (i != my_index) {
            vec2 other_pos = boid_pos.data[i];
            vec2 other_vel = boid_vel.data[i];
            vec2 offset = other_pos - my_pos;
            float sq_dist = offset.x * offset.x + offset.y * offset.y;

            if (sq_dist < params.friend_radius * params.friend_radius) {
                flock_heading += normalize(other_vel);
                flock_center += other_pos;
                flockmates++;

                if (sq_dist < params.avoid_radius * params.avoid_radius) {
                    seperation_vec -= offset / max(sq_dist, 0.001);
                }
            }
        }
    }

    vec2 acceleration = vec2(0.0);

    if (flockmates > 0) {
        flock_center /= float(flockmates);
        vec2 flock_offset = flock_center - my_pos;

        acceleration += steer_towards(flock_heading, my_vel) * params.alignment_factor;
        acceleration += steer_towards(flock_offset, my_vel) * params.cohesion_factor;
        acceleration += steer_towards(seperation_vec, my_vel) * params.separation_factor;
    }

    my_vel += acceleration * params.delta_time;
    float speed = length(my_vel);
    vec2 dir = normalize(my_vel);
    speed = clamp(speed, params.min_vel, params.max_vel);
    my_vel = dir * speed;
    my_pos += my_vel * params.delta_time;

    my_pos = vec2(
        mod(my_pos.x, params.viewport_x),
        mod(my_pos.y, params.viewport_y)
    );

    boid_vel.data[my_index] = my_vel;
    boid_pos.data[my_index] = my_pos;

    ivec2 pixel_pos = ivec2(
        int(mod(my_index, params.image_size)),
        int(my_index / params.image_size)
    );

    float my_rot = 0.0;
    my_rot = acos(dot(normalize(my_vel), vec2(1,0)));
    if (isnan(my_rot)) {
        my_rot = 0.0;
    } else if (my_vel.y < 0.0) {
        my_rot = -my_rot;
    }

    float prev_rot = imageLoad(boid_data, pixel_pos).z;
    prev_rot = prev_rot + (my_rot - prev_rot) * 30. * params.delta_time;

    imageStore(boid_data, pixel_pos, vec4(my_pos.x, my_pos.y, prev_rot, 1));
}