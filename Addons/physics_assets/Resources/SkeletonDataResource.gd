extends Resource
tool
class_name SkeletonDataResource

# Armature Bones Data
export var data:Dictionary setget set_data
export var scale:Vector3 setget set_scale

func set_data(value: Dictionary):
	data = value
	emit_changed()

func set_scale(value: Vector3):
	scale = value
	emit_changed()
