extends Node3D

const NUM_BOIDS := 10_000
const WORLD_SIZE := Vector3(30, 30, 30)
const SIMULATE_GPU := true

@export_category("Boid Settings")
@export var friend_radius:     float = 2.0
@export var avoid_radius:      float = 1.0
@export var min_vel:           float = 1.0
@export var max_vel:           float = 2.0
@export var steer_factor:      float = 1.0
@export var alignment_factor:  float = 1.5
@export var cohesion_factor:   float = 2.0
@export var separation_factor: float = 3.5

@onready var BoidParticle3D: GPUParticles3D = $BoidParticle3D
@onready var FlyingController: CharacterBody3D = %FlyingController

var IMAGE_SIZE = int(ceil(sqrt(NUM_BOIDS)))
var boid_pos      : Array[Vector3] = []
var boid_vel      : Array[Vector3] = []
var boid_lerp_vel : Array[Vector3] = []

var boid_data : Image
var boid_quat : Image
var boid_data_texture : ImageTexture
var boid_quat_texture : ImageTexture

var compute3d : BoidCompute3D

func _ready() -> void:
	randomize()
	_generate_boids_3d()
	
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_quat = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_data_texture = ImageTexture.create_from_image(boid_data)
	boid_quat_texture = ImageTexture.create_from_image(boid_quat)
	
	BoidParticle3D.amount = NUM_BOIDS
	BoidParticle3D.process_material.set_shader_parameter("boid_data", boid_data_texture)
	BoidParticle3D.process_material.set_shader_parameter("boid_quat", boid_quat_texture)
	BoidParticle3D.custom_aabb = AABB(Vector3.ZERO, WORLD_SIZE)
	
	if SIMULATE_GPU:
		compute3d = BoidCompute3D.new(NUM_BOIDS, IMAGE_SIZE, WORLD_SIZE)
		compute3d.setup("res://compute_shaders/boid_simulation_3d_alt_alt.glsl", boid_pos, boid_vel, boid_data.get_data(), boid_quat.get_data())
		compute3d.update([
			friend_radius, avoid_radius, min_vel, max_vel,
			steer_factor, alignment_factor, cohesion_factor, separation_factor, 0.0
		])


func _process(delta: float) -> void:
	if SIMULATE_GPU:
		compute3d.sync()
		compute3d.update([
			friend_radius, avoid_radius, min_vel, max_vel,
			steer_factor, alignment_factor, cohesion_factor, separation_factor, delta
		])
		
		boid_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, compute3d.read_back_data())
		boid_quat.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, compute3d.read_back_quat())
		boid_data_texture.update(boid_data)
		boid_quat_texture.update(boid_quat)
	else:
		_update_boids_cpu_3d(delta)


func _generate_boids_3d() -> void:
	for i in NUM_BOIDS:
		boid_pos.append(Vector3(
			randf() * WORLD_SIZE.x,
			randf() * WORLD_SIZE.y,
			randf() * WORLD_SIZE.z))
		boid_vel.append(Vector3(
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel))
		boid_lerp_vel.append(boid_vel[i])


#func _generate_grid_positions_3d() -> void:
	#var boids = []
	#var grid_size = ceil(pow(NUM_BOIDS, 1.0 / 3.0))
	#var spacing = Vector3(
		#WORLD_SIZE.x / grid_size,
		#WORLD_SIZE.y / grid_size,
		#WORLD_SIZE.z / grid_size
	#)
	#
	#var count = 0
	#for x in range(grid_size):
		#for y in range(grid_size):
			#for z in range(grid_size):
				#if count >= NUM_BOIDS: break
				#var pos = Vector3(
					#(x + 0.5) * spacing.x,
					#(y + 0.5) * spacing.y,
					#(z + 0.5) * spacing.z
				#)
				#var vel = Vector3(
					#randf_range(-1.0, 1.0) * max_vel,
					#randf_range(-1.0, 1.0) * max_vel,
					#randf_range(-1.0, 1.0) * max_vel
					##(min_vel + max_vel) / 2, 0.0, 0.0
				#)
				#
				#boid_pos.append(pos)
				#boid_vel.append(vel)
				#boid_lerp_vel.append(vel)
				#
				#count += 1
			#if count >= NUM_BOIDS: break
		#if count >= NUM_BOIDS: break


func _update_boids_cpu_3d(delta):
	for i in NUM_BOIDS:
		var my_pos = boid_pos[i]
		var my_vel = boid_vel[i]
		var my_lerp = boid_lerp_vel[i]
		var avg_vel = Vector3.ZERO
		var midpoint = Vector3.ZERO
		var separation_vec = Vector3.ZERO
		var num_friends = 0
		var num_avoids = 0
		
		for j in NUM_BOIDS:
			if i != j:
				var other_pos = boid_pos[j]
				var other_vel = boid_vel[j]
				var dist = my_pos.distance_to(other_pos)
				if(dist < friend_radius):
					num_friends += 1
					avg_vel += other_vel
					midpoint += other_pos
					if(dist < avoid_radius):
						num_avoids += 1
						separation_vec += my_pos - other_pos
		
		if(num_friends > 0):
			avg_vel /= num_friends
			my_vel += avg_vel.normalized() * alignment_factor
			
			midpoint /= num_friends
			my_vel += (midpoint - my_pos).normalized() * cohesion_factor
			
			if(num_avoids > 0):
				my_vel += separation_vec.normalized() * separation_factor
		
		var vel_mag = my_vel.length()
		vel_mag = clamp(vel_mag, min_vel, max_vel)
		my_vel = my_vel.normalized() * vel_mag
		my_pos += my_vel * delta
		my_pos = Vector3(wrapf(my_pos.x, -WORLD_SIZE.x/2, WORLD_SIZE.x/2,),
						 wrapf(my_pos.y, -WORLD_SIZE.y/2, WORLD_SIZE.y/2,),
						 wrapf(my_pos.z, -WORLD_SIZE.z/2, WORLD_SIZE.z/2,))
		
		my_lerp = lerp(my_lerp, my_vel, 3. * delta)
		
		boid_pos[i] = my_pos
		boid_vel[i] = my_vel
		boid_lerp_vel[i] = my_lerp
	
	
	## UPDATE TEXTURE
	for i in NUM_BOIDS:
		var px = int(i % IMAGE_SIZE)
		var py = int(i / IMAGE_SIZE)
		var p = boid_pos[i]
		var v = boid_lerp_vel[i]
		boid_data.set_pixel(px, py, Color(p.x, p.y, p.z, 1.0))
		boid_quat.set_pixel(px, py, Color(v.x, v.y, v.z, 1.0))
	boid_data_texture.update(boid_data)
	boid_quat_texture.update(boid_quat)


func _exit_tree():
	if SIMULATE_GPU: compute3d.free_resources()
