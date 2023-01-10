tool
extends VBoxContainer

# Refrence to owner-plugin
var _plugin:EditorPlugin
var _inspector_plugin:EditorInspectorPlugin
var _editor_interface:EditorInterface
var _edited_scene_root:Node

const CONTAINER_NODE_NAME = "PhysicsTree"
const PBONE_PREFIX = "Pb_"
const RULES_META = "RulesMeta"
const BONE_ID_KEY = "bone_id"
const BONE_NAME_KEY = "bone_name"
const PARENT_BONE_ID_KEY = "parent_id"
const GENERATED_KEY = "generated_bone"

# select scene node dialog
onready var select_ui = preload("res://Addons/physics_assets/Ui/Controls/SelectSceneNodeDialog/SelectSceneNodeDialog.tscn").instance()

onready var btn_process_rules = get_node("%BtnProcessRules")
onready var btn_simulate_ragdoll = get_node("%BtnSimulateRagdoll")
onready var btn_generate_all = get_node("%BtnGenerateForAllBones")
onready var btn_read_pattern = get_node("%BtnReadPattern")
onready var btn_clear_generated = get_node("%BtnClearGenerated")
onready var btn_change_joint_type = get_node("%BtnChangeJointType")
onready var btn_select_physical_bones = get_node("%BtnSelectPhysicalBones")
onready var txt_shape_rules = get_node("%TxtShapeRules")
onready var hf_body_type = get_node("%HFBodyType")
onready var hf_shape_type = get_node("%HFShapeType")
onready var hf_joint_type = get_node("%HFJointType")
var simulate_ragdoll_text:String = "Simulate Ragdoll"
var stop_ragdoll_text:String = "Stop Ragdoll"
var is_ragdoll_sim := false

# Pseudo-Constructor
func init(plugin:EditorPlugin, inspector_plugin:EditorInspectorPlugin):
	_plugin = plugin
	_editor_interface = plugin.get_editor_interface()
	_edited_scene_root = _editor_interface.get_edited_scene_root()
	inspector_plugin = _inspector_plugin

func _ready():
	# in case if no init was called
	if not _plugin:
		printerr(PAErrors.ERR_INIT)
		return
	
	var selected_node := PAHelpers.get_selected_node(_plugin)
	# load saved rules from meta if any
	if selected_node.has_meta(RULES_META):
		txt_shape_rules.set_text(selected_node.get_meta(RULES_META))
	
	# save default text for simulate ragdoll button
	simulate_ragdoll_text = btn_simulate_ragdoll.text
	if selected_node.has_meta("simulation_on"):
		if selected_node.get_meta("simulation_on") == 1:
			btn_simulate_ragdoll.text = stop_ragdoll_text
		else:
			btn_simulate_ragdoll.text = simulate_ragdoll_text
	
	btn_process_rules.connect("pressed", self, "generate_by_rules")
	btn_simulate_ragdoll.connect("pressed", self, "sumulate_ragdoll")
	btn_generate_all.connect("pressed", self, "generate_all")
	btn_read_pattern.connect("pressed", self, "read_pattern")
	btn_clear_generated.connect("pressed", self, "clear_generated")
	btn_change_joint_type.connect("pressed", self, "change_joint_type")
	btn_select_physical_bones.connect("pressed", self, "select_physical_bones")
	txt_shape_rules.connect("text_changed", self, "save_rules")

# save rule list on change
func save_rules():
	# set text value as meta to currently edited node
	# meta fields are saved within scene node so this is true way of storing scene-related data
	var selected_node := PAHelpers.get_selected_node(_plugin)
	if selected_node != null:
		selected_node.set_meta(RULES_META, txt_shape_rules.text)

# generate collision shapes
func generate_by_rules():
	var selected_node := PAHelpers.get_selected_node(_plugin)
	btn_process_rules.disabled = true
	
	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return
	
	# cast selected node to Skeleton type
	var selected_skeleton = selected_node as Skeleton

	# get container node
	var container = get_clean_container(selected_node)
	var pbones = process_rules(selected_skeleton, container)
	save_rules()
	
	# force armature to re-scan it's child
	selected_node.set("scan_child", true)
	btn_process_rules.disabled = false

# clears generated nodes
func clear_generated():
	var selected_node := PAHelpers.get_selected_node(_plugin)
	
	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return

	# get container node
	var container = get_clean_container(selected_node)

