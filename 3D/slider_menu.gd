extends PanelContainer

const slider_part = preload("res://3D/slider_menu_part.tscn")
@onready var main: Node = $"..".main
@onready var slider_menu_container: VBoxContainer = %SliderMenuContainer
@onready var slider_menu_part: HBoxContainer = $MarginContainer/SliderMenuContainer/SliderMenuPart

func _ready() -> void:
	slider_menu_part.queue_free()

func add_sliders(slider_list):
	for slider_info in slider_list:
		var part = slider_part.instantiate()
		var get_var = main.get(slider_info[0])
		if get_var != null:
			part.setup(slider_info, get_var)
		part.get_node("value").value_changed.connect(func(x): main.set(slider_info[0], x))
		slider_menu_container.add_child(part)
