tool
class_name TreeFiles
extends Tree
# some of the code taken (and re-written) from https://github.com/zaevi/godot-filesystem-view, MIT license - https://github.com/zaevi/godot-filesystem-view/blob/master/LICENSE

# Refrence to owner-plugin
var _plugin:EditorPlugin
var _filesystem:EditorFileSystem
# List of collapsed folders
var _cache_collapsed = []

export(PoolStringArray) var filter_extensions = ["*.tscn"]
export(PoolStringArray) var file_opened_paths = ["res://Addons/physics_assets/Scene/PhysicsAssetScene.tscn"]

func _ready():
	# disable multi select
	select_mode = Tree.SELECT_SINGLE

	# bindings
	connect("item_activated", self, "on_file_tree_item_double_click")
	connect("item_rmb_selected", self, "on_file_tree_item_rmb_selected")
	connect("multi_selected", self, "on_file_tree_multi_items_selected")
	connect("item_collapsed", self, "on_item_collapsed")
	
	# forward drag & drop events from files tree to current class
	# this will force engine to call get_drag_data_fw, can_drop_data_fw, drop_data_fw
	# disabled because abandoned
	# can be safely removed
	#set_drag_forwarding(self)

# Initialise
func init(plugin:EditorPlugin):
	_plugin = plugin
	# refrence to filesystem
	_filesystem = _plugin.get_editor_interface().get_resource_filesystem()
	if not _filesystem.is_connected("filesystem_changed", self, "update_files_tree"):
		_filesystem.connect("filesystem_changed", self, "update_files_tree")

# update tree items
func update_files_tree():
	# in case if no _plugin is set
	if _plugin == null and Engine.editor_hint:
		printerr(PAErrors.ERR_INIT)
		return

	# if root exists then clear all nodes from tree
	if get_root():
		clear_tree()
	
	_build_files_tree(null, _filesystem.get_filesystem())

	#_hide_empty_dir(get_root())
	update_file_filters()
	update_collapsed_nodes()
	update_selections()

# recursive files tree builder
func _build_files_tree(parent: TreeItem, current_dir: EditorFileSystemDirectory):
	var root_item = create_item(parent)
	var dname = current_dir.get_name()
	dname = "res://" if dname == "" else dname
		
	root_item.set_text(0, dname)
	root_item.set_selectable(0, true)

	#if parent == null:
		# select first item by default
	#	root_item.select(0)
	
	root_item.set_icon(0, get_icon("Folder", "EditorIcons"));
	root_item.set_icon_modulate(0, get_color("folder_icon_modulate", "FileDialog"));
	#root_item.collapsed = true if parent != null else false 
	var dir_path = current_dir.get_path()
	set_item_path (root_item, dir_path)
	
	# run recursion for each subfolder
	for subdir_index in current_dir.get_subdir_count():
		_build_files_tree(root_item, current_dir.get_subdir(subdir_index))
	
	var previewer = _plugin.get_editor_interface().get_resource_previewer()
	
	for file_index in current_dir.get_file_count():
		var file_name = current_dir.get_file(file_index)
		var file_path = dir_path.plus_file(file_name)
		
		var file_item:TreeItem = create_item(root_item)
		file_item.set_text(0, file_name)
		file_item.set_icon(0, _get_tree_item_icon(current_dir, file_index))
		
		# store current item path
		set_item_path(file_item, file_path)
		
		previewer.queue_resource_preview(file_path, self, "_create_tree_preview_callback", file_item)

# clears tree
func clear_tree():
	cache_collapsed()
	clear()

# sometimes icons won't show. this fix it
func _create_tree_preview_callback(path, preview, small_preview : Texture, file_item):
	if small_preview and file_item:
		file_item.set_icon(0, small_preview)

# hide empty dirs
func _hide_empty_dir(current: TreeItem):
	var should_clean = true
	
	var item: TreeItem = current.get_children()
	# go thru all items in current folder
	while item:
		var path : String = get_item_path(item)
		if path.ends_with("/"):
			if _hide_empty_dir(item):
				current.remove_child(item)
			else:
				should_clean = false
		else:
			return false
		
		item = item.get_next()
		
	return should_clean

# filter files from tree root
func update_file_filters():
	_apply_file_filters(get_root())