# selects in scene tree all PhysicalBones
func select_physical_bones():
	if _plugin == null:
		return
	
	var selected_node := PAHelpers.get_selected_node(_plugin)
	# search  for all nodes of PhysicalBone type recursively
	var pbones = PAHelpers.find_child_list_of_class(selected_node, "PhysicalBone", "Skeleton")
	for pbone in pbones:
		PAHelpers.select_editor_node(_plugin, pbone)
	
	# don't forget to de-select current node
	PAHelpers.deselect_editor_node(_plugin, selected_node)

# generate collision shapes
func generate_all():
	var selected_node := PAHelpers.get_selected_node(_plugin)
	btn_generate_all.disabled = true
	
	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return
	
	# cast selected node to Skeleton type
	var skeleton_ref = selected_node as Skeleton

	# get container node
	var container = get_clean_container(selected_node)
	
	var body_type_selected:Node = get_checked(hf_body_type)
	var shape_type_selected:Node = get_checked(hf_shape_type)
	var shape = shape_type_selected.name.replace("CB","")
	var joint_type_selected:Node = get_checked(hf_joint_type)
	var joint_type = joint_type_selected.name.replace("CB","")
	
	# dictionary <int bone_id><PhysicalBone>
	var bones_list = {}
	#var cnt = 0
	for bone_id in range( skeleton_ref.get_bone_count() ):
		if body_type_selected.name == "CBPhysicalBone":
			var pbones:Dictionary = create_derived_physical_bones(skeleton_ref, bone_id, container, shape)
			if pbones.keys().size()  == 0:
				continue
			# set joint type for each bone
			for pbone_id in pbones.keys():
				var value = pbones[pbone_id]
				match joint_type:
					"6DOF":
						value.joint_type = PhysicalBone.JOINT_TYPE_6DOF
					"Hinge":
						value.joint_type = PhysicalBone.JOINT_TYPE_HINGE
					"Pin":
						value.joint_type = PhysicalBone.JOINT_TYPE_PIN
					"Cone":
						value.joint_type = PhysicalBone.JOINT_TYPE_CONE
					_:
						value.joint_type = PhysicalBone.JOINT_TYPE_NONE
			bones_list.merge(pbones,true)
		elif body_type_selected.name == "CBRigidBody":
			var pbones:Dictionary = create_derived_rigid_bodys(skeleton_ref, bone_id, container, shape)
			bones_list.merge(pbones,true)
		elif body_type_selected.name == "CBWiggleBoneD":
			var pbone = create_wiggle_bone(skeleton_ref, bone_id, WiggleProperties.Mode.DISLOCATION)
			bones_list[bone_id] = pbone
		elif body_type_selected.name == "CBWiggleBoneR":
			var pbone = create_wiggle_bone(skeleton_ref, bone_id, WiggleProperties.Mode.ROTATION)
			bones_list[bone_id] = pbone
		
		# limit for debug
#		cnt += 1
#		if cnt > 10:
#			return bones_list
	
	# add rigid body joints if user generated any rigid bodies
	for bone_id in range( skeleton_ref.get_bone_count() ):
		create_rigid_joint(skeleton_ref, container, bone_id, joint_type)
	
	# force armature to re-scan it's child
	selected_node.set("scan_child", true)
	btn_generate_all.disabled = false

# changes joint type on all physical bone and joints to selected type
func change_joint_type():
	var selected_node := PAHelpers.get_selected_node(_plugin)
	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return
	
	var skeleton_ref = selected_node as Skeleton
	# get list of PhysicalBones
	var pbones = PAHelpers.find_child_list_of_class(skeleton_ref, "PhysicalBone", "Skeleton")
	
	var joint_type_selected:Node = get_checked(hf_joint_type)
	var joint_type = joint_type_selected.name.replace("CB","")
	
	# apply to Physical Bones
	for pbone in pbones:
		var pbone_casted = pbone as PhysicalBone
		match joint_type:
			"6DOF":
				pbone_casted.joint_type = PhysicalBone.JOINT_TYPE_6DOF
			"Hinge":
				pbone_casted.joint_type = PhysicalBone.JOINT_TYPE_HINGE
			"Pin":
				pbone_casted.joint_type = PhysicalBone.JOINT_TYPE_PIN
			"Cone":
				pbone_casted.joint_type = PhysicalBone.JOINT_TYPE_CONE
			_:
				pbone_casted.joint_type = PhysicalBone.JOINT_TYPE_NONE
	
	# apply to RigidBody Joints
	var container = find_container(skeleton_ref)
	if container != null:
		var joints = PAHelpers.find_child_list_of_class(skeleton_ref, "Joint", "Skeleton")
		
		# get rid of existing rigid body joints
		for joint_single in joints:
			if joint_single.is_class("Joint"):
				container.remove_child(joint_single)
				joint_single.free()
			
		# re-generate rigid body joints
		for bone_id in range( skeleton_ref.get_bone_count() ):
			create_rigid_joint(skeleton_ref, container, bone_id, joint_type)
		

