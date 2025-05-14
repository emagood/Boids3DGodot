extends Node
class_name BoidCompute3D

var NUM_BOIDS: int
var IMAGE_SIZE: int
var WORLD_SIZE: Vector3

var rd: RenderingDevice
var boid_compute_shader : RID
var pipeline: RID
var bindings: Array
var uniform_set: RID

var boid_pos_buffer: RID
var boid_vel_buffer: RID
var params_buffer: RID
var params_uniform : RDUniform
var boid_data_buffer: RID
var boid_quat_buffer: RID


func _init(num_boids:int, image_size:int, world_size:Vector3) -> void:
	NUM_BOIDS  = num_boids
	IMAGE_SIZE = image_size
	WORLD_SIZE = world_size


func setup(shader_path:String, pos:Array, vel:Array, data_img:PackedByteArray, quat_img:PackedByteArray) -> void:
	rd = RenderingServer.create_local_rendering_device()
	
	var shader_file := load(shader_path)
	var shader_spirv : RDShaderSPIRV = shader_file.get_spirv()
	boid_compute_shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(boid_compute_shader)
	
	boid_pos_buffer = _generate_vec4_buffer(pos)
	var boid_pos_uniform = _generate_uniform(boid_pos_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	boid_vel_buffer = _generate_vec4_buffer(vel)
	var boid_vel_uniform = _generate_uniform(boid_vel_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	var params_array = [NUM_BOIDS, IMAGE_SIZE, WORLD_SIZE.x, WORLD_SIZE.y, WORLD_SIZE.z] + [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	params_buffer = _generate_param_buffer(params_array)
	params_uniform = _generate_uniform(params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	var fmt := RDTextureFormat.new()
	fmt.width = IMAGE_SIZE
	fmt.height = IMAGE_SIZE
	fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var view := RDTextureView.new()
	
	boid_data_buffer = rd.texture_create(fmt, view, [data_img])
	var boid_data_buffer_uniform = _generate_uniform(boid_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 3)

	boid_quat_buffer = rd.texture_create(fmt, view, [quat_img])
	var boid_quat_buffer_uniform = _generate_uniform(boid_quat_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 4)

	bindings = [boid_pos_uniform, boid_vel_uniform, params_uniform, boid_data_buffer_uniform, boid_quat_buffer_uniform]
	
	uniform_set = rd.uniform_set_create(bindings, boid_compute_shader, 0)


func update(params:Array) -> void:
	var arr = [NUM_BOIDS, IMAGE_SIZE, WORLD_SIZE.x, WORLD_SIZE.y, WORLD_SIZE.z] + params
	print(arr)
	var params_byte_array = PackedFloat32Array(arr).to_byte_array()
	rd.buffer_update(params_buffer, 0, params_byte_array.size(), params_byte_array)
	
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, ceili(NUM_BOIDS/1024.), 1, 1)
	rd.compute_list_end()
	rd.submit()


func sync() -> void: rd.sync()
func read_back_data() -> PackedByteArray: return rd.texture_get_data(boid_data_buffer, 0)
func read_back_quat() -> PackedByteArray: return rd.texture_get_data(boid_quat_buffer, 0)

func free_resources() -> void:
	rd.free_rid(uniform_set)
	rd.free_rid(boid_data_buffer)
	rd.free_rid(boid_quat_buffer)
	rd.free_rid(params_buffer)
	rd.free_rid(boid_pos_buffer)
	rd.free_rid(boid_vel_buffer)
	rd.free_rid(pipeline)
	rd.free()

## HELPERS ##

func _generate_vec4_buffer(data:Array) -> RID:
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

func _generate_param_buffer(arr:Array) -> RID:
	var b : PackedByteArray = PackedFloat32Array(arr).to_byte_array()
	return rd.storage_buffer_create(b.size(), b)
