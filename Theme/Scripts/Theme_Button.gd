extends Button
tool

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var __theme_type : String = ""
var __themefont_type : String = ""
var __themefont_font : String = ""
var __themestyle_type : String = ""
var __themestyle_disabled : String = ""
var __themestyle_focus : String = ""
var __themestyle_hover : String = ""
var __themestyle_normal : String = ""
var __themestyle_pressed : String = ""


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _get(property : String):
	var value = null
	match property:
		"theme_type":
			value = __theme_type
		"theme_fonts/type":
			value = __themefont_type
		"theme_fonts/font":
			value = __themefont_font
		"theme_styles/type":
			value = __themestyle_type
		"theme_styles/disabled":
			value = __themestyle_disabled
		"theme_styles/focus":
			value = __themestyle_focus
		"theme_styles/hover":
			value = __themestyle_hover
		"theme_styles/normal":
			value = __themestyle_normal
		"theme_styles/pressed":
			value = __themestyle_pressed
	return value

func _set(property : String, value) -> bool:
	var success = true
	match property:
		"theme_type":
			if typeof(value) == TYPE_STRING:
				__theme_type = value
				_UpdateStyles()
				_UpdateFonts()
			else: success = false
		"theme_fonts/type":
			if typeof(value) == TYPE_STRING:
				__themefont_type = value
				_UpdateFonts()
			else: success = false
		"theme_fonts/font":
			if typeof(value) == TYPE_STRING:
				__themefont_font = value
				_UpdateFonts()
			else: success = false
		"theme_styles/type":
			if typeof(value) == TYPE_STRING:
				__themestyle_type = value
				_UpdateStyles()
			else: success = false
		"theme_styles/disabled":
			if typeof(value) == TYPE_STRING:
				__themestyle_disabled = value
				_UpdateStyles()
			else: success = false
		"theme_styles/focus":
			if typeof(value) == TYPE_STRING:
				__themestyle_focus = value
				_UpdateStyles()
			else: success = false
		"theme_styles/hover":
			if typeof(value) == TYPE_STRING:
				__themestyle_hover = value
				_UpdateStyles()
			else: success = false
		"theme_styles/normal":
			if typeof(value) == TYPE_STRING:
				__themestyle_normal = value
				_UpdateStyles()
			else: success = false
		"theme_styles/pressed":
			if typeof(value) == TYPE_STRING:
				__themestyle_pressed = value
				_UpdateStyles()
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
			name = "theme_fonts/type",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_fonts/font",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/type",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/disabled",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/focus",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/hover",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/normal",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_styles/pressed",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		}
	]

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


func _UpdateStyles():
	var type = __theme_type if __themestyle_type == "" else __themestyle_type
	_UpdateStylebox("disabled", type, __themestyle_disabled)
	_UpdateStylebox("focus", type, __themestyle_focus)
	_UpdateStylebox("hover", type, __themestyle_hover)
	_UpdateStylebox("normal", type, __themestyle_normal)
	_UpdateStylebox("pressed", type, __themestyle_pressed)


func _UpdateFonts():
	var type = __theme_type if __themefont_type == "" else __themefont_type
	var font : Font = null
	if type != "":
		if __themefont_font == "":
			font = get_font("font", type)
		else:
			font = get_font(__themefont_font, type)
	add_font_override("font", font)