# reads current bones setup from armature
func read_pattern():
	var selected_node := PAHelpers.get_selected_node(_plugin)
	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return
	# cast to type
	var skeleton = selected_node as Skeleton
	# first get nodes in container
	# there will be rigid bodies and physicalbones with theuir collisions and joints
	var container = find_container(skeleton)
	
	# here will be our rules list
	var rules_list = ""
	
	if container != null:
		var child_nodes = PAHelpers.collect_children(container, "Skeleton")
		
		for node in child_nodes:
			var rule = ""
			# format of the rule is:
			#spine_01 PhysicalBone Capsule Pin
			
			# skip all except PhysicsBody's implementations
			if not node.is_class("PhysicsBody"):
				continue
			
			if node.is_class("PhysicalBone"):
				var pb = node as PhysicalBone
				rule += pb.bone_name
				rule += " PhysicalBone"
				rule += " " + get_collision_shape_type(pb)
				rule += " " + get_pb_joint_type(pb)
			elif node.is_class("RigidBody"):
				var rb = node as RigidBody
				# since rigid bodies nor connected to any bones - i decided to store bone info of body in meta keys
				# so we look for bone name in meta if any
				if rb.has_meta(BONE_NAME_KEY):
					rule += restore_bone_name(rb.get_meta(BONE_NAME_KEY))
				else:
					rule += restore_bone_name(rb.name)
				# rigid body type
				rule += " RigidBody"
				rule += " " + get_collision_shape_type(rb)
				
				# detect joint type by parsing list of existing joints and checking their connections
				var joints = PAHelpers.find_child_list_of_class(container, "Joint", "Skeleton")
				for joint in joints:
					var casted_joint = joint as Joint
					# take joint's node_a and try to match it with currently processing body
					# if  they match - set joint type
					if rb == joint.get_node_or_null(joint.get("nodes/node_a")):
						rule += " " + get_adapted_joint_type(joint)
			if rule != "":
				rules_list += rule + "\n"
	# second look for wiggle bones in ther root of skeleton
	var attachments = PAHelpers.find_child_list_of_class(skeleton, "BoneAttachment", "Skeleton")
	for att in attachments:
		if att.has_meta("mode"):
			var rule = att.bone_name
			var mode = att.properties.mode
			if mode == WiggleProperties.Mode.DISLOCATION:
				rule += " WiggleDislocation"
			else:
				rule += " WiggleRotation"
			rules_list += rule + "\n"
	var dlg
	
	# in case if no rules
	if rules_list == "":
		printerr(PAErrors.ERR_NO_RULES)
		# show error message
		dlg = AcceptDialog.new()
		dlg.dialog_text = "Script can't form rules for given skeleton."
		dlg.window_title = "No Rules Formed"
	else:
		# show confirmation before loading, because previous rules will be removed
		dlg = ConfirmationDialog.new()
		dlg.dialog_text = "Rules collected succesfully. Load them? Warning: previous rules will be removed!"
		dlg.window_title = "Load Rules?"
		dlg.connect("confirmed", self, "load_rules_confirmed", [rules_list])
	# attach dialog to the editor viewport
	var root = _plugin.get_editor_interface().get_editor_viewport()
	# if not initialised yet or in case of queue_free is called
	if not root.is_a_parent_of(dlg):
		# add dialog to scene
		root.add_child(dlg)
		dlg.set_owner(root.get_owner())
	dlg.popup_centered()
	
	print(rules_list)
	
	# wait til closed and then free
	yield(dlg,"popup_hide")
	dlg.queue_free()

