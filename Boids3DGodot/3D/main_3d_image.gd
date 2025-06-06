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
@export var avoidance_factor:  float = 2.0
@export var time_scale:        float = 1.0

@onready var BoidParticle3D: GPUParticles3D = $BoidParticle3D
@onready var FlyingController: CharacterBody3D = %FlyingController
@onready var BoundaryBox: MeshInstance3D = $BoundaryBox
@onready var BoidEnvironment: WorldEnvironment = $BoidEnvironment

@onready var main: CSGBox3D = $Main
@onready var sub_1: CSGBox3D = $Main/Sub1
@onready var sub_2: CSGBox3D = $Main/Sub2
@onready var sub_3: CSGBox3D = $Main/Sub3

const NeonTetra = preload("res://boid_resources/NeonTetra.obj")
const CopperbandButterflyfish = preload("res://boid_resources/CopperbandButterflyfish.obj")
const ConeBoid = preload("res://boid_resources/ConeBoid.obj")
const WaterEnvironment = preload("res://boid_resources/WaterEnvironment.tres")

var boid_pos : Image
var boid_vel : Image
var boid_lerp : Image
var boid_pos_texture : ImageTexture
var boid_vel_texture : ImageTexture
var boid_lerp_texture : ImageTexture

var rd : RenderingDevice
var boid_compute_shader : RID
var pipeline : RID
var bindings : Array
var uniform_set : RID
var params_buffer : RID
var params_uniform : RDUniform
var boid_pos_buffer : RID
var boid_vel_buffer : RID
var boid_lerp_buffer : RID

func _ready() -> void:
	rd = RenderingServer.create_local_rendering_device()
	BoidParticle3D.draw_pass_1 = ConeBoid
	BoidEnvironment.environment = null
	FlyingController.position = Vector3(0,0,-(WORLD_SIZE.z/2+15))
	
	randomize()
	_init_simulation()

var sim1_params = [350,   Vector3(10,10,10), false]
var sim2_params = [1_000, Vector3(10,10,10), true]
var sim3_params = [10_000,Vector3(30,30,30), true]

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

var boid_p : Array[Vector3] = []
var boid_v : Array[Vector3] = []
var boid_l : Array[Vector3] = []

func _generate_boids_3d_arrays() -> void:
	for i in NUM_BOIDS:
		boid_p.append(Vector3(
			randf() * WORLD_SIZE.x,
			randf() * WORLD_SIZE.y,
			randf() * WORLD_SIZE.z))
		boid_v.append(Vector3(
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel))
		boid_l.append(boid_v[i])

func _update_boids_cpu_3d(delta):
	for i in NUM_BOIDS:
		var my_pos = boid_p[i]
		var my_vel = boid_v[i]
		var my_lerp = boid_l[i]
		var avg_vel = Vector3.ZERO
		var midpoint = Vector3.ZERO
		var separation_vec = Vector3.ZERO
		var num_friends = 0
		var num_avoids = 0
		
		for j in NUM_BOIDS:
			if i != j:
				var other_pos = boid_p[j]
				var other_vel = boid_v[j]
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
		
		boid_p[i] = my_pos
		boid_v[i] = my_vel
		boid_l[i] = my_lerp
	
	
	## UPDATE TEXTURE
	for i in NUM_BOIDS:
		var px = int(i % IMAGE_SIZE)
		var py = int(i / IMAGE_SIZE)
		var p = boid_p[i]
		var v = boid_v[i]
		var l = boid_l[i]
		boid_pos.set_pixel(px, py, Color(p.x, p.y, p.z, 1.0))
		boid_vel.set_pixel(px, py, Color(v.x, v.y, v.z, 1.0))
		boid_lerp.set_pixel(px, py, Color(l.x, l.y, l.z, 1.0))
	boid_pos_texture.update(boid_pos)
	boid_vel_texture.update(boid_vel)
	boid_lerp_texture.update(boid_lerp)


