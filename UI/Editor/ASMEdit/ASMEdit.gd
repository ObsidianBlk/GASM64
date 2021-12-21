extends Control
class_name ASMEdit


# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _assem : Assembler = null
var _project : Project = null
var _resource_name : String = ""
var _resource_info : Dictionary = {}

# ---------------------------------------------------------------------------
# Onready Variables
# ---------------------------------------------------------------------------
onready var sourcelist_node = get_node("Editor/SourceList")
onready var dataview_node = get_node("Editor/DataView")
onready var codeeditor_node = get_node("Editor/CodeEditor")


# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------



# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	_assem = Assembler.new()
	dataview_node.available_lines = 10
	
	GASM_Project.connect("project_loaded", self, "_on_project_loaded")
	_project = GASM_Project.get_project()
	
	codeeditor_node.connect("resized", self, "_on_CodeEditor_resized")
	codeeditor_node.connect("source_change", self, "_on_source_change")
	codeeditor_node.connect("visible_lines_change", self, "_on_visible_lines_change")


# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _UpdateDataView(start : int, end : int) -> void:
	if dataview_node:
		dataview_node.clear()
		if "assembler" in _resource_info:
			var lines = _resource_info.assembler.get_binary_lines(start, end)
			for line in lines:
				dataview_node.set_line(line.line - start, line.addr, line.data)

func _SetCodeEditorText(source : String, resource_update : bool = true) -> void:
	codeeditor_node.text = source
	if "source" in _resource_info and resource_update:
		_resource_info.source = source
	_UpdateDataView(
		codeeditor_node.get_current_start_line(),
		codeeditor_node.get_current_end_line()
	)

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
		return codeeditor_node.scroll_vertical
#		var font = codeeditor_node.get_font("font")
#		if font:
#			if font is DynamicFont:
#				return int(floor(codeeditor_node.scroll_vertical / font.size))
#			if font is BitmapFont:
#				return int(floor(codeeditor_node.scroll_vertical / font.height))
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

func set_source(source_name) -> void:
	if _project != null:
		if _project.has_resource(Project.RESOURCE_TYPE.ASSEMBLY, source_name):
			_resource_name = source_name
			_resource_info = _project.get_assembly_resource(source_name)
			_SetCodeEditorText(_resource_info.source, false)


# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------

func _on_project_loaded(proj : Project) -> void:
	_project = proj
	_resource_info = {}
	_SetCodeEditorText("", false)


func _on_source_change() -> void:
	var src = codeeditor_node.text
	if _project:
		_project.set_assembly_resource(_resource_name, {"source":src})
	if "assembler" in _resource_info:
		var asm = _resource_info.assembler
		if asm.process_from_source(src):
			_UpdateDataView(
				codeeditor_node.get_current_start_line(),
				codeeditor_node.get_current_end_line()
			)
			#assem.print_binary()
		else:
			asm.print_errors()

func _on_visible_lines_change(start : int, end : int) -> void:
	_UpdateDataView(start, end)

func _on_CodeEditor_resized():
	var cerect = codeeditor_node.get_rect()
	if cerect.size.y < 5000:
		dataview_node.set_available_lines_to_height(cerect.size.y)

#func _on_CodeEditor_line_change(line_num, line_text):
#	var lex = Lexer.new(line_text, line_num)
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
