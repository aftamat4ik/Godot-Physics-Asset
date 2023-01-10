tool
extends FileDialog
class_name SaveFileDialog

# Refrence to owner-plugin
var _plugin:EditorPlugin

# Initialise
func init(plugin:EditorPlugin):
	_plugin = plugin
