tool
extends VBoxContainer

# select scene node dialog
onready var select_ui = preload("res://Addons/physics_assets/Ui/Controls/SelectSceneNodeDialog/SelectSceneNodeDialog.tscn").instance()

# Items will be here
var items:PoolStringArray

# Refrence to owner-plugin
var _plugin:EditorPlugin

# current page index
var current_page := 0
var reorder_from_index := -1
var reorder_to_index := -1
var reorder_mouse_y_delta := 0.0

var reorder_selected_element_hbox:HBoxContainer
var reorder_selected_button:Button

const page_length = 5

# signals
signal button_clicked()
signal updated(items)
signal reordered(items)

onready var sb_size:SpinBox = get_node("%SbSize")
onready var sb_page:SpinBox = get_node("%SbPage")
onready var vb_items_list:VBoxContainer = get_node("%VBItemsList")

func _ready():
	set_drag_forwarding(self)
	sb_page.connect("value_changed", self, "_page_changed")
	sb_size.connect("value_changed", self, "_length_changed")
	# initialisation check
	if _plugin == null:
		return
	# construct
	select_ui.init(_plugin)

	var root = _plugin.get_editor_interface().get_editor_viewport()
	# if not initialised yet or in case of queue_free is called
	if not root.is_a_parent_of(select_ui):
		# add dialog to scene
		root.add_child(select_ui)
		select_ui.set_owner(_plugin.get_editor_interface().get_edited_scene_root())
	
	update_items()

# Initialise
func init(plugin:EditorPlugin):
	self._plugin = plugin

# Setting items list
func set_items(new_items:PoolStringArray):
	items = new_items
	update_items()

# on length slider value changed
func _length_changed(value:float):
	items.resize(value)
	emit_signal("updated", items)

# on page slider value changed
func _page_changed(value:float):
	current_page = sb_page.value
	update_items()

# Items List Update
func update_items():
	# onready vars should be loaded first
	if not is_inside_tree():
		return
	
	var size := items.size()
	
	var pages := max(0, size - 1) / page_length + 1
	# check bounds
	current_page = current_page if current_page <= pages-1 and current_page > 0 else 0
	
	var offset = current_page * page_length
	
	sb_size.set_value(size)
	
	sb_page.set_value(current_page)
	sb_page.set_visible(pages > 0)
	
	# Remove old items
	PAHelpers.remove_children(vb_items_list, [reorder_selected_element_hbox])
	
	#var amount = min(size - offset, page_length)
	for index in page_length:
		var array_pos = offset + index
		# out of bounds
		if array_pos > items.size() - 1:
			continue
		
		var hbox := HBoxContainer.new()
		vb_items_list.add_child(hbox)
		hbox.set_owner(vb_items_list.get_owner())
		
		# reorder button
		var reorder_button := Button.new()
		reorder_button.icon = self.get_icon("TripleBar", "EditorIcons")
		reorder_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
		reorder_button.connect("gui_input", self, "_reorder_button_gui_input")
		reorder_button.connect("button_down", self, "_reorder_button_down", [array_pos])
		reorder_button.connect("button_up", self, "_reorder_button_up")
		hbox.add_child(reorder_button)
		
		# text edit
		var line_edit := LineEdit.new()
		line_edit.text = items[array_pos]
		line_edit.connect("text_changed", self, "_property_text_changed", [array_pos])
		line_edit.connect("text_entered", self, "_property_text_entered", [array_pos])
		line_edit.connect("focus_exited", self, "_property_focus_exited")
		#line_edit.size_flags_horizontal += SIZE_EXPAND
		line_edit.rect_clip_content = true
		
		hbox.add_child(line_edit)
		
		# node path selection button
		var select_button := Button.new()
		select_button.set_text("Select")
		select_button.connect("pressed", self, "_select_node_path", [array_pos])
		hbox.add_child(select_button)
		
		# remove button
		var remove_button := Button.new()
		remove_button.icon = self.get_icon("Remove", "EditorIcons")
		remove_button.connect("pressed", self, "_remove_pressed", [array_pos])
		hbox.add_child(remove_button)
		
		# add box and it's children to items list
		PAHelpers.reparent_node(hbox,vb_items_list)
	emit_signal("updated", items)

