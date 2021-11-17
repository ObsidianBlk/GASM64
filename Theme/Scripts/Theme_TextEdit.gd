extends TextEdit
tool


var __theme_type : String = ""
var __themestyle_type : String = ""
var __themestyle_read_only : String = ""
var __themestyle_focus : String = ""
var __themestyle_normal : String = ""
var __themestyle_completion : String = ""

# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------
func set_themestyle_type(type : String) -> void:
	__themestyle_type = type
	_UpdateThemeStyles()

func set_themestyle_read_only(style : String) -> void:
	__themestyle_read_only = style
	_UpdateThemeStyles()

func set_themestyle_focus(style : String) -> void:
	__themestyle_focus = style
	_UpdateThemeStyles()

func set_themestyle_normal(style : String) -> void:
	__themestyle_normal = style
	_UpdateThemeStyles()

func set_themestyle_completion(style : String) -> void:
	__themestyle_completion = style
	_UpdateThemeStyles()

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	_UpdateThemeStyles()

func _get(property : String):
	var value = null
	match property:
		"theme_type":
			value = __theme_type
		"theme_styles/type":
			value = __themestyle_type
		"theme_styles/read_only":
			value = __themestyle_read_only
		"theme_styles/focus":
			value = __themestyle_focus
		"theme_styles/normal":
			value = __themestyle_normal
		"theme_styles/completion":
			value = __themestyle_completion
	return value

func _set(property : String, value) -> bool:
	var success = true
	match property:
		"theme_type":
			if typeof(value) == TYPE_STRING:
				__theme_type = value
				_UpdateThemeStyles()
			else: success = false
		"theme_styles/type":
			if typeof(value) == TYPE_STRING:
				__themestyle_type = value
				_UpdateThemeStyles()
			else: success = false
		"theme_styles/read_only":
			if typeof(value) == TYPE_STRING:
				__themestyle_read_only = value
				_UpdateThemeStyles()
			else: success = false
		"theme_styles/focus":
			if typeof(value) == TYPE_STRING:
				__themestyle_focus = value
				_UpdateThemeStyles()
			else: success = false
		"theme_styles/normal":
			if typeof(value) == TYPE_STRING:
				__themestyle_normal = value
				_UpdateThemeStyles()
			else: success = false
		"theme_styles/completion":
			if typeof(value) == TYPE_STRING:
				__themestyle_completion = value
				_UpdateThemeStyles()
			else: success = false
		_:
			success = false
	if success:
		property_list_changed_notify()
	return success


func _get_property_list():
	var properties = [
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
			name = "theme_styles/read_only",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/focus",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/normal",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/completion",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		}
	
	]
	return properties

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _UpdateStylebox(override_name : String, sb_type : String, sb_name : String) -> void:
	var style : StyleBox = null
	if sb_type != "":
		if sb_name == "":
			style = get_stylebox(override_name, sb_type)
		else:
			style = get_stylebox(sb_name, sb_type)
	add_stylebox_override(override_name, style)

func _UpdateThemeStyles() -> void:
	var type = __theme_type if __themestyle_type == "" else __themestyle_type
	_UpdateStylebox("read_only", type, __themestyle_read_only)
	_UpdateStylebox("focus", type, __themestyle_focus)
	_UpdateStylebox("normal", type, __themestyle_normal)
	_UpdateStylebox("completion", type, __themestyle_completion)