# on confirmation - load rules into text editor
func load_rules_confirmed(rules:String):
	txt_shape_rules.text = rules

# returns first found body collision shape
func find_body_collision_shape(body:PhysicsBody)->CollisionShape:
	var child_list = PAHelpers.collect_children(body, "Skeleton")
	for node in child_list:
		if node.is_class("CollisionShape"):
			return node as CollisionShape
	return null

# adapts shape type to rules list string types
func get_collision_shape_type(for_body:PhysicsBody)->String:
	var col_shape = find_body_collision_shape(for_body)
	if col_shape == null:
		return "None"
	if col_shape.shape.is_class("BoxShape"):
		return "Box"
	elif col_shape.shape.is_class("SphereShape"):
		return "Sphere"
	elif col_shape.shape.is_class("CapsuleShape"):
		return "Capsule"
	return "None"

# adapts shape type to rules list string types
func get_adapted_joint_type(j:Joint):
	if j == null:
		return "None"
	
	if j is HingeJoint:
		return "Hinge"
	elif j is Generic6DOFJoint:
		return "6DOF"
	elif j is PinJoint:
		return "Pin"
	elif j is ConeTwistJoint:
		return "Cone"
	return "None"

# returns physics body joint type
func get_pb_joint_type(body:PhysicsBody):
	var key = body.joint_type
	match(key):
		PhysicalBone.JOINT_TYPE_6DOF:
			return "6DOF"
		PhysicalBone.JOINT_TYPE_HINGE:
			return "Hinge"
		PhysicalBone.JOINT_TYPE_PIN:
			return "Pin"
		PhysicalBone.JOINT_TYPE_CONE:
			return "Cone"
	return "None"

# generation of physical bone
func process_rules(skeleton_ref:Skeleton, container:Node)->Dictionary:
	var rules = txt_shape_rules.text
	# dictionary <int bone_id><PhysicalBone>
	var bones_list = {}
	
	# rules format: BName AttachmentClass ShapeType JointType
	for rule in rules.split("\n", false):
		var parts: PoolStringArray = rule.split(" ", false)
		var size = parts.size()
		# check parts count
		if size < 2 or size > 4:
			printerr("Rule " + rule + " in wrong format!" )
			continue
		var bone_name:String = parts[0]
		var attachment_class:String = parts[1]
		var shape_type:String = "Capsule" if parts.size() < 3 else parts[2]
		# joint is optional
		var joint_type:String = "None" if parts.size() < 4 else parts[3]
		# mark current bone as parent because shapes should be generated from child to parent
		# generation from parent to child donse't supported. I tryed but this is all what i could.
		var bone_id = skeleton_ref.find_bone(bone_name)
		
		# if not found
		if bone_id == -1:
			continue
		
		# physical bone generation
		if attachment_class == "PhysicalBone":
			var pbones:Dictionary = create_derived_physical_bones(skeleton_ref, bone_id, container, shape_type)
			if pbones.keys().size()  == 0:
				continue
			# set joint type for each bone
			for pbone_id in pbones.keys():
				var value = pbones[pbone_id]
				match joint_type:
					"6DOF":
						value.joint_type = PhysicalBone.JOINT_TYPE_6DOF
					"Hinge":
						value.joint_type = PhysicalBone.JOINT_TYPE_HINGE
					"Pin":
						value.joint_type = PhysicalBone.JOINT_TYPE_PIN
					"Cone":
						value.joint_type = PhysicalBone.JOINT_TYPE_CONE
					_:
						value.joint_type = PhysicalBone.JOINT_TYPE_NONE
			bones_list.merge(pbones,true)
		# rigid body
		elif attachment_class == "RigidBody":
			var pbones = create_derived_rigid_bodys(skeleton_ref, bone_id, container, shape_type)
			# this will generate joint for body if possible
			create_rigid_joint(skeleton_ref, container, bone_id, joint_type)
			bones_list.merge(pbones,true)
		# wiggle bone
		elif attachment_class.find("Wiggle") != -1:
			var mode = WiggleProperties.Mode.ROTATION if attachment_class == "WiggleRotation" else WiggleProperties.Mode.DISLOCATION
			var pbone = create_wiggle_bone(skeleton_ref, bone_id, mode)
			bones_list[bone_id] = pbone
		
	return bones_list

