#[compute]
#version 450

// Boids Algorithm heavily inspired by Sebastian Lague's Boids project https://github.com/SebLague/Boids/
// and the rest of the code is a reworked (to 3d) version of David Schoemehl's Boids project:
// https://gitlab.com/niceeffort/boids_compute_example | https://www.youtube.com/watch?v=v-xNj4ud0aM

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(rgba32f, binding = 1) uniform image2D boid_pos;

layout(rgba32f, binding = 2) uniform image2D boid_vel;

layout(rgba32f, binding = 3) uniform image2D boid_lerp;

layout(set = 0, binding = 4, std430) restrict buffer Params{
    float num_boids; float image_size; float world_size_x; float world_size_y; float world_size_z;
    float friend_radius; float avoid_radius; float min_vel; float max_vel;
    float steer_factor; float alignment_factor; float cohesion_factor; float separation_factor;
    float flow_factor; float mouse_factor; float avoidance_factor;
    float time_scale; float delta_time; } params;

vec3 steerTowards(vec3 target, vec3 heading) {
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

vec3 boundaryAvoidance(vec3 pos, vec3 vel) {
    vec3 halfSize = vec3(
        params.world_size_x * 0.5,
        params.world_size_y * 0.5,
        params.world_size_z * 0.5
    );

    vec3 distPosFace = halfSize - pos;
    vec3 distNegFace = halfSize + pos;

    vec3 push = vec3(0.0);
    if (distPosFace.x < 0.0) push.x += distPosFace.x;
    if (distNegFace.x < 0.0) push.x -= distNegFace.x;
    if (distPosFace.y < 0.0) push.y += distPosFace.y;
    if (distNegFace.y < 0.0) push.y -= distNegFace.y;
    if (distPosFace.z < 0.0) push.z += distPosFace.z;
    if (distNegFace.z < 0.0) push.z -= distNegFace.z;

    if (length(push) < 1e-6) {
        return vel;
    } else {
        return steerTowards(push, vel);
    }
}

void main() {
    int my_index = int(gl_GlobalInvocationID.x);
    if (my_index >= int(params.num_boids)) { return; }

    ivec2 my_texel = ivec2(
        int(mod(my_index, params.image_size)),
        int(my_index / params.image_size)
    );

    vec4 bpos = imageLoad(boid_pos, my_texel);
    vec4 bvel = imageLoad(boid_vel, my_texel);
    vec4 blerp = imageLoad(boid_lerp, my_texel);

    vec3 my_pos = bpos.xyz;
    vec3 my_vel = bvel.xyz;
    vec3 flock_heading = vec3(0,0,0);
    vec3 flock_center = vec3(0,0,0);
    vec3 seperation_vec = vec3(0,0,0);
    int flockmates = 0;

    for (int other_index = 0; other_index < int(params.num_boids); other_index++){
        if (other_index != my_index) {
            ivec2 other_texel = ivec2(
                int(mod(other_index, params.image_size)),
                int(other_index / params.image_size)
            );

            vec3 other_pos = imageLoad(boid_pos, other_texel).xyz;
            vec3 other_vel = imageLoad(boid_vel, other_texel).xyz;
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

        acceleration += steerTowards(flock_heading, my_vel) * params.alignment_factor;
        acceleration += steerTowards(flock_offset, my_vel) * params.cohesion_factor;
        acceleration += steerTowards(seperation_vec, my_vel) * params.separation_factor;
    }

    acceleration += steerTowards(sampleFlowField(my_pos), my_vel) * params.flow_factor;
    acceleration += boundaryAvoidance(my_pos, my_vel) * params.avoidance_factor;

    float dt = params.delta_time * params.time_scale;
    my_vel += acceleration * dt;
    float speed = length(my_vel);
    vec3 dir = normalize(my_vel);
    speed = clamp(speed, params.min_vel, params.max_vel);
    my_vel = dir * speed;
    my_pos += my_vel * dt;

    vec3 my_lerp = blerp.xyz;
    my_lerp = my_lerp + (my_vel - my_lerp) * 3. * dt;

    imageStore(boid_pos, my_texel, vec4(my_pos.x, my_pos.y, my_pos.z, 1));
    imageStore(boid_vel, my_texel, vec4(my_vel.x, my_vel.y, my_vel.z, 1));
    imageStore(boid_lerp, my_texel, vec4(my_lerp.x, my_lerp.y, my_lerp.z, 1));
}