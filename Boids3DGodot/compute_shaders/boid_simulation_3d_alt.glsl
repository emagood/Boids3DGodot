#[compute]
#version 450

// Boids Algorithm heavily inspired by Sebastian Lague's Boids project https://github.com/SebLague/Boids/
// and the rest of the code is a reworked (to 3d) version of David Schoemehl's Boids project:
// https://gitlab.com/niceeffort/boids_compute_example | https://www.youtube.com/watch?v=v-xNj4ud0aM

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position { vec4 data[]; } boid_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity { vec4 data[]; } boid_vel;

layout(set = 0, binding = 2, std430) restrict buffer Params{
    float num_boids; float image_size; float world_size_x; float world_size_y; float world_size_z;
    float friend_radius; float avoid_radius; float min_vel; float max_vel;
    float steer_factor; float alignment_factor; float cohesion_factor; float separation_factor;
    float flow_factor; float mouse_factor; float avoidance_factor;
    float time_scale; float delta_time; } params;

layout(rgba32f, binding = 3) uniform image2D boid_data;

layout(rgba32f, binding = 4) uniform image2D boid_quat;


vec3 steer_towards(vec3 target, vec3 heading) {
    float tlen = length(target);
    if (tlen < 1e-5) return vec3(0.0);

    vec3 desired = (target / tlen) * params.max_vel;
    vec3 v = desired - heading;
    float mag = length(v);

    v = (mag > 1e-5)
        ? normalize(v) * min(mag, params.steer_factor)
        : vec3(0.0);
    return v;
}

vec3 sampleFlowField(vec3 p) {
    vec3 rel = p;
    float r = length(rel);
    vec3 tangent = normalize(vec3(-rel.z, 0.0, rel.x));

    float R = min(params.world_size_x, 
                  params.world_size_z) * 0.4;
    float k = smoothstep(R, max(R, 1e-3), r);
    vec3 inward = normalize(-rel) * k;
    return normalize(tangent * 1.0 + inward * 2.0);
}

void main() {
    int my_index = int(gl_GlobalInvocationID.x);

    if (my_index >= int(params.num_boids)) { return; }

    vec3 my_pos = boid_pos.data[my_index].xyz;
    vec3 my_vel = boid_vel.data[my_index].xyz;
    vec3 flock_heading = vec3(0,0,0);
    vec3 flock_center = vec3(0,0,0);
    vec3 seperation_vec = vec3(0,0,0);
    int flockmates = 0;

    for (int i = 0; i < int(params.num_boids); i++){
        if (i != my_index) {
            vec3 other_pos = boid_pos.data[i].xyz;
            vec3 other_vel = boid_vel.data[i].xyz;
            vec3 offset = other_pos - my_pos;
            float sq_dist = offset.x * offset.x + offset.y * offset.y + offset.z * offset.z;

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

    vec3 acceleration = vec3(0.0);

    if (flockmates > 0) {
        flock_center /= float(flockmates);
        vec3 flock_offset = flock_center - my_pos;

        acceleration += steer_towards(flock_heading, my_vel) * params.alignment_factor;
        acceleration += steer_towards(flock_offset, my_vel) * params.cohesion_factor;
        acceleration += steer_towards(seperation_vec, my_vel) * params.separation_factor;
    }

    vec3 flow = sampleFlowField(my_pos);
    acceleration += steer_towards(flow, my_vel) * params.flow_factor;

    if (params.avoidance_factor > 0.0) {
        vec3 halfSize = vec3(
            params.world_size_x / 2.0,
            params.world_size_y / 2.0,
            params.world_size_z / 2.0
        );
        
        vec3 minB = -halfSize + vec3(10.);
        vec3 maxB = halfSize - vec3(10.);

        vec3 clamped = clamp(my_pos, minB, maxB);
        vec3 edgePush = clamped - my_pos;
        acceleration += steer_towards(edgePush, my_vel) * params.avoidance_factor;
    }

    float dt = params.delta_time * params.time_scale;
    my_vel += acceleration * dt;
    float speed = length(my_vel);
    vec3 dir = normalize(my_vel);
    speed = clamp(speed, params.min_vel, params.max_vel);
    my_vel = dir * speed;
    my_pos += my_vel * dt;

    if (params.avoidance_factor <= 0.0) {
        vec3 half_size = vec3(
            params.world_size_x / 2.0,
            params.world_size_y / 2.0,
            params.world_size_z / 2.0
        );
        
        if (my_pos.x < -half_size.x) my_pos.x += params.world_size_x;
        if (my_pos.x > half_size.x) my_pos.x -= params.world_size_x;
        
        if (my_pos.y < -half_size.y) my_pos.y += params.world_size_y;
        if (my_pos.y > half_size.y) my_pos.y -= params.world_size_y;
        
        if (my_pos.z < -half_size.z) my_pos.z += params.world_size_z;
        if (my_pos.z > half_size.z) my_pos.z -= params.world_size_z;
    }

    boid_vel.data[my_index] = vec4(my_vel, 0.0);
    boid_pos.data[my_index] = vec4(my_pos, 0.0);

    ivec2 pixel_pos = ivec2(
        int(mod(my_index, params.image_size)),
        int(my_index / params.image_size)
    );

    vec3 prev_lerp = imageLoad(boid_quat, pixel_pos).xyz;
    prev_lerp = prev_lerp + (my_vel - prev_lerp) * 3. * dt;

    imageStore(boid_data, pixel_pos, vec4(my_pos.x, my_pos.y, my_pos.z, 1));
    imageStore(boid_quat, pixel_pos, vec4(prev_lerp.x, prev_lerp.y, prev_lerp.z, 1));
}