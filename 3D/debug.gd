extends CanvasLayer

#@onready var debug_ui = %DebugUI
#@onready var debug_container = $DebugUI/DebugContainer
#
#const slider_part = preload("res://slider_menu_part.tscn")
#
#func add_debug(debug_list):
	##debug_list = {
		##"": func(): return "",
		##"saved_progress": func(): return player.saved_progress,
	##}
	##
	#for property in debug_list:
		#var sec = slider_part.instantiate()
		#sec.property = property
		#sec.func = debug_list[property]
		#
		#debug_container.add_child(sec)


#extends MarginContainer
#
#@export var property = "property"
#@export var state = "state"
#
#func _process(_delta):
	#$HSplitContainer/property.text = property
	#$HSplitContainer/state.text = str(state.call())
