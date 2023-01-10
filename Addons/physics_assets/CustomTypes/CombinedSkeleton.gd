tool
extends Skeleton
class_name CombinedSkeleton

# this array turned into selector in UiInspectorPlugin
export (PoolStringArray) var resources_list
# this booleans turned into buttons in UiInspectorPlugin
export var load_scale:bool = true
# you can rebuild armature automatically every time you open the scene
export var build_on_load:bool = false
export var build:bool = false
export var phys_bones_follow_animtaion:bool = false
export var scan_child:bool = false
export var clear:bool = false

# child lists
var child_physical_bones:Array

# consts for meta fields
const BONE_ID_KEY = "bone_id"
const PARENT_BONE_ID_KEY = "parent_id"
const SIMULATING_KEY = "simulation_on"

func _process(delta):
	if Engine.is_editor_hint():
		# once build is checked - build armature
		if build:
			build_armature()
			# reset it back
			build = false
		# once clear is checked - clear armature
		if clear:
			clear_bones()
			update_gizmo()
			clear = false
		# scan child on tick
		if scan_child:
			scan_child()
			scan_child = false
		
		# make physical bones follow rig during animation
		# note: this hardly affects performance, so don't add big amount of physical bones
		if not has_meta(SIMULATING_KEY) and phys_bones_follow_animtaion:
			align_physical_bones()

# forses physical bones to follow armature deformations during animation
func align_physical_bones():
	for bone in child_physical_bones:
		if is_instance_valid(bone):
			var casted_bone = bone as PhysicalBone
			casted_bone.set_body_offset(casted_bone.get_body_offset())


# Build Armature on scene tree
func _enter_tree():
	if build_on_load:
		build_armature()

# overload since there is no way of detecting if we currently simulating physic or not
func physical_bones_start_simulation(bones:Array=[]):
	set_meta(SIMULATING_KEY, 1)
	print("start sim")
	.physical_bones_start_simulation(bones)

func physical_bones_stop_simulation():
	scan_child()
	print("stop sim")
	remove_meta(SIMULATING_KEY)
	.physical_bones_stop_simulation()
	align_physical_bones()

# scans child nodes to fill necessary lists
func scan_child():
	child_physical_bones = PAHelpers.find_child_list_of_class(self, "PhysicalBone")

# Builds Armature
func build_armature():
	clear_bones()
	
	for res in resources_list:
		generate_bones_from_res(res)
	
	clear_bones_global_pose_override()

# Makes dictionary from child nodes in format <body_id><Node of class>
func build_body_relatives(for_class:String)->Dictionary:
	var res:Dictionary
	# build rigids dictionary
	for tbody in PAHelpers.find_child_list_of_class(self, for_class):
		if tbody.has_meta(BONE_ID_KEY):
			var bone_id = tbody.get_meta(BONE_ID_KEY)
			if bone_id == -1:
				continue
			var name = get_bone_name(bone_id)
			res[name] = tbody
	return res

# Re-create bones from resource data
func generate_bones_from_res(resource_path:String):
	var resource = ResourceLoader.load(resource_path) as SkeletonDataResource
	
	var data:Dictionary = resource.data
	for bone_id in data.keys():
		var bone_data = data[bone_id]
		var bone_index = find_bone(bone_data["name"])
		
		# do not add bones with the same name and same parent
		if bone_index != -1:
			if get_bone_parent(bone_index) == bone_data["parent"]:
				continue
		
		add_bone(bone_data["name"])
		# get added bone index
		bone_index = find_bone(bone_data["name"])
		
		# try to find parent with the same and attach armature to it's id first
		var parent_index = find_bone(bone_data["parent_name"])
		if parent_index != -1:
			set_bone_parent(bone_index, parent_index)
		else:
			set_bone_parent(bone_index, bone_data["parent"])
		set_bone_rest(bone_index, bone_data["rest"])
		#set_bone_pose(bone_index, bone_data["pose"])
		set_bone_custom_pose(bone_index, bone_data["custom_pose"])
		set_bone_disable_rest(bone_index, bone_data["bone_rest_disabled"])
	# apply saved scale
	if load_scale:
		set_scale(resource.scale)