# remove element
func _remove_pressed(property_index:int):
	items.remove(property_index)
	update_items()

# showing node path selection dialog
func _select_node_path(property_index:int):
	# onready vars should be loaded first
	if not is_inside_tree() or _plugin == null:
		return
	if select_ui.is_connected("confirmed", self, "_scene_node_selected"):
		# disconnect from previous
		select_ui.disconnect("confirmed", self, "_scene_node_selected")
	# reconnect with current index
	select_ui.connect("confirmed", self, "_scene_node_selected", [property_index])
	select_ui.popup_centered()

# once scene node selected
func _scene_node_selected(property_index:int):
	
	var file_path = select_ui.get_files_tree_path()
	if file_path == "":
		return
	
	var node_path = select_ui.get_scene_tree_path()
	if node_path == "":
		return
	
	if property_index >= items.size() or property_index < 0:
		return
	
	# set value to property
	items[property_index] = file_path + "[|]" + node_path
	emit_signal("updated", items)

# once user finished text entering
func _property_focus_exited():
	emit_signal("updated", items)

# on enter press
func _property_text_entered(new_text: String, property_index:int):
	emit_signal("updated", items)

# once text of property is changed
func _property_text_changed(new_text: String, property_index:int):
	# bounds check
	if property_index >= items.size() or property_index < 0:
		return
	items[property_index] = new_text

# start reorder
func _reorder_button_down(index:int):
	reorder_from_index = index
	reorder_to_index = index
	var target_pos = index % page_length
	# set element refrences
	reorder_selected_element_hbox = vb_items_list.get_child(target_pos) as HBoxContainer
	reorder_selected_button = reorder_selected_element_hbox.get_child(0) as Button
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# stop reorder
func _reorder_button_up():
	var from = reorder_from_index
	var to = reorder_to_index
	
	# reset value
	reorder_from_index = -1
	reorder_to_index = -1
	reorder_mouse_y_delta = 0.0
	
	if from != to:
		# move the element
		var value_to_move = items[from]
		var prev_value = items[to]
		items[from] = prev_value
		items[to] = value_to_move
		
		emit_signal("reordered", items)
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	reorder_selected_button.warp_mouse(reorder_selected_button.get_size() / 2.0)
	
	reorder_selected_element_hbox = null
	reorder_selected_button = null
	
	update_items()

# reorder button drag processing
func _reorder_button_gui_input(event:InputEvent):
	# don't process this if no reordering pressed
	if reorder_from_index == -1:
		return
	
	if event is InputEventMouseMotion:
		var mm = event as InputEventMouseMotion
		
		var size = items.size()

		reorder_mouse_y_delta += mm.get_relative().y

		# Reordering is done by moving the dragged element by +1/-1 index at a time based on the cumulated mouse delta so if
		# already at the array bounds make sure to ignore the remaining out of bounds drag (by resetting the cumulated delta).
		if (reorder_to_index == 0 and reorder_mouse_y_delta < 0.0) or (reorder_to_index == size - 1 && reorder_mouse_y_delta > 0.0):
			reorder_mouse_y_delta = 0.0
			return

		var required_y_distance = 20.0 * _plugin.get_editor_interface().get_editor_scale() # Editor.get_scale()
		if abs(reorder_mouse_y_delta) > required_y_distance:
			var direction = 1 if reorder_mouse_y_delta > 0.0 else -1
			
			# maintain offset
			reorder_mouse_y_delta -= required_y_distance * direction

			reorder_to_index += direction
			if (direction < 0 and reorder_to_index % page_length == page_length - 1) or (direction > 0 and reorder_to_index % page_length == 0):
				# Automatically move to the next/previous page.
				sb_page.set_value(current_page + direction)
			
			var child_count = vb_items_list.get_child_count()
			
			if child_count > 0 and reorder_selected_element_hbox != null:
				var target_index = reorder_to_index % page_length
				vb_items_list.move_child(reorder_selected_element_hbox, target_index)
