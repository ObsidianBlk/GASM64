extends Control


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
			var lines = codeeditor_node.get_rect().h / fheight
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


