extends Control

# -------------------------------------------------------------------------
# Consts and Signals
# -------------------------------------------------------------------------
signal selected(source_name, source_type)

const UNSELECT_COLOR = Color(1,1,1,0)

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------
var __theme_style_normal : StyleBox = null
var __theme_style_selected : StyleBox = null
var __theme_color_normal : Color = Color(0,0,0,1)
var __theme_color_normal_used : bool = false
var __theme_color_selected : Color = Color(0,0,0,1)
var __theme_color_selected_used : bool = false

var __selected : bool = false
var __source_type : int = -1

# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var label_node : Label = get_node("Control/LBL/Label")
onready var icon_node : TextureRect = get_node("Control/LBL/Icon")

# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	set_process_input(false)
	
	if has_icon("file", "EditorIcons"):
		var ico = get_icon("file", "EditorIcons")
		icon_node.texture = ico
	
	if not Engine.editor_hint:
		connect("mouse_entered", self, "_on_mouse_entered")
		connect("mouse_exited", self, "_on_mouse_exited")

func _input(event) -> void:
	if event is InputEventMouseButton:
		select()
		emit_signal("selected", label_node.text, __source_type)

func _get(property : String):
	match property:
		"source_name":
			return label_node.text
		"source_type":
			return __source_type
		"selected":
			return __selected
		"theme_overrides/styles/normal":
			return __theme_style_normal
		"theme_overrides/styles/selected":
			return __theme_style_selected
		"theme_overrides/colors/font_color_normal":
			return __theme_color_normal
		"theme_overrides/colors/font_color_selected":
			return __theme_color_selected
		"theme_overrides/colors/use_font_color_normal":
			return __theme_color_normal_used
		"theme_overrides/colors/use_font_color_selected":
			return __theme_color_selected_used
	return null

func _set(property : String, value) -> bool:
	var success = true
	match property:
		"source_name":
			if typeof(value) == TYPE_STRING:
				label_node.text = value
			else : success = false
		"source_type":
			if typeof(value) == TYPE_INT:
				if GASM_Project.RESOURCE_TYPE.values().find(value) >= 0:
					__source_type = value
				else : success = false
			else : success = false
		"selected":
			if typeof(value) == TYPE_BOOL:
				select(value)
			else : success = false
		"theme_overrides/styles/normal":
			if value is StyleBox:
				__theme_style_normal = value
				_UpdateLabelTheme()
			else : success = false
		"theme_overrides/styles/selected":
			if value is StyleBox:
				__theme_style_selected = value
				_UpdateLabelTheme()
			else : success = false
		"theme_overrides/colors/font_color_normal":
			if typeof(value) == TYPE_COLOR:
				__theme_color_normal = value
				_UpdateLabelTheme()
			else : success = false
		"theme_overrides/colors/font_color_selected":
			if typeof(value) == TYPE_COLOR:
				__theme_color_selected = value
				_UpdateLabelTheme()
			else : success = false
		"theme_overrides/colors/use_font_color_normal":
			if typeof(value) == TYPE_BOOL:
				__theme_color_normal_used = value
				_UpdateLabelTheme()
			else : success = false
		"theme_overrides/colors/use_font_color_selected":
			if typeof(value) == TYPE_BOOL:
				__theme_color_selected_used = value
				_UpdateLabelTheme()
			else : success = false
		_:
			success = false
	
	if success:
		property_list_changed_notify()
	return success


func _get_property_list():
	return [
		{
			name = "Source List Item",
			type = TYPE_NIL,
			usage = PROPERTY_USAGE_CATEGORY
		},
		{
			name = "source_name",
			type = TYPE_STRING,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "source_type",
			type = TYPE_INT,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "selected",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/styles/normal",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "StyleBox",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/styles/selected",
			type = TYPE_OBJECT,
			hint = PROPERTY_HINT_RESOURCE_TYPE,
			hint_string = "StyleBox",
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/colors/font_color_normal",
			type = TYPE_COLOR,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/colors/use_font_color_normal",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/colors/font_color_selected",
			type = TYPE_COLOR,
			usage = PROPERTY_USAGE_DEFAULT
		},
		{
			name = "theme_overrides/colors/use_font_color_selected",
			type = TYPE_BOOL,
			usage = PROPERTY_USAGE_DEFAULT
		}
	]

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------
func _UpdateLabelStyle(target : String, source : String, style : StyleBox) -> void:
	if style:
		label_node.add_stylebox_override(target, style)
	elif has_stylebox(source, "SourceListItem"):
		label_node.add_stylebox_override(target, get_stylebox(source, "SourceListItem"))
	else:
		label_node.add_stylebox_override(target, null)

func _UpdateLabelColor(target : String, source : String, color) -> void:
	if color:
		label_node.add_color_override(target, color)
	elif has_color(source, "SourceListItem"):
		label_node.add_color_override(target, get_color(source, "SourceListItem"))
	else:
		label_node.add_color_override(target, label_node.get_color(source))
	
func _UpdateLabelTheme() -> void:
	if __selected:
		var color = null if not __theme_color_selected_used else __theme_color_selected
		_UpdateLabelColor("font_color", "font_color_selected", color)
		_UpdateLabelStyle("normal", "selected", __theme_style_normal)
	else:
		var color = null if not __theme_color_normal_used else __theme_color_normal
		_UpdateLabelColor("font_color", "font_color_normal", color)
		_UpdateLabelStyle("normal", "normal", __theme_style_selected)

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func is_selected() -> bool:
	return __selected

func select(s : bool = true) -> void:
	if __selected != s:
		__selected = s
		_UpdateLabelTheme()

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_mouse_entered() -> void:
	set_process_input(true)

func _on_mouse_exited() -> void:
	set_process_input(false)
