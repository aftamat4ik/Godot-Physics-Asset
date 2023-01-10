extends EditorProperty

var button:Button

# called directly from UiInspectorPlugin.gd
func _init():
	button = Button.new()
	var prop_val = get_property_value()
	
	button.toggle_mode = true
	add_child(button)
	
	# To remember focus when selected back:
	add_focusable(button)
	button.connect("pressed", self, "_button_pressed")

# button text set
func set_button_text(text:String):
	button.text = text

# casted property value
func get_property_value()->bool:
	if get_edited_property() == null or get_edited_object() == null:
		return false
	var prop_val = get_edited_object()[get_edited_property()]
	# we work only with booleans
	if not prop_val is bool:
		return false
	# cast to type
	return prop_val as bool
	

# to access button directly in case we need some overrides in it's style
func get_button()->Button:
	return button

func _button_pressed():
	var prop_val = get_property_value()
	
	# set value to true
	emit_changed(get_edited_property(), true)

# triggered by engine when property is changed
func update_property():
	if button != null:
		var prop_val = get_property_value()
		button.pressed = prop_val
