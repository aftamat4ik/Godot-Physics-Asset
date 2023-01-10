extends EditorProperty

const ui_node_paths_picker := preload("res://Addons/physics_assets/Ui/Controls/SceneNodePathsPicker/SceneNodePathsPicker.tscn")

var updating = false
var picker
var _plugin:EditorPlugin
var _editor_interface:EditorInterface

# called directly from UiInspectorPlugin.gd
func initialise(plugin:EditorPlugin):
	self._plugin = plugin
	self._editor_interface = plugin.get_editor_interface()
	
	picker = ui_node_paths_picker.instance()
	picker.init(_plugin)
	
	add_child(picker)
	
	# To remember focus when selected back:
	add_focusable(picker)
	picker.connect("updated", self, "_items_updated")

# sync ui data with property data
func _items_updated(items_list:PoolStringArray):
	if (updating):
		return
	
	# save
	emit_changed(get_edited_property(), items_list)

# triggered by engine when property is changed
func update_property():
	updating = true
	var array_items = get_edited_object()[get_edited_property()] as PoolStringArray
	picker.set_items(array_items)
	updating = false
