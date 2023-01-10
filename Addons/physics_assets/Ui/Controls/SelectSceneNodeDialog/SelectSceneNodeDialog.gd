tool
extends ConfirmationDialog
class_name SelectSceneNodeDialog
# some of the code taken (and re-written) from https://github.com/zaevi/godot-filesystem-view, MIT license - https://github.com/zaevi/godot-filesystem-view/blob/master/LICENSE

# Refrence to owner-plugin
var _plugin:EditorPlugin

export(PoolStringArray) var filter_extensions = ["*.tscn"]
export(PoolStringArray) var file_opened_paths = ["res://Addons/physics_assets/Scene/PhysicsAssetScene.tscn"]
export(String) var selected_node:String = ""
export(String) var selectable_class = "Skeleton"
export(String) var current_scene_path = ""

# Files Tree
onready var tree_files:TreeFiles = get_node("%TreeFiles")
# Scene Tree
onready var tree_scene:TreeScene = get_node("%TreeScene")

var files_tree_path = ""
var scene_tree_path = ""

# Initialise
func init(plugin:EditorPlugin):
	_plugin = plugin

func _ready():
	# in case if no init was called
	if _plugin == null:
		# Emulate plugin
		_plugin = EditorPlugin.new()
		printerr(PAErrors.ERR_INIT)
	
	# show
	connect("about_to_show", self, "on_popup_about_to_show")
	# hide
	connect("popup_hide", self, "on_popup_hide")
	
	# once user selected scene in files tree
	tree_files.connect("item_selected", self, "on_files_tree_item_selected")
	tree_scene.connect("item_selected", self, "on_scene_tree_item_selected")

# in case of some settings change - we can use this to update
func update_settings():
	tree_files.file_opened_paths = file_opened_paths
	tree_files.filter_extensions = filter_extensions
	tree_scene.selected_node = selected_node
	tree_scene.selectable_class = selectable_class
	tree_scene.current_scene_path = current_scene_path

# Bindings

func on_popup_about_to_show():
	update_settings()
	
	tree_files.call("init",_plugin)
	tree_scene.call("init",_plugin)

	tree_files.update_files_tree()
	tree_scene.build_scene_tree()

# on hide
func on_popup_hide():
	tree_files.clear_tree()
	tree_scene.clear_tree()

# scene tree item selected event
func on_scene_tree_item_selected():
	var item = tree_scene.get_selected()
	if item == null:
		return
	scene_tree_path = tree_scene.get_item_path(item)
	

# on files tree item selected event
func on_files_tree_item_selected():
	var item = tree_files.get_selected()
	if item == null:
		return ""
	files_tree_path = tree_files.get_item_path(item)
	# load scene into tree
	if PAHelpers.is_scene_path(files_tree_path):
		tree_scene.build_scene_tree(files_tree_path)

# scene tree path
func get_scene_tree_path()->String:
	return scene_tree_path

# files tree path
func get_files_tree_path()->String:
	return files_tree_path

# results in array[scene_file_path, scene_node path]
func get_total_path()->Array:
	return [get_files_tree_path(),get_scene_tree_path()]
