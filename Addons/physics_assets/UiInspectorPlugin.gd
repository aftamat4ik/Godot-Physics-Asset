extends EditorInspectorPlugin

const ui_select_pa_res := preload("res://Addons/physics_assets/Ui/SaveRigDataUi.tscn")
const ui_pa_res := preload("res://Addons/physics_assets/Ui/RagdollSettingsUi.tscn")
const string_array_node_picker := preload("res://Addons/physics_assets/Ui/EditorProperty/NodePathsPickerEditorProperty.gd")
const string_array_res_picker := preload("res://Addons/physics_assets/Ui/EditorProperty/ResourcePickerEditorProperty.gd")
const bool_button_control := preload("res://Addons/physics_assets/Ui/EditorProperty/BoolButtonEditorProperty.gd")

const physics_asset_root_name = "PhysicsAssetScene_root"

# We can't instanciate our UI in here
# Since Inspector clears all it's widgets every time user switch an object
# So we should instanciate or utility ui Every Time and re-add it every time
# Because of that here will be just empty variable
var ui_instance

# Refrence to owner-plugin
var _plugin:EditorPlugin

# Pseudo-Constructor
func init(plugin:EditorPlugin):
	_plugin = plugin

# Objects types that will have our submenu ui in Inspector
func can_handle(object):
	if object is Skeleton:
		return true
	return false

# Add controls to the beginning of inspector property list
func parse_begin(object):
	# Get root node name of current scene
	var root_name = _plugin.get_editor_interface().get_edited_scene_root().get_name()
	if object is Skeleton:
		# if we currently inside of physics asset scene
		if root_name == physics_asset_root_name:
			# Instanciate physics asset related Ui
			ui_instance = ui_pa_res.instance()
		else:
			# Instanciate asset selection Ui
			ui_instance = ui_select_pa_res.instance()
		# Add Ui
		add_custom_control(ui_instance)
		# Call Constructor
		ui_instance.call("init", _plugin, self)

# Destroy ui instance if set
func clear_instance():
	if ui_instance != null:
		ui_instance.queue_free()

func parse_property(object, type, path, hint, hint_text, usage):
	# replace skeleton_paths export variable (which is PoolStringArray, CombinedSkeleton.gd)
	# with custom controll that allows to pick scene node paths into String Array fields
	if path == "skeleton_paths" and type == TYPE_STRING_ARRAY:
		#var value:PoolStringArray = object.get(path)
		# initialise custom control
		var property_replacer = string_array_node_picker.new()
		property_replacer.initialise(_plugin)
		add_property_editor(path, property_replacer)
		# in case if we want to replace internal property editor - true
		return true
	
	if path == "resources_list" and type == TYPE_STRING_ARRAY:
		# initialise custom control
		var property_replacer = string_array_res_picker.new()
		property_replacer.initialise(_plugin)
		add_property_editor(path, property_replacer)
		return true
	
	if path == "build" and type == TYPE_BOOL:
		# initialise custom control
		var property_replacer = bool_button_control.new()
		property_replacer.set_button_text("Build")
		add_property_editor(path, property_replacer)
		return true
	
	if path == "clear" and type == TYPE_BOOL:
		# initialise custom control
		var property_replacer = bool_button_control.new()
		property_replacer.set_button_text("Clear")
		add_property_editor(path, property_replacer)
		return true
	
	# by default false - keep internal editor
	return false

# We can add Inspector Plugin controls to special category
# func parse_category(object, category):
# 	# Show our UI in Skeleton section
# 	if category == "Skeleton":
# 		if object is Skeleton:
# 			# Instantiate UI
# 			utilites_ui_instance = utilities_ui_res.instance()
# 			# Add Control to the category
# 			add_custom_control(utilites_ui_instance)