func _init_simulation() -> void:
	IMAGE_SIZE = int(ceil(sqrt(NUM_BOIDS)))
	
	boid_pos = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_vel = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_lerp = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	boid_pos_texture = ImageTexture.create_from_image(boid_pos)
	boid_vel_texture = ImageTexture.create_from_image(boid_vel)
	boid_lerp_texture = ImageTexture.create_from_image(boid_lerp)
	
	_generate_boids_3d()
	_generate_boids_3d_arrays()
	
	BoidParticle3D.amount = NUM_BOIDS
	BoidParticle3D.process_material.set_shader_parameter("boid_pos", boid_pos_texture)
	BoidParticle3D.process_material.set_shader_parameter("boid_lerp", boid_lerp_texture)
	BoidParticle3D.custom_aabb = AABB(-WORLD_SIZE/2, WORLD_SIZE)
	BoidParticle3D.visibility_aabb = BoidParticle3D.custom_aabb
	
	BoundaryBox.mesh.size = WORLD_SIZE
	
	main.size = WORLD_SIZE
	sub_1.size = main.size * Vector3(0.98, 0.98, 1.01)
	sub_2.size = sub_1.size
	sub_3.size = sub_1.size
	
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
		var px = int(i % IMAGE_SIZE)
		var py = int(i / floor(IMAGE_SIZE))
		
		boid_pos.set_pixel(px, py, Color(
			randf() * WORLD_SIZE.x - WORLD_SIZE.x/2,
			randf() * WORLD_SIZE.x - WORLD_SIZE.x/2,
			randf() * WORLD_SIZE.x - WORLD_SIZE.x/2))
		boid_vel.set_pixel(px, py, Color(
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel,
			randf_range(-1.0, 1.0) * max_vel))
	boid_lerp = boid_vel.duplicate()

func _update_data_texture():
	if SIMULATE_GPU:
		var boid_pos_image_data := rd.texture_get_data(boid_pos_buffer, 0)
		var boid_vel_image_data := rd.texture_get_data(boid_vel_buffer, 0)
		var boid_lerp_image_data := rd.texture_get_data(boid_lerp_buffer, 0)
		boid_pos.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, boid_pos_image_data)
		boid_vel.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, boid_vel_image_data)
		boid_lerp.set_data(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF, boid_lerp_image_data)
	
	boid_pos_texture.update(boid_pos)
	boid_vel_texture.update(boid_vel)
	boid_lerp_texture.update(boid_lerp)


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
	var shader_file := load("res://compute_shaders/boid_simulation_3d_image_alt.glsl")
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	boid_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(boid_compute_shader)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()
	
	boid_pos_buffer = rd.texture_create(fmt, view, [boid_pos.get_data()])
	var boid_pos_buffer_uniform = _generate_uniform(boid_pos_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 1)
	
	boid_vel_buffer = rd.texture_create(fmt, view, [boid_vel.get_data()])
	var boid_vel_buffer_uniform = _generate_uniform(boid_vel_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 2)
	
	boid_lerp_buffer = rd.texture_create(fmt, view, [boid_lerp.get_data()])
	var boid_lerp_buffer_uniform = _generate_uniform(boid_lerp_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)
	
	params_buffer = _generate_parameter_buffer(0)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	
	bindings = [boid_pos_buffer_uniform, boid_vel_buffer_uniform, boid_lerp_buffer_uniform, params_uniform]
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
	_update_data_texture()
	
	if SIMULATE_GPU:
		_update_boids_gpu(delta)
		_sync_boids_gpu()
	else:
		_update_boids_cpu_3d(delta)
	
	main.visible = !General.is_viewing


func _free_gpu_resources():
	rd.free_rid(uniform_set)
	rd.free_rid(boid_pos_buffer)
	rd.free_rid(boid_vel_buffer)
	rd.free_rid(boid_lerp_buffer)
	rd.free_rid(params_buffer)
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
	BoidParticle3D.custom_aabb = AABB(-WORLD_SIZE/2, WORLD_SIZE)
	
	main.size = WORLD_SIZE
	sub_1.size = main.size * Vector3(0.98, 0.98, 1.01)
	sub_2.size = sub_1.size
	sub_3.size = sub_1.size

func _on_simulate_gpu_toggled(toggled_on: bool) -> void:
	SIMULATE_GPU = toggled_on
	_init_simulation()
