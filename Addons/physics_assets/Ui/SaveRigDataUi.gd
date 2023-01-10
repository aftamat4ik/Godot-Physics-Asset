tool
extends VBoxContainer

onready var btn_save_data := get_node("%BtnSaveRigData")

# save dialog
onready var save_file_dialog:FileDialog

# this folder will be used by save dialog
const resources_folder := "res://Addons/physics_assets/Resources/Skeleton Data/"

# Refrence to owner-plugin
var _plugin:EditorPlugin
var _inspector_plugin:EditorInspectorPlugin
var _editor_interface:EditorInterface
var _edited_scene_root:Node


# Pseudo-Constructor
# there is no way of overriding node instance constructors, so i have to use this instead
func init(plugin:EditorPlugin, inspector_plugin:EditorInspectorPlugin):
	_plugin = plugin
	inspector_plugin = _inspector_plugin
	_editor_interface = plugin.get_editor_interface()
	_edited_scene_root = _editor_interface.get_edited_scene_root()
	

func _ready():
	# in case if no init was called
	if not _plugin:
		printerr(PAErrors.ERR_INIT)
		return
	
	btn_save_data.connect("pressed", self, "show_save_data_dialog")
	
	# create save file dialog
	save_file_dialog = FileDialog.new()
	
	save_file_dialog.mode = FileDialog.MODE_SAVE_FILE
	save_file_dialog.access = FileDialog.ACCESS_RESOURCES
	save_file_dialog.filters = ["*.tres ; Resources"]
	save_file_dialog.rect_min_size.x = 550
	save_file_dialog.rect_min_size.y = 300
	save_file_dialog.size_flags_horizontal = SIZE_EXPAND_FILL
	save_file_dialog.size_flags_vertical = SIZE_EXPAND_FILL
	# attach dialog to the editor viewport
	var root = _plugin.get_editor_interface().get_editor_viewport()
	# if not initialised yet or in case of queue_free is called
	if not root.is_a_parent_of(save_file_dialog):
		# add dialog to scene
		root.add_child(save_file_dialog)
		save_file_dialog.set_owner(root.get_owner())
	save_file_dialog.connect("file_selected", self, "save_skeletal_data")

# showing save file dialog
func show_save_data_dialog():
	# set current directory
	save_file_dialog.set_current_path(resources_folder)
	
	# show dialog
	save_file_dialog.popup_centered()

# on save data
func save_skeletal_data(path:String):
	var selected_node := PAHelpers.get_selected_node(_plugin)
	if not selected_node is Skeleton:
		return
	
	var skeleton_ref = selected_node as Skeleton
	var skeleton_data:= {}
	# note: sometimes armature get's scaled on import. For example if we import rig from Unreal Engine we'l get armature scale multiplied by 0.01
	# we need to preserve this scale
	for bone_id in range( skeleton_ref.get_bone_count() ):
		# put list of bone data into Dictionary
		skeleton_data[bone_id] = {}
		skeleton_data[bone_id]["name"] = skeleton_ref.get_bone_name(bone_id)
		
		var parent = skeleton_ref.get_bone_parent(bone_id)
		var should_apply_scale:bool = (parent == -1)
		
		skeleton_data[bone_id]["parent"] = parent
		skeleton_data[bone_id]["parent_name"] = skeleton_ref.get_bone_name(parent) if parent != -1 else ""
		
		skeleton_data[bone_id]["rest"] = skeleton_ref.get_bone_rest(bone_id)
		skeleton_data[bone_id]["pose"] = skeleton_ref.get_bone_pose(bone_id)
		skeleton_data[bone_id]["custom_pose"] = skeleton_ref.get_bone_custom_pose(bone_id)
		skeleton_data[bone_id]["bone_rest_disabled"] = skeleton_ref.is_bone_rest_disabled(bone_id)
	
	var file_to_write = path
	var resource: = SkeletonDataResource.new()
	resource.data = skeleton_data
	resource.scale = skeleton_ref.global_transform.basis.get_scale()
	# save
	ResourceSaver.save(file_to_write,resource)
