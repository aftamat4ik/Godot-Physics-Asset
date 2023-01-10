tool
extends PhysicalBone
class_name PhysicalBoneEx, "res://addons/physics_assets/Img/icon_bone_attachment.png"

# Main Reason Why i created extended physical bone class is this:
# Default Physical Bones dosen't follow bone positions in-editor during animation
# So i decided to fix that in here
# It looks simple and short to you, yes?
# I WASTED TWO DAYS for IT. 
# There is no info about this in the internet. Was no info in 22.11.2022 when this is created.
# So i had to read sources of physics_body.cpp myself and only then came to underestanding

func _process(delta):
	# we don't need to apply follow logick during gameplay or ragdoll testing
	if Engine.editor_hint and not is_simulating_physics():
		follow_skeletal_bone()

# this will force bone to follow it's rig
func follow_skeletal_bone():
	# force PhysicalBone to maintain initial offset
	self.set_body_offset(get_body_offset())
