extends HBoxContainer

func setup(slider_info, val):
	$property.text = slider_info[0]
	$value.min_value = slider_info[1]
	$value.max_value = slider_info[2]
	$value.step = ($value.max_value - $value.min_value) / 200.0
	
	$value.value_changed.connect(change_label)
	$value.value = val
	change_label(val)

func change_label(value):
	$value_label.text = str(value)