# finds first child bone from current id
# since somehow Skeleton class donsen't have this method. We have only get_bone_parent
func get_child_bone_id(for_bone_id:int, skeleton_ref:Skeleton):
	if for_bone_id == -1 or for_bone_id >= skeleton_ref.get_bone_count():
		return -1
	for bone_id in range( skeleton_ref.get_bone_count() ):
		var parent_id = skeleton_ref.get_bone_parent(bone_id)
		if parent_id == for_bone_id:
			return bone_id
	return -1

# returns array of child bones
func find_all_child_bones(skeleton_ref:Skeleton, bone_id:int)->Array:
	var ids:Array = []
	for id in range( skeleton_ref.get_bone_count() ):
		if skeleton_ref.get_bone_parent(id) == bone_id:
			ids.append(id)
	return ids

# creates physical bone + collision shape for given bone_id and it's closest childs
func create_derived_physical_bones(skeleton_ref:Skeleton, bone_id:int, container:Node, shape_type:String = "Capsule")->Dictionary:
	var bones_list:Dictionary = {}
	
	# if bone donse't exist or out of bounds
	if bone_id == -1 or bone_id >= skeleton_ref.get_bone_count():
		return bones_list
	
	var childs := find_all_child_bones(skeleton_ref, bone_id)
	# since parent bone connected to current bone_id as well
	# so it's derived from it - we add parent in list to process
	var parent_id = skeleton_ref.get_bone_parent(bone_id)
	if parent_id != -1:
		childs.append(parent_id)
	else:
		childs.append(bone_id)
	childs.sort()
	for child_id in childs:
		if child_id == -1:
			continue
		
		var bone_rest:Transform = skeleton_ref.get_bone_rest(bone_id)
		var child_rest:Transform = skeleton_ref.get_bone_rest(child_id)
		
		var bone_pose:Transform = skeleton_ref.get_bone_global_pose(bone_id)
		var child_pose:Transform = skeleton_ref.get_bone_global_pose(child_id)
		
		var half_height = (bone_pose.origin - child_pose.origin).length() * 0.5
		var radius = half_height * 0.3

		var collision = CollisionShape.new()
		# select collision shape
		var shape:Shape
		if shape_type != "None":
			if shape_type == "Sphere":
				shape = SphereShape.new()
				shape.set_radius(half_height/2)
			elif shape_type == "Box":
				shape = BoxShape.new()
				shape.extents = Vector3(half_height/2, half_height/2, half_height/2)
			else: # default is capsule shape
				shape = CapsuleShape.new()
				shape.set_height((half_height - radius) * 2)
				shape.set_radius(radius)
			collision.shape = shape
		
		var body_transform:= Transform()
		
		var up = Vector3(0, 1, 0)
		if (up.cross(bone_rest.origin).is_equal_approx(Vector3.ZERO)):
			up = Vector3(0, 0, 1)
		
		# we will look from child bone to current bone and apply looking direction
		var look_to_origin = skeleton_ref.get_bone_global_pose(child_id).origin
		body_transform.origin = skeleton_ref.get_bone_global_pose(bone_id).origin
		if look_to_origin != Vector3.ZERO:
			body_transform = body_transform.looking_at(look_to_origin, up)
		# by default bone transform given in the middle of bone
		# but we need to attach our physical bone to the end of it
		# so we will move transform location (origin point) down locally by given vector
		body_transform.origin += body_transform.basis.xform(Vector3(0, 0, -half_height))
		body_transform = body_transform.scaled(skeleton_ref.get_scale())
		# att skeleton origin to generated body transform 
		# or it will always spawn at the world origin since get_bone_global_pose dosen't include skeleton transform
		body_transform.origin += skeleton_ref.global_transform.origin
		# set joint transform
		var joint_transform: = Transform()
		#joint_transform.origin = joint_transform.basis.xform(Vector3(0, 0, -half_height))
		joint_transform.origin = Vector3(0, 0, -half_height)
		
		var physical_bone = PhysicalBone.new()
		# attach to bone
		var bone_name:String = skeleton_ref.get_bone_name(child_id)
		#var bone_name:String = skeleton_ref.get_bone_name(bone_id)
		
		# Set Physical Bone Name
		physical_bone.name = get_fixed_bone_name(skeleton_ref, child_id)
		
		# connect physical bone to actual bone using it's name
		physical_bone.bone_name = bone_name
		# mark as Generated using meta field
		physical_bone.set_meta(GENERATED_KEY, 1)
		physical_bone.set_meta(BONE_NAME_KEY, bone_name)
		physical_bone.set_meta(BONE_ID_KEY, child_id)
		
		# skip this node if it's already exists on parent container
		#var existing_node = container.find_node(physical_bone.name, true)
		var existing_node = container.get_node_or_null(physical_bone.name)
		if existing_node != null:
			bones_list[child_id] = existing_node
			continue
		
		# attach body to container
		container.add_child(physical_bone)
		physical_bone.set_owner(_edited_scene_root)
		
		# attach collision to generated physical bone
		physical_bone.add_child(collision)
		collision.set_owner(_edited_scene_root)
		
		# apply bone transform
		#physical_bone.set_joint_offset(joint_transform)
		physical_bone.global_transform = body_transform
		
		bones_list[child_id] = physical_bone
	
	return bones_list


