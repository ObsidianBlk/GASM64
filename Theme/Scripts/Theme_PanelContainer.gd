extends PanelContainer
tool

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var __theme_type : String = ""
var __themestyle_type : String = ""
var __themestyle_panel : String = ""


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	_UpdatePanel()

func _get(property : String):
	var value = null
	match property:
		"theme_type":
			value = __theme_type
		"theme_styles/type":
			value = __themestyle_type
		"theme_styles/panel":
			value = __themestyle_panel
	return value

func _set(property : String, value) -> bool:
	var success = true
	match property:
		"theme_type":
			if typeof(value) == TYPE_STRING:
				__theme_type = value
				_UpdatePanel()
			else: success = false
		"theme_styles/type":
			if typeof(value) == TYPE_STRING:
				__themestyle_type = value
				_UpdatePanel()
			else: success = false
		"theme_styles/panel":
			if typeof(value) == TYPE_STRING:
				__themestyle_panel = value
				_UpdatePanel()
			else: success = false
		_:
			success = false
	
	if success:
		property_list_changed_notify()
	return success

func _get_property_list() -> Array:
	return [
		{
			name = "Theming",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "theme_type",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/type",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/panel",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		}
	]

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _UpdatePanel() -> void:
	var sb : StyleBox = null
	var type = __theme_type if __themestyle_type == "" else __themestyle_type
	if type != "":
		if __themestyle_panel == "":
			sb = get_stylebox("panel", type)
		else:
			sb = get_stylebox(__themestyle_panel, type)
	add_stylebox_override("panel", sb)


