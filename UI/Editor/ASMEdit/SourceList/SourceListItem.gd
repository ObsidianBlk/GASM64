extends Control

# -------------------------------------------------------------------------
# Consts and Signals
# -------------------------------------------------------------------------
signal selected(source_name)

const UNSELECT_COLOR = Color(1,1,1,0)

# -------------------------------------------------------------------------
# Export Variables
# -------------------------------------------------------------------------
export var source_name : String = ""						setget set_source_name
export var select_color : Color = Color(1, 1, 1, 0.25)		setget set_select_color

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------


# -------------------------------------------------------------------------
# Onready Variables
# -------------------------------------------------------------------------
onready var label_node : Label = get_node("Control/LBL/Label")
onready var color_node : ColorRect = get_node("Control/ColorRect")

# -------------------------------------------------------------------------
# Setters / Getters
# -------------------------------------------------------------------------
func set_source_name(sn : String) -> void:
	source_name = sn
	if label_node:
		label_node.text = source_name


func set_select_color(c : Color) -> void:
	if c.a <= 0:
		select_color = c
		if color_node and color_node.color.a > 0:
			color_node.color = select_color

# -------------------------------------------------------------------------
# Override Methods
# -------------------------------------------------------------------------
func _ready() -> void:
	set_process_input(false)
	set_source_name(source_name)
	
	connect("mouse_entered", self, "_on_mouse_entered")
	connect("mouse_exited", self, "_on_mouse_exited")

func _input(event) -> void:
	print("Hello old bean")
	if event is InputEventMouseButton:
		select()
		emit_signal("selected", source_name)

# -------------------------------------------------------------------------
# Private Methods
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Public Methods
# -------------------------------------------------------------------------
func is_selected() -> bool:
	return color_node.color.a > 0

func select(s : bool = true) -> void:
	color_node.color = UNSELECT_COLOR if not s else select_color

# -------------------------------------------------------------------------
# Handler Methods
# -------------------------------------------------------------------------
func _on_mouse_entered() -> void:
	set_process_input(true)

func _on_mouse_exited() -> void:
	set_process_input(false)
