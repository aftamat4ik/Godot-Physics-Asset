tool
extends Spatial

func _enter_tree():
	
	# lock node
	set_meta("_edit_lock_", true)
	
	# unlock node
	#set_meta("_edit_lock_", null)

func _ready():
	# activate physics server on ready
	PhysicsServer.set_active(true)

func _exit_tree():
	# deactivate Physics Server on scene switch
	PhysicsServer.set_active(false)
