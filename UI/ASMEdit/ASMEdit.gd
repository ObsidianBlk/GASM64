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
	dataview_node.available_lines = 10
	#dataview_node.set_line(0, 0x8000, PoolByteArray([255, 110, 96]))
	
	codeeditor_node.connect("source_change", self, "_on_source_change")


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

func get_visible_top_line_index() -> int:
	if codeeditor_node:
		var font = codeeditor_node.get_font("font")
		if font:
			if font is DynamicFont:
				return int(floor(codeeditor_node.scroll_vertical / font.size))
			if font is BitmapFont:
				return int(floor(codeeditor_node.scroll_vertical / font.height))
	return 0

func get_visible_line_count() -> int:
	var cerect = codeeditor_node.get_rect()
	var font = codeeditor_node.get_font("font")
	if font:
		if font is DynamicFont:
			return int(floor(cerect.size.y / font.size))
		if font is BitmapFont:
			return int(floor(cerect.size.y / font.height))
	return 0

func get_line_count() -> int:
	if codeeditor_node:
		return codeeditor_node.get_line_count()
	return 0

# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------

func _on_source_change() -> void:
	var src = codeeditor_node.text
	var assem = Assembler.new()
	if assem.process(src):
		var s = get_visible_top_line_index()
		var e = s + get_visible_line_count()
		if dataview_node:
			dataview_node.clear()
			var lines = assem.get_binary_lines(s, e)
			for line in lines:
				dataview_node.set_line(line.line, line.addr, line.data)
		#assem.print_binary()
	else:
		assem.print_errors()
	#print(assem.get_binary())
#	var lex = Lexer.new(src)
#	if lex.is_valid():
#		var parser = Parser.new(lex)
#		if parser.is_valid():
#			print(parser.get_ast())
#		else:
#			for i in range(parser.error_count()):
#				print(parser.get_error(i))
#	else:
#		var err = lex.get_error_token()
#		if err != null:
#			print("ERROR [Line: ", err.line, ", Col: ", err.col, "]: ", err.msg)

func _on_CodeEditor_resized():
	var cerect = codeeditor_node.get_rect()
	if cerect.size.y < 5000:
		dataview_node.set_available_lines_to_height(cerect.size.y)

func _on_CodeEditor_line_change(line_num, line_text):
	var lex = Lexer.new(line_text, line_num)
	if lex.is_valid():
		var parser = Parser.new(lex)
		if parser.is_valid():
			print(parser.get_ast())
		else:
			for i in range(parser.error_count()):
				print(parser.get_error(i))
	else:
		var err = lex.get_error_token()
		if err != null:
			print("ERROR [Line: ", err.line, ", Col: ", err.col, "]: ", err.msg)
