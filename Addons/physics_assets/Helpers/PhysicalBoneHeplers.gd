class_name PhysicalBoneHeplers
# skeleton related static functions

# PhysicalBone.name prefix
const PBONE_PREFIX = "Pb_"

# generation of physical bone
static func generate_physical_bones(skeleton_ref:Skeleton, container:Node)->Dictionary:
	# dictionary <int bone_id><PhysicalBone>
	var bones_list = {}
	var cnt = 0
	for bone_id in range( skeleton_ref.get_bone_count() ):
		if bone_id == -1:
			continue
		
		var parent = skeleton_ref.get_bone_parent(bone_id)
		
		# we don't want to create any physical bones on non-attached bones
		if parent == -1:
			continue
		
		var pbone = create_physical_bone(skeleton_ref, parent, bone_id, container)
		
		bones_list[bone_id] = pbone
		#if pbone and bones_list.values().find(pbone) == -1:
			# put bone in list
		
#		cnt += 1
#		if cnt > 10:
#			break

	return bones_list


# creates physical bone + collision shape
static func create_physical_bone(skeleton_ref:Skeleton, bone_id:int, bone_child_id:int, container:Node)->PhysicalBone:
	var child_rest:Transform = skeleton_ref.get_bone_rest(bone_child_id)
	var bone_rest:Transform = skeleton_ref.get_bone_rest(bone_id)
	
	var half_height = child_rest.origin.length() * 0.5
	var radius = half_height * 0.2

	# * this  code taken from original godot's sources c++ file that implements "Create physical sceleton" command in godot inteface
	# file - godot-3.5-stable.tar/editor/plugins/skeleton_editor_plugin.cpp
	# line - 100, function - create_physical_bone
	# so my plugin works same way as original physical skeleton function, but with extensions

	var collision = CollisionShape.new()
	var capsule_shape = CapsuleShape.new()
	
	capsule_shape.set_height((half_height - radius) * 2)
	capsule_shape.set_radius(radius)
	collision.shape = capsule_shape
	
	var body_transform:= Transform()

# * this is my old code. It's stil works, But! for Not attached body. For attached body it won't work!
#	# we will look from child bone to current bone and apply looking direction
#	var look_to_origin = skeleton_ref.get_bone_global_pose(bone_id).origin
#	body_transform.origin = skeleton_ref.get_bone_global_pose(bone_child_id).origin
#	body_transform = body_transform.looking_at(look_to_origin, Vector3.UP)
#	# by default bone transform given in the middle of bone
#	# but we need to attach our physical bone to the end of it
#	# so we will move transform location (origin point) down locally by given vector
#	body_transform.origin += body_transform.basis.xform(Vector3(0, 0, -half_height))
	
	var up = Vector3(0, 1, 0)
	if (up.cross(child_rest.origin).is_equal_approx(Vector3.ZERO)):
		up = Vector3(0, 0, 1)
		
	body_transform = body_transform.looking_at(child_rest.origin, up)
	body_transform.origin = body_transform.basis.xform(Vector3(0, 0, -half_height))
	
	var joint_transform: = Transform()
	joint_transform.origin = Vector3(0, 0, -half_height)

	var physical_bone = PhysicalBone.new()
	
	var bone_name:String = skeleton_ref.get_bone_name(bone_id)
	
	# Debug
	print("bone_name = "+ (bone_name as String) + " bone_id = " +  (bone_id as String))
	
	# Set Physical Bone Name
	physical_bone.name = get_physical_bone_name(skeleton_ref, bone_id)
	# connect physical bone to actual bone using it's name
	physical_bone.bone_name = bone_name
	
	# skip this node if it's already exists on parent container
	var existing_node = container.find_node(physical_bone.name, true)
	if existing_node != null:
		return existing_node
	
	# attach body to container
	container.add_child(physical_bone)
	physical_bone.set_owner(container.get_owner())
	
	# attach collision to generated physical bone
	physical_bone.add_child(collision)
	collision.set_owner(container.get_owner())
	
	# apply bone transform
	physical_bone.set_body_offset(body_transform)
	physical_bone.set_joint_offset(joint_transform)
	
	# load joint
	physical_bone.joint_type = PhysicalBone.JOINT_TYPE_6DOF
	# https://github.com/godotengine/godot/pull/44535
	#physical_bone.set("joint_constraints/damping", 0.1)
	#physical_bone.set("joint_constraints/impulse_clamp", 0.3)
	physical_bone.set("joint_constraints/angular_limit_upper", 30.0)
	physical_bone.set("joint_constraints/angular_limit_lower", -30.0)
	physical_bone.set("joint_constraints/angular_limit_relaxation", 0.1)
	physical_bone.set("joint_constraints/angular_limit_enabled", true)
	
	return physical_bone

# form physical bone name
static func get_physical_bone_name(skeleton_ref:Skeleton, bone_id:int)->String:
	return PBONE_PREFIX + skeleton_ref.get_bone_name(bone_id)
