extends Node3D

var NUM_BOIDS : int = 350
var WORLD_SIZE : Vector3 = Vector3(10, 10, 10)
var SIMULATE_GPU : bool = false
var IMAGE_SIZE : int

@export_category("Boid Settings")
@export var num_boids:         int   = 350
@export var world_radius:      int   = 10
@export var simulate_gpu:      bool  = false

@export var friend_radius:     float = 1.5
@export var avoid_radius:      float = 1.0
@export var min_vel:           float = 1.0
@export var max_vel:           float = 2.0
@export var steer_factor:      float = 1.0
@export var alignment_factor:  float = 1.5
@export var cohesion_factor:   float = 2.5
@export var separation_factor: float = 3.2
@export var flow_factor:       float = 0.1
@export var mouse_factor:      float = 1.0
@export var avoidance_factor:  float = 0.3
@export var time_scale:        float = 1.0

@onready var BoidParticle3D: GPUParticles3D = $BoidParticle3D
@onready var FlyingController: CharacterBody3D = %FlyingController
@onready var BoundaryBox: MeshInstance3D = $BoundaryBox
@onready var BoidEnvironment: WorldEnvironment = $BoidEnvironment

const NeonTetra = preload("res://boid_resources/fishNeonTeT.obj")
const CopperbandButterflyfish = preload("res://boid_resources/newFish.obj")
const ConeBoid = preload("res://boid_resources/ConeBoid.obj")
const WaterEnvironment = preload("res://boid_resources/WaterEnvironment.tres")

var boid_pos  : Array[Vector3] = []
var boid_vel  : Array[Vector3] = []
var boid_lvel : Array[Vector3] = []

var boid_data : Image
var boid_velo : Image
var boid_data_texture : ImageTexture
var boid_velo_texture : ImageTexture

# GPU variables
var rd : RenderingDevice
var boid_compute_shader : RID
var pipeline : RID
var bindings : Array
var uniform_set : RID

var boid_pos_buffer : RID
var boid_vel_buffer : RID
var params_buffer : RID
var params_uniform : RDUniform
var boid_data_buffer : RID
var boid_velo_buffer : RID


func _ready() -> void:
	rd = RenderingServer.create_local_rendering_device()
	BoidParticle3D.draw_pass_1 = ConeBoid
	BoidEnvironment.environment = null
	FlyingController.position = Vector3(0,0,-(WORLD_SIZE.z/2+15))
	
	randomize()
	_init_simulation()


var sim1_params = [350,    Vector3(10,10,10), false]
var sim2_params = [350,    Vector3(10,10,10), true]
var sim3_params = [10_000, Vector3(30,30,30), true]


func _unhandled_input(event: InputEvent) -> void:
	if   event.is_action_pressed("sim1"):
		BoidParticle3D.draw_pass_1 = ConeBoid
		BoidEnvironment.environment = null
		restart_simulation(sim1_params)
	elif event.is_action_pressed("sim2"):
		BoidParticle3D.draw_pass_1 = NeonTetra
		BoidEnvironment.environment = WaterEnvironment
		restart_simulation(sim2_params)
	elif event.is_action_pressed("sim3"):
		BoidParticle3D.draw_pass_1 = CopperbandButterflyfish
		BoidEnvironment.environment = WaterEnvironment
		restart_simulation(sim3_params)


func _init_simulation() -> void:
	IMAGE_SIZE = int(ceil(sqrt(NUM_BOIDS)))
	boid_pos.clear()
	boid_vel.clear()
	boid_lvel.clear()
	
	_generate_boids_3d()
	
	boid_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_velo = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_data_texture = ImageTexture.create_from_image(boid_data)
	boid_velo_texture = ImageTexture.create_from_image(boid_velo)
	
	BoidParticle3D.amount = NUM_BOIDS
	BoidParticle3D.process_material.set_shader_parameter("boid_data", boid_data_texture)
	BoidParticle3D.process_material.set_shader_parameter("boid_velo", boid_velo_texture)
	BoidParticle3D.custom_aabb = AABB(-WORLD_SIZE/2, WORLD_SIZE)
	BoidParticle3D.visibility_aabb = BoidParticle3D.custom_aabb
	
	BoundaryBox.mesh.size = WORLD_SIZE
	
	if SIMULATE_GPU:
		_setup_compute_shader()
		BoundaryBox.hide()
	else:
		BoundaryBox.show()


func restart_simulation(params) -> void:
	NUM_BOIDS    = params[0]
	WORLD_SIZE   = params[1]
	SIMULATE_GPU = params[2]
	_init_simulation()


func _generate_boids_3d() -> void:
	for i in NUM_BOIDS:
		boid_pos.append(Vector3(
			randf() * WORLD_SIZE.x - WORLD_SIZE.x/2,
			randf() * WORLD_SIZE.y - WORLD_SIZE.y/2,
			randf() * WORLD_SIZE.z - WORLD_SIZE.z/2))
		boid_vel.append(Vector3(
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel))
		boid_lvel.append(boid_vel[i])


