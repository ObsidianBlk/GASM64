extends PanelContainer
tool

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------
export var resource_type : String = ""	setget set_resource_type
export var stylebox_name : String = ""	setget set_stylebox_name

# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------
func set_stylebox_name(rn : String) -> void:
	stylebox_name = rn
	_UpdatePanel()

func set_resource_type(rt : String) -> void:
	resource_type = rt
	_UpdatePanel()

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	_UpdatePanel()

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _UpdatePanel() -> void:
	var sb : StyleBox = get_stylebox(stylebox_name, resource_type)
	print("Stylebox is: ", sb)
	add_stylebox_override("panel", sb)


