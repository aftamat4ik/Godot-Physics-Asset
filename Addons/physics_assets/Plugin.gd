tool
extends EditorPlugin

var inspector_utility:EditorInspectorPlugin
var wiggle_gizmo:EditorSpatialGizmoPlugin

# Custom physical bone type
const phys_bone_type := "PhysicalBoneEx"
const phys_bone_ex_script:Script = preload("res://Addons/physics_assets/CustomTypes/PhysicalBoneEx.gd")
const phys_bone_ex_icon:Texture = preload("res://addons/physics_assets/Img/icon_bone_attachment.png")

const wiggle_bone_type := "WiggleBone"
const wiggle_bone_script:Script = preload("res://Addons/physics_assets/CustomTypes/WiggleBone.gd")
const wiggle_bone_icon:Texture = preload("res://Addons/physics_assets/Img/icon_wigglebone.svg")

const combined_skeleton_type := "CombinedSkeleton"
const combined_skeleton_script:Script = preload("res://Addons/physics_assets/CustomTypes/CombinedSkeleton.gd")
const combined_skeleton_icon:Texture = preload("res://Addons/physics_assets/Img/icon_skeleton.png")

const wiggle_gismo_script:Script = preload("res://Addons/physics_assets/WiggleGizmoPlugin.gd")
const inspector_plugin_script:Script = preload("res://Addons/physics_assets/UiInspectorPlugin.gd")


# Plugin name overload
func get_plugin_name():
	return "Physics Asset"

# On Plugin Activation
func _enter_tree():
	add_custom_type(phys_bone_type, "PhysicalBone", phys_bone_ex_script, phys_bone_ex_icon)
	add_custom_type(wiggle_bone_type, "BoneAttachment", wiggle_bone_script, wiggle_bone_icon)
	add_custom_type(combined_skeleton_type, "Skeleton", combined_skeleton_script, combined_skeleton_icon)
	if inspector_utility == null:
		# Register inspector_utility as Inspector plugin
		inspector_utility = inspector_plugin_script.new()
		add_inspector_plugin(inspector_utility)
		# Call Constructor
		inspector_utility.init(self)
	if wiggle_gizmo == null:
		wiggle_gizmo = wiggle_gismo_script.new()
		add_spatial_gizmo_plugin(wiggle_gizmo)

# On Plugin Deactivation
func _exit_tree():
	remove_custom_type(phys_bone_type)
	remove_custom_type(wiggle_bone_type)
	remove_custom_type(combined_skeleton_type)
	if inspector_utility != null:
		# Clear inspector_utility registration
		inspector_utility.clear_instance()
		remove_inspector_plugin(inspector_utility)
	if wiggle_gizmo != null:
		remove_spatial_gizmo_plugin(wiggle_gizmo)