func _update_data_texture():
	if SIMULATE_GPU:
		var boid_velo_image_data := rd.texture_get_data(boid_velo_buffer, 0)
		var boid_data_image_data := rd.texture_get_data(boid_data_buffer, 0)
		boid_data.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, boid_data_image_data)
		boid_velo.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, boid_velo_image_data)
		
	else:
		for i in NUM_BOIDS:
			var px = int(i % IMAGE_SIZE)
			var py = int(i / floor(IMAGE_SIZE))
			var p = boid_pos[i]
			var v = boid_lvel[i]
			boid_data.set_pixel(px, py, Color(p.x, p.y, p.z))
			boid_velo.set_pixel(px, py, Color(v.x, v.y, v.z))
	
	boid_data_texture.update(boid_data)
	boid_velo_texture.update(boid_velo)


func _update_boids_cpu_3d(delta):
	for i in NUM_BOIDS:
		var my_pos = boid_pos[i]
		var my_vel = boid_vel[i]
		var my_lerp = boid_lvel[i]
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
		boid_lvel[i] = my_lerp


func _generate_vec4_buffer(data: Array[Vector3]) -> RID:
	var flat = PackedFloat32Array()
	for v in data: flat.append_array([v.x, v.y, v.z, 0.0])
	var bytes = flat.to_byte_array()
	return rd.storage_buffer_create(bytes.size(), bytes)


func _generate_uniform(data_buffer, type, binding) -> RDUniform:
	var data_uniform := RDUniform.new()
	data_uniform.uniform_type = type
	data_uniform.binding = binding
	data_uniform.add_id(data_buffer)
	return data_uniform


func _generate_parameter_buffer(delta):
	var params_buffer_bytes : PackedByteArray = PackedFloat32Array(
		[NUM_BOIDS, IMAGE_SIZE, WORLD_SIZE.x, WORLD_SIZE.y, WORLD_SIZE.z,
		friend_radius, avoid_radius, min_vel, max_vel,
		steer_factor, alignment_factor, cohesion_factor, separation_factor,
		flow_factor, mouse_factor, avoidance_factor,
		time_scale, delta]).to_byte_array()
	
	return rd.storage_buffer_create(params_buffer_bytes.size(), params_buffer_bytes)


func _setup_compute_shader():
	var shader_file := load("res://compute_shaders/boid_simulation_3d_alt.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	boid_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(boid_compute_shader)
	
	boid_pos_buffer = _generate_vec4_buffer(boid_pos)
	var boid_pos_uniform = _generate_uniform(boid_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	boid_vel_buffer = _generate_vec4_buffer(boid_vel)
	var boid_vel_uniform = _generate_uniform(boid_vel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	params_buffer = _generate_parameter_buffer(0)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()
	
	boid_data_buffer = rd.texture_create(fmt, view, [boid_data.get_data()])
	var boid_data_buffer_uniform = _generate_uniform(boid_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	
	boid_velo_buffer = rd.texture_create(fmt, view, [boid_velo.get_data()])
	var boid_velo_buffer_uniform = _generate_uniform(boid_velo_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 4)
	
	bindings = [boid_pos_uniform, boid_vel_uniform, params_uniform, boid_data_buffer_uniform, boid_velo_buffer_uniform]
	
	uniform_set = rd.uniform_set_create(bindings, boid_compute_shader, 0)


func _update_boids_gpu(delta):
	var new_params_data = PackedFloat32Array(
		[NUM_BOIDS, IMAGE_SIZE, WORLD_SIZE.x, WORLD_SIZE.y, WORLD_SIZE.z,
		friend_radius, avoid_radius, min_vel, max_vel,
		steer_factor, alignment_factor, cohesion_factor, separation_factor,
		flow_factor, mouse_factor, avoidance_factor,
		time_scale, delta]).to_byte_array()
	
	rd.buffer_update(params_buffer, 0, new_params_data.size(), new_params_data)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceili(NUM_BOIDS/1024.), 1, 1)
	rd.compute_list_end()
	rd.submit()


func _sync_boids_gpu():
	rd.sync()


func _process(delta: float) -> void:
	if not SIMULATE_GPU:
		_update_boids_cpu_3d(delta)
	_update_data_texture()
	
	if SIMULATE_GPU:
		_update_boids_gpu(delta)
		_sync_boids_gpu()


func _free_gpu_resources():
	rd.free_rid(uniform_set)
	rd.free_rid(boid_data_buffer)
	rd.free_rid(boid_velo_buffer)
	rd.free_rid(params_buffer)
	rd.free_rid(boid_pos_buffer)
	rd.free_rid(boid_vel_buffer)
	rd.free_rid(pipeline)
	rd.free_rid(boid_compute_shader)


func _exit_tree():
	if SIMULATE_GPU:
		call_deferred("_free_gpu_resources")


func _on_num_boids_text_submitted(new_text: String) -> void:
	NUM_BOIDS = int(new_text)
	_init_simulation()

func _on_world_radius_value_changed(value: float) -> void:
	WORLD_SIZE = Vector3(value, value, value)
	_init_simulation()

func _on_simulate_gpu_toggled(toggled_on: bool) -> void:
	SIMULATE_GPU = toggled_on
	_init_simulation()
