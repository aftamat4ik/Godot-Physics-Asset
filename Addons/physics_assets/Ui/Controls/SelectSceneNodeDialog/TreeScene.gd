tool
class_name TreeScene
extends Tree

var _plugin:EditorPlugin
# List of collapsed folders
var _cache_collapsed = {}

# loaded scene root
var scene_root:Node
export(String) var selected_node:String = ""
export(String) var selectable_class = "Skeleton"
export(String) var current_scene_path = ""

func _ready():
	# bindings
	connect("item_activated", self, "on_file_tree_item_double_click")
	connect("item_collapsed", self, "on_item_collapsed")

# Initialise
func init(plugin:EditorPlugin):
	_plugin = plugin

func build_scene_tree(scene_path:String = ""):
	# in case if no _plugin is set
	if _plugin == null and Engine.editor_hint:
		printerr(PAErrors.ERR_INIT)
		return
	
	# if root exists then clear all nodes from tree
	if get_root():
		clear_tree()

	if scene_path == "" and PAHelpers.is_scene_path(current_scene_path):
		scene_path = current_scene_path
	else:
		current_scene_path = scene_path
	
	# in case if no scene path specified
	if scene_path == "":
		return
	
	scene_root = load(scene_path).instance()
	_build_children_tree(scene_root)
	update_collapsed()
	update_selections()

func _build_children_tree(scene_node:Node, parent:TreeItem = null, comb_path:String = ""):
	
	var core_item = create_item(parent)

	# recursively construct path to the node 
	# since scene_node.get_path() dosen't work for scenes that are instanced, but not spawned in scene tree
	#if parent != null: # ignore scene root
	if comb_path != "":
		comb_path += "/"
	comb_path += scene_node.name

	# store current item path
	set_item_path(core_item, comb_path )

	core_item.set_text(0, scene_node.get_name())
	core_item.set_icon(0, _get_node_icon(scene_node))
	
	# selectable
	# it could be shorter. but i like it as it is
	if selectable_class == "" or scene_node.is_class(selectable_class):
		core_item.set_selectable(0, true)
	else:
		core_item.set_selectable(0, false)
	
	for s_node in scene_node.get_children():
		_build_children_tree(s_node, core_item, comb_path)

# clears tree
func clear_tree():
	cache_collapsed()
	clear()

# children count
func get_children_count(of_item:TreeItem)->int:
	var item: TreeItem = of_item.get_children()
	var icount :int = 0;
	if item != null:
		while item:
			icount += 1
			item = item.get_next()
	return icount

# update collapsed children states from root
func update_collapsed():
	# we don't want to fire "item_collapsed" event during this update bks it will affect _cache_collapsed dictionary
	if is_connected("item_collapsed", self, "on_item_collapsed"):
		disconnect("item_collapsed", self, "on_item_collapsed")

	if _cache_collapsed.has(current_scene_path) and _cache_collapsed[current_scene_path].size() > 0:
		_apply_collapsed_state(get_root(), false)
	else:
		# on first load all child of tree root should be collapsed
		_apply_collapsed_state(get_root(), true)
	
	connect("item_collapsed", self, "on_item_collapsed")

# collapsed state recursive apply
func _apply_collapsed_state(current:TreeItem, state:bool = false):
	var item: TreeItem = current.get_children()

	while item:
		var path = get_item_path(item)
		var idx = -1
		if _cache_collapsed.has(current_scene_path):
			idx = _cache_collapsed[current_scene_path].find(path)
		
		if is_match_show_paths(path):
			item.collapsed = false
		else:
			if idx != -1:
				item.collapsed = not state
			else:
				item.collapsed = state

		if get_children_count(item) > 0:
			_apply_collapsed_state(item, state)
		
		item = item.get_next()

# caches collapsed nodes state
func cache_collapsed():
	_cache_collapsed[current_scene_path] = _cache_collapsed_list(get_root())

# recursively walks among nodes and returns their states
func _cache_collapsed_list(current:TreeItem)->Array:
	var item: TreeItem = current.get_children()
	var list = []
	while item:
		var path: String = get_item_path(item)

		if item.collapsed:
			list.append(path)
		
		if get_children_count(item) > 0:
			var subr = _cache_collapsed_list(item)
			list.append_array(subr)

		item = item.get_next()
	return list


# update node selections from root
func update_selections():
	_apply_selections(get_root())

# make node on path selected
func _apply_selections(current:TreeItem):
	var item: TreeItem = current.get_children()
	while item:
		var path: String = get_item_path(item)
		if get_children_count(item) > 0:
			_apply_selections(item)
		if is_match_show_paths(path):
			# select shown files
			if get_children_count(item) == 0:
				item.select(0)
		item = item.get_next()

# check if given path maches any of items in show_path array
func is_match_show_paths(path:String)->bool:
	var root_path = get_item_path(get_root())
	if root_path != "":
		path = path.replace(root_path +"/","")
	
	if selected_node.findn(path) != -1:
		return true
	return false

# Data

# set file_path to tree item metadata on index 0
func set_item_path(tree_item:TreeItem, path:String):
	tree_item.set_metadata(0, path)

# retrieves file_path from item
func get_item_path(tree_item:TreeItem)->String:
	return tree_item.get_metadata(0) as String

# retrieves icon for file in directory
# looks for files not based on name, but based on file index
func _get_node_icon(node:Node) -> Texture:
	
	var icon : Texture
	var icon_type = node.get_class()
	if has_icon(icon_type,"EditorIcons"):
		icon = get_icon(icon_type, "EditorIcons")
		
	return icon

# tree item double click was used for debug
func on_file_tree_item_double_click():
	pass
	#var clicked_item = get_selected()
	#var path = get_item_path(clicked_item)
	# debug path
	#print(path)
	#print(get_children_count(clicked_item))
	#print(_cache_collapsed)

# update collapsed states on collapse
func on_item_collapsed(item:TreeItem):
	cache_collapsed()
