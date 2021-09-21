extends Control
class_name ASMEdit


# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Onready Variables
# ---------------------------------------------------------------------------
onready var dataview_node = get_node("Editor/DataView")
onready var codeeditor_node = get_node("Editor/CodeEditor")


# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	print("Yo bro!")
	dataview_node.available_lines = 10
	dataview_node.set_line(0, 255, 110, 96)


# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func add_font_override(name : String, font : Font) -> void:
	if codeeditor_node:
		codeeditor_node.add_font_override(name, font)
		if dataview_node:
			if font is DynamicFont:
				dataview_node.font_size = font.size
			var fheight = font.get_height()
			var cerect = codeeditor_node.get_rect()
			var lines = cerect.size.y / fheight
			dataview_node.available_lines = lines

func get_font(name : String, node_type : String = "") -> Font:
	if node_type == "ASMEdit" and codeeditor_node:
		return codeeditor_node.get_font(name, node_type)
	return null

func has_font(name : String, node_type : String = "") -> bool:
	if node_type == "ASMEdit" and codeeditor_node:
		codeeditor_node.has_font(name, node_type)
	return false

func get_color(name : String, node_type : String = "") -> Color:
	if node_type == "ASMEdit" and codeeditor_node:
		return codeeditor_node.get_color(name)
	return .get_color(name)

# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------

func _on_CodeEditor_resized():
	var cerect = codeeditor_node.get_rect()
	if cerect.size.y < 5000:
		dataview_node.set_available_lines_to_height(cerect.size.y)

func _on_CodeEditor_line_change(line_num, line_text):
	print("Line Number ", line_num, " text is now \"", line_text, "\"")