# hide filreted files
func _apply_file_filters(current:TreeItem):
	var item: TreeItem = current.get_children()
	# go thru all items in current folder
	while item:
		var path : String = get_item_path(item)
		# foreach file
		if not path.ends_with("/"):
			if not is_path_match_filters(path):
				current.remove_child(item)
		else:
			# recursively go thru all files in subfolders
			_apply_file_filters(item)
		item = item.get_next()

# checks if provided path matches any of custom filters
# in current case i filter it only by extension
func is_path_match_filters(path:String)->bool:
	# foreach extension in extensions list
	for ext in filter_extensions:
		if path.matchn(ext):
			return true
	return false

# retrieves icon for file in directory
# looks for files not based on name, but based on file index
func _get_tree_item_icon(dir: EditorFileSystemDirectory, idx: int) -> Texture:
	var icon : Texture
	if not dir.get_file_import_is_valid(idx):
		icon = get_icon("ImportFail", "EditorIcons")
	else:
		var file_type = dir.get_file_type(idx)
		if has_icon(file_type, "EditorIcons"):
			icon = get_icon(file_type, "EditorIcons")
		else:
			icon = get_icon("File", "EditorIcons")
	return icon

# set file_path to tree item metadata on index 0
func set_item_path(tree_item:TreeItem, path:String):
	tree_item.set_metadata(0, path)

# retrieves file_path from item
func get_item_path(tree_item:TreeItem)->String:
	return tree_item.get_metadata(0) as String

# update collapsed node states
func update_collapsed_nodes():
	# we don't want to fire "item_collapsed" event during this update bks it will affect _cache_collapsed array
	
	if is_connected("item_collapsed", self, "on_item_collapsed"):
		disconnect("item_collapsed", self, "on_item_collapsed")

	if _cache_collapsed.size() > 0:
		_apply_collapsed(get_root(), false)
	else:
		# on first load all child of tree root should be collapsed
		_apply_collapsed(get_root(), true)
	
	connect("item_collapsed", self, "on_item_collapsed")

# collapse-uncollapse folders
func _apply_collapsed(current:TreeItem, collapsed:bool):
	var item: TreeItem = current.get_children()
	
	while item:
		var path: String = get_item_path(item)
		var idx = _cache_collapsed.find(path)
		# for folders
		if path.ends_with("/"):
			_apply_collapsed(item, collapsed)
			# *only folders in filesystem can be collapsed or uncollapsed
			if idx != -1:
				item.collapsed = not collapsed
			else:
				item.collapsed = collapsed
		# we don't need to collapse items that should be shown
		if is_match_show_paths(path):
			item.collapsed = false
		item = item.get_next()

# update node selections from root
func update_selections():
	_apply_selections(get_root())

# selects nodes that should be shown
func _apply_selections(current:TreeItem):
	var item: TreeItem = current.get_children()
	while item:
		var path: String = get_item_path(item)
		if path.ends_with("/"):
			_apply_selections(item)
		if is_match_show_paths(path):
			# select shown files
			if not path.ends_with("/"):
				item.select(0)
		item = item.get_next()

# check if given path maches any of items in show_path array
func is_match_show_paths(path:String)->bool:
	for s_path in file_opened_paths:
		# we can auto-mask our path
		# path = path.replace("res://","")
		# var mask = "*"+path+"*"
		# if s_path.matchn(mask):
		if s_path.findn(path) != -1:
			return true
	return false

# save list of currently collapsed folders
func cache_collapsed():
	var list = []
	_cache_collapsed_list(get_root(), list)
	_cache_collapsed = list

# recursive walk along folders to cache their states into array
func _cache_collapsed_list(parent: TreeItem, list: Array):
	var item: TreeItem = parent.get_children()
	while item: 
		var path : String = get_item_path(item)
		if path.ends_with("/"):
			_cache_collapsed_list(item, list)
			if item.collapsed:
				list.append(path)
		item = item.get_next()
 
# selected item paths
func get_selected_paths():
	var paths = []
	var item = get_next_selected(null)
	while item:
		paths.push_back(get_item_path(item))
		item = get_next_selected(item)
	
	return paths

# Bindings

# file_tree item double click - was used for debug
func on_file_tree_item_double_click():
	pass
	# var clicked_item = get_selected()
	# var path = get_item_path(clicked_item)
	# # debug path
	# print(path)

