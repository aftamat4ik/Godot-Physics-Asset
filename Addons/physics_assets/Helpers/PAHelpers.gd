class_name PAHelpers

# Return all filenames and directories (with full filepaths) under root path
static func get_dir_contents(rootPath: String) -> Array:
	var files = []
	var directories = []
	var dir = Directory.new()

	if dir.open(rootPath) == OK:
		dir.list_dir_begin(true, false)
		_add_dir_contents(dir, files, directories)
	else:
		push_error("An error occurred when trying to access the path.")

	return [files, directories]

# Recursively list and add all filenames and directories 
# with full paths to their respective arrays
static func _add_dir_contents(dir: Directory, files: Array, directories: Array):
	var file_name = dir.get_next()

	while (file_name != ""):
		var path = dir.get_current_dir() + "/" + file_name

		if dir.current_is_dir():
			print("Found directory: %s" % path)
			var subDir = Directory.new()
			subDir.open(path)
			subDir.list_dir_begin(true, false)
			directories.append(path)
			_add_dir_contents(subDir, files, directories)
		else:
			print("Found file: %s" % path)
			files.append(path)

		file_name = dir.get_next()

	dir.list_dir_end()


# way to get editor scene selected nodes
# works only with tool scripts
static func get_selected_nodes(plugin:EditorPlugin)->Array:
	return plugin.get_editor_interface().get_selection().get_selected_nodes()

# for single node
static func get_selected_node(plugin:EditorPlugin)->Node:
	var selected = get_selected_nodes(plugin)
	
	if not selected.empty():
		# Always pick first node in selection
		return selected[0]
	
	return null

# selects desired node in editor
static func select_editor_node(plugin:EditorPlugin, node:Node):
	plugin.get_editor_interface().get_selection().add_node(node)

# removes node selection
static func deselect_editor_node(plugin:EditorPlugin, node:Node):
	plugin.get_editor_interface().get_selection().remove_node(node)

# getting edited scene
static func get_edited_scene_root(plugin:EditorPlugin):
	return plugin.get_editor_interface().get_edited_scene_root()

# Default godot's get_children() dosen't return nested child nodes
# This one returns all of them
static func collect_children(in_node:Node, ignore_class:String = "", arr:Array = []):
	arr.push_back(in_node)
	for child in in_node.get_children():
		if ignore_class != "" and child.is_class(ignore_class):
			continue
		arr = collect_children(child, ignore_class, arr)
	return arr

# Align transform's Up axis with given normal vector
static func align_up_with_normal(inTransfrom:Transform, normal:Vector3)->Transform:
	# Normal should be new UP axis (in godot Y axis is Up)
	inTransfrom.basis.y = normal
	# We know that x axis is always perpendicular to the Y axis 
	# By knowing this we can create X axis with cross product to new Y axis
	inTransfrom.basis.x = -inTransfrom.basis.z.cross(normal)
	inTransfrom.basis = inTransfrom.basis.orthonormalized()
	return inTransfrom

# returns vector rotation angles in radians relative to world coordinates (Vector3.UP, Vector3.LEFT, Vector.FORWARD)
static func get_vector_rotation_rad(vector:Vector3)->Vector3:
	var direction := vector.normalized()
	var left_axis := Vector3.UP.cross(direction).normalized()
	var basis_rotation:Vector3 = Basis(left_axis, Vector3.UP, direction).get_euler()
	
	return basis_rotation

# Gdscript somehow dosen't support 2d arrays by default so i have to use this instead
# usage:
# var a = DA_QuickRefs.create_2d_array(5,2)
# a[3][1] = 2
static func create_2d_array(w, h):
	var map = []

	for x in range(w):
		var col = []
		col.resize(h)
		map.append(col)

	return map

# way to copy node and all it's properties + metadata
static func clone(node: Node) -> Node:
	var copy = node.duplicate()
	var properties: Array = node.get_property_list()

	# since duplicate donse't copy script properties we should do it manually
	var script_properties: Array = []
	# build property list
	for prop in properties:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == PROPERTY_USAGE_SCRIPT_VARIABLE:
			script_properties.append(prop)
	# set property values
	for prop in script_properties:
		copy.set(prop.name, node[prop.name])
	
	# also copy metadata fields
	for prop in node.get_meta_list():
		copy.set_meta(prop, node.get_meta(prop))

	return copy

# scene path check
static func is_scene_path(path)->bool:
	return not path.ends_with("/") and path.get_extension() == "tscn"

# node reparenting
static func reparent_node(node_to_reparent, new_parent)->Node:
	var old_parent = node_to_reparent.get_parent()
	if old_parent != null:
		old_parent.remove_child(node_to_reparent)

	new_parent.add_child(node_to_reparent)

	set_owner_for_node_and_children(node_to_reparent, new_parent.get_owner())
	return node_to_reparent

# without setting owner node will not appear in scene tree in tool mode
# this function does setting owner recursively
# which is necessary if we reparented node with already attached child nodes, such as collisions
static func set_owner_for_node_and_children(node, owner):
	node.set_owner(owner)
	for child_node in node.get_children():
		set_owner_for_node_and_children(child_node, owner)

# recursively goes thru node hierarchy to find parent node of class
static func get_parent_of_class(for_node:Node, parent_class:String)->Node:
	if for_node == null:
		return null
	if for_node.is_class(parent_class):
		return for_node
	else:
		return get_parent_of_class(for_node.get_parent(), parent_class)

# recursively looks for all child nodes of given class
static func find_child_list_of_class(node: Node, className: String, ignore_class: String = "") -> Array:
	var res = []
	if node.is_class(className) :
		res.push_back(node)
	for child in node.get_children():
		if ignore_class != "" and child.is_class(ignore_class):
			continue
		var child_nodes:Array = find_child_list_of_class(child, className, ignore_class)
		if child_nodes.size() > 0:
			res.append_array(child_nodes)
	return res

# gets rid of children
# note: no need for recursion here because in godot if you delete top-level node - all it's siblevels gets removed automatically
static func remove_children(node:Node, except:Array = []):
	for n in node.get_children():
		if n in except:
			continue
		node.remove_child(n)
		n.queue_free()