# creates rigid body + collision shape for given bone_id's parent
func create_derived_rigid_bodys(skeleton_ref:Skeleton, bone_id:int,container:Node, shape_type="Capsule")->Dictionary:
	var body_list:Dictionary = {}
	# if bone donse't exist or out of bounds
	if bone_id == -1 or bone_id >= skeleton_ref.get_bone_count():
		return body_list
	
	var childs = find_all_child_bones(skeleton_ref, bone_id)
	# since parent bone connected to current bone_id as well
	# so it's derived from it - we add parent in list to process
	for child_id in childs:
		if child_id == -1:
			continue
		
		var bone_rest:Transform = skeleton_ref.get_bone_rest(bone_id)
		var child_rest:Transform = skeleton_ref.get_bone_rest(child_id)
		
		var bone_pose:Transform = skeleton_ref.get_bone_global_pose(bone_id)
		var child_pose:Transform = skeleton_ref.get_bone_global_pose(child_id)
		
		var half_height = (bone_pose.origin - child_pose.origin).length() * 0.5
		var radius = half_height * 0.3
		
		# initialise collision
		var collision = CollisionShape.new()
		var shape:Shape
		if shape_type != "None":
			if shape_type == "Sphere":
				shape = SphereShape.new()
				shape.set_radius(half_height/2)
			elif shape_type == "Box":
				shape = BoxShape.new()
				shape.extents = Vector3(half_height/2, half_height/2, half_height/2)
			else: # default is capsule shape
				shape = CapsuleShape.new()
				shape.set_height((half_height - radius) * 2)
				shape.set_radius(radius)
			collision.shape = shape
		
		var body_transform:= Transform()
		# we will look from child bone to current bone and apply looking direction
		var look_to_origin = skeleton_ref.get_bone_global_pose(child_id).origin
		body_transform.origin = skeleton_ref.get_bone_global_pose(bone_id).origin
		body_transform = body_transform.looking_at(look_to_origin, Vector3.UP)
		# by default bone transform given in the middle of bone
		# but we need to attach our physical bone to the end of it
		# so we will move transform location (origin point) down locally by given vector
		body_transform.origin += body_transform.basis.xform(Vector3(0, 0, -half_height))
		body_transform = body_transform.scaled(skeleton_ref.get_scale())
		# att skeleton origin to generated body transform 
		# or it will always spawn at the world origin since get_bone_global_pose dosen't include skeleton transform
		body_transform.origin += skeleton_ref.global_transform.origin
		
		var up = Vector3(0, 1, 0)
		if (up.cross(bone_rest.origin).is_equal_approx(Vector3.ZERO)):
			up = Vector3(0, 0, 1)
		
		var rigid_body := RigidBody.new()
		# set rigid body default mode to static - we need to prevent ragdoll from similation
		# set mode to rigid on each body to simulate
		rigid_body.mode = RigidBody.MODE_STATIC
		# save bone name as meta
		var bone_name:String = skeleton_ref.get_bone_name(child_id)
		rigid_body.set_meta(BONE_NAME_KEY, bone_name)
		rigid_body.set_meta(BONE_ID_KEY, child_id)
		# mark as Generated using meta fields
		rigid_body.set_meta(GENERATED_KEY, 1)
		
		# Set Body Name
		rigid_body.name = get_fixed_bone_name(skeleton_ref, child_id)
		
		# skip this node if it's already exists on parent container
		var existing_node = container.find_node(rigid_body.name, true)
		if existing_node != null:
			body_list[child_id] = existing_node
			continue
		
		# attach body to container
		container.add_child(rigid_body)
		rigid_body.set_owner(_edited_scene_root)
		
		# attach collision to generated physical bone
		rigid_body.add_child(collision)
		collision.set_owner(_edited_scene_root)
		
		rigid_body.global_transform = body_transform
		body_list[child_id] = rigid_body
	return body_list