# right mouse click
func on_file_tree_item_rmb_selected(position:Vector2):
	pass

# multiple items selected
func on_file_tree_multi_items_selected(item:TreeItem, column:int, selected:bool):
	pass

# on collapse
func on_item_collapsed(item:TreeItem):
	cache_collapsed()

# Drag & Drop
# # i set set_drag_forwarding in _ready to this class
# # so when user makes drang&drop in file_tree - this functions are called
# UNFINISHED! (it will conflict with main goal of dialogue - to select files, not to organise them)
# this goes to Editor Plugin in case if we want to implement drag&drop
# var interface: EditorInterface
# var filesystem: EditorFileSystem
# var editor_node : Node
# var filesystem_dock : Node
# var filesystem_popup : PopupMenu
# var filesystem_move_dialog: ConfirmationDialog
# var tree : Tree
# func _enter_tree():
# 	interface = get_editor_interface()
# 	filesystem = interface.get_resource_filesystem()
# 	editor_node = interface.get_base_control().get_parent().get_parent()
# 	filesystem_dock = interface.get_base_control().find_node("FileSystem", true, false)
# 	for i in filesystem_dock.get_children():
# 		if i is VSplitContainer:
# 			tree = i.get_child(0)
# 		elif i is PopupMenu:
# 			filesystem_popup = i
# 		elif i is ConfirmationDialog and i.has_signal("dir_selected"):
# 			filesystem_move_dialog = i
# 		if tree and filesystem_popup and filesystem_move_dialog:
# 			break
# func fsd_open_file(file_path: String):
# 	filesystem_dock.call("_select_file", file_path, false)


# func fsd_select_paths(paths: PoolStringArray):
# 	if paths.size() == 0:
# 		return

# 	var temp_item = tree.create_item(tree.get_root())
# 	var _start_select = false
# 	for path in paths:
# 		var item = tree.create_item(temp_item)
# 		item.set_metadata(0, path)
# 		if _start_select:
# 			item.select(0)
# 		else:
# 			tree.select_mode = Tree.SELECT_SINGLE
# 			item.select(0)
# 			tree.select_mode = Tree.SELECT_MULTI
# 			_start_select = true
	
# 	tree.emit_signal("multi_selected", null, 0, true)
# 	tree.get_root().call_deferred("remove_child", temp_item)
# 	tree.call_deferred("update")
# func get_drag_data_fw(position, from_control):
# 	var paths = get_selected_paths()
# 	plugin.fsd_select_paths(paths)
# 	return plugin.filesystem_dock.get_drag_data_fw(get_global_mouse_position(), plugin.tree)


# func can_drop_data_fw(position, data, from_control):
# 	var type = data["type"] if data.has("type") else null
# 	# todo resource is not supported
# 	if not type in ["files", "files_and_dirs"]:
# 		return false
# 	var target = _get_drag_target_folder(position)
# 	if not target:
# 		return false
	
# 	if type == "files_and_dirs":
# 		for path in data["files"]:
# 			if path.ends_with("/") and target.begins_with(path):
# 				return false
	
# 	return true


# func drop_data_fw(position, data, from_control):
# 	if not can_drop_data_fw(position, data, from_control):
# 		return
	
# 	var target = _get_drag_target_folder(position)
# 	var type = data["type"] if data.has("type") else null
	
# 	plugin.fsd_select_paths(data["files"])
# 	plugin.filesystem_dock.call("_tree_rmb_option", $Popup.Menu.FILE_MOVE)
# 	if plugin.filesystem_move_dialog.visible:
# 		plugin.filesystem_move_dialog.hide()
# 		plugin.filesystem_move_dialog.emit_signal("dir_selected", target)


# func _get_drag_target_folder(pos: Vector2):
# 	var item = tree.get_item_at_position(pos)
# 	var section = tree.get_drop_section_at_position(pos)
# 	if item:
# 		var path = item.get_metadata(0)
# 		var is_folder = path.ends_with("/")
# 		if is_folder and section == 0:
# 			return path # drop in folder
# 		elif is_folder and section != 0 and path != "res://":
# 			return path.substr(0, len(path)-1).get_base_dir() # drop in folder's base dir
# 		elif not is_folder:
# 			return path.get_base_dir() # drop in file's base dir
			
# 	return null