# since rigid bodies dosen't have joints on them - this function generates it
func create_rigid_joint(skeleton_ref:Skeleton, container:Node, bone_id:int, joint_type:String = "6DOF"):
	var parent_id:int = skeleton_ref.get_bone_parent(bone_id)
	# no joint in case if no parent because joint requires two bodies on it
	if parent_id == -1:
		return
	
	var body_a_name = get_fixed_bone_name(skeleton_ref, bone_id)
	var body_b_name = get_fixed_bone_name(skeleton_ref, parent_id)
	var body_a = container.get_node_or_null(body_a_name)
	var body_b = container.get_node_or_null(body_b_name)
	
	# we can connect with joints only rigid bodies
	if body_a == null or body_b == null or not body_a.is_class("RigidBody") or not body_b.is_class("RigidBody"):
		return
	
	# select and initialise joint type
	var joint:Joint
	match joint_type:
		"6DOF":
			joint = Generic6DOFJoint.new()
		"Hinge":
			joint = HingeJoint.new()
		"Pin":
			joint = PinJoint.new()
		"Cone":
			joint = ConeTwistJoint.new()
		_:
			# if joint is "None" or any other value - just return
			return
	
	# copy joint transform from bone
	joint.transform = skeleton_ref.get_bone_global_pose(bone_id)
	joint.name = "j_" + skeleton_ref.get_bone_name(bone_id) + "_" + skeleton_ref.get_bone_name(parent_id)
	# set joint name as meta fields to rigid bodies that connected by it
	body_a.set_meta("joint_body_a", joint.name)
	body_b.set_meta("joint_body_b", joint.name)
	
	# First add joint to scene
	# attach joint to container
	container.add_child(joint)
	joint.set_owner(_edited_scene_root)
	
	# Then set it's node paths
	# order matters!
	joint.set("nodes/node_a", joint.get_path_to(body_a) )
	joint.set("nodes/node_b", joint.get_path_to(body_b) )
	
	# set meta fields of joint to store bone_id 
	# since by default joints are not connected to the skeleton
	# we'll be able to get this data once needed
	joint.set_meta(BONE_ID_KEY, bone_id)
	joint.set_meta(PARENT_BONE_ID_KEY, parent_id)
	# mark as Generated using meta fields
	joint.set_meta(GENERATED_KEY, 1)

# wiggle bone generation
func create_wiggle_bone(skeleton_ref:Skeleton, bone_id:int, mode = WiggleProperties.Mode.ROTATION)->WiggleBone:
	
	if bone_id == -1:
		return null
	
	var wiggle_bone = WiggleBone.new()
	
	# load properties
	var wiggle_properties
	
	# select resource with settings depending on mode
	match mode:
		WiggleProperties.Mode.ROTATION:
			wiggle_properties = preload("res://Addons/physics_assets/Resources/Wiggle Data/Rotation.tres")
		WiggleProperties.Mode.DISLOCATION:
			wiggle_properties = preload("res://Addons/physics_assets/Resources/Wiggle Data/Dislocation.tres")
	wiggle_bone.properties = wiggle_properties
	#wiggle_bone.enabled = false
	
	# node name
	wiggle_bone.name = get_fixed_bone_name(skeleton_ref, bone_id)
	# mark this bone as generagted using meta fields
	# we need to do so to re-generate bones and keep user created bones in the same time
	wiggle_bone.set_meta(GENERATED_KEY, 1)
	# attach to skeleton
	# note: WiggleBone class is inherited from BoneAttachment class
	# BoneAttachment class requires to be attached as first-level child to skeleton
	# so ve can't put any of the WiggleBones in container, unfortunately
	skeleton_ref.add_child(wiggle_bone)
	wiggle_bone.set_owner(_edited_scene_root)
	
	# WiggleBone dosen't need to be attached manually
	# just set bone name
	wiggle_bone.bone_name = skeleton_ref.get_bone_name(bone_id)
	
	wiggle_bone.set_meta(BONE_NAME_KEY, wiggle_bone.bone_name)
	wiggle_bone.set_meta(BONE_ID_KEY, bone_id)
	# mark as Generated using meta fields
	wiggle_bone.set_meta(GENERATED_KEY, 1)
	
	return wiggle_bone

# organise bones in tree form
func organise_physical_bones(skeleton_ref:Skeleton, bones_list:Dictionary, container:Node)->Dictionary:
	for bone_id in range( skeleton_ref.get_bone_count() ):
		if bone_id == -1:
			continue
		
		var parent = skeleton_ref.get_bone_parent(bone_id)
		if parent != -1 and bones_list.has(parent):
			bones_list[bone_id] = PAHelpers.reparent_node(bones_list[bone_id],bones_list[parent])
		
	return bones_list

# form physical bone name by encoding special symbols
func get_fixed_bone_name(skeleton_ref:Skeleton, bone_id:int)->String:
	var src = skeleton_ref.get_bone_name(bone_id)
	# this symbols can't be in node name so we should replace them with placeholders
	src = src.replace(".", "-dot-")
	src = src.replace(":", "-2dot-")
	src = src.replace("@", "-dog-")
	src = src.replace("@", "-slash-")
	src = src.replace("\"", "-query-")
	src = src.replace("'", "-squery-")
	src = src.replace("%", "-percent-")
	return PBONE_PREFIX + src

# restore bone name from encoded
func restore_bone_name(src:String)->String:
	src = src.trim_prefix(PBONE_PREFIX)
	src = src.replace("-dot-", ".")
	src = src.replace("-2dot-", ":")
	src = src.replace("-dog-", "@")
	src = src.replace("-slash-", "@")
	src = src.replace("-query-", "\"")
	src = src.replace("-squery-", "'")
	src = src.replace("-percent-", "%")
	
	return src

# searches for generated elements container node
func find_container(in_node:Node)->Node:
	return in_node.get_node_or_null(CONTAINER_NODE_NAME)

# in this node will be all physics asset related ubnodes
func get_clean_container(in_node:Node)->Node:
	# get rid of old node (that also will remove all it's subnodes)
	var old_node = find_container(in_node)
	if old_node != null:
		in_node.remove_child(old_node)
		old_node.queue_free()
	
	# get rid of existing Generated Bodies
	var child_list = PAHelpers.collect_children(in_node, "Skeleton")
	for child in child_list:
		var subnode = child as Node
		if subnode.has_meta(GENERATED_KEY):
			in_node.remove_child(subnode)
			subnode.queue_free()
	
	# create new container
	var container = Spatial.new()
	# define core node name
	container.set_name(CONTAINER_NODE_NAME)
	# add node to list
	in_node.add_child(container)
	container.set_owner(_edited_scene_root)
	return container

# gets checked buttons inside FlowContainer
func get_checked(on_container:HFlowContainer)->Node:
	var child_list = on_container.get_children()
	for child in child_list:
		if child.pressed:
			return child
	return null

# apply ragdoll
func sumulate_ragdoll():
	var selected_node := PAHelpers.get_selected_node(_plugin)

	if not selected_node is Skeleton:
		printerr(PAErrors.ERR_NOT_SELECTED_SKELETON)
		return
	if selected_node.has_meta("simulation_on"):
		is_ragdoll_sim = true if selected_node.get_meta("simulation_on") == 1 else 0
	
	var skeleton_ref = selected_node as Skeleton
	PhysicsServer.set_active(not is_ragdoll_sim)
	# toggle physics simulation
	if is_ragdoll_sim == false:
		btn_simulate_ragdoll.text = stop_ragdoll_text
		skeleton_ref.physical_bones_start_simulation()
		is_ragdoll_sim = true
	else:
		btn_simulate_ragdoll.text = simulate_ragdoll_text
		skeleton_ref.physical_bones_stop_simulation()
		is_ragdoll_sim = false
