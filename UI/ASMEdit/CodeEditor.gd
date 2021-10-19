extends TextEdit

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal line_change(line_num, line_text)
signal visible_lines_change(first, last)
signal source_change()


# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _active_line = ""
var _last_cursor_line = 0
var _last_line_count = 1

var last_start_line : int = -1
var last_end_line : int = -1

# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	_UpdateSyntaxColors()
	connect("resized", self, "_on_resized")
	connect("cursor_changed", self, "_on_cursor_changed")
	connect("text_changed", self, "_on_text_changed")
	

# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _UpdateSyntaxColors() -> void:
	var funcColor = get_color("function_color")
	var commentColor = get_color("selection_color")
	#if not funcColor:
	#	funcColor = color_instruction
	var ops = GASM.get_instructions()
	for op in ops:
		add_keyword_color(op.to_lower(), funcColor)
		add_keyword_color(op.to_upper(), funcColor)
	add_color_region(";", "\n", commentColor, true)


func _UpdateVisibleLines(emit_on_changed : bool = false) -> void:
	var start_line = scroll_vertical
	var end_line = start_line + get_visible_line_count()
	if start_line != last_start_line or end_line != last_end_line:
		last_start_line = start_line
		last_end_line = end_line
		if emit_on_changed:
			emit_signal("visible_lines_change", last_start_line, last_end_line)


func _UpdateData() -> void:
	var cl = cursor_get_line()
	var cc = cursor_get_column()
	var line_count = get_line_count()
	_UpdateVisibleLines(true)
	if get_line_count() != _last_line_count:
		emit_signal("source_change")
		_last_line_count = line_count
	else:
		if cl != _last_cursor_line:
			var line = get_line(_last_cursor_line)
			if line != _active_line:
				emit_signal("source_change")
				#emit_signal("line_change", _last_cursor_line, line)
			_last_cursor_line = cl
			_active_line = get_line(_last_cursor_line)

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func get_visible_line_count() -> int:
	var cerect = get_rect()
	var font = get_font("font")
	if font:
		if font is DynamicFont:
			return int(floor(cerect.size.y / font.size))
		if font is BitmapFont:
			return int(floor(cerect.size.y / font.height))
	return 0

func get_current_start_line() -> int:
	if last_start_line >= 0:
		return last_start_line
	return 0

func get_current_end_line() -> int:
	if last_end_line >= 0:
		return last_end_line
	return 0


# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------
func _on_resized() -> void:
	_UpdateVisibleLines(true)

func _on_cursor_changed() -> void:
	Utils.call_deferred_once("_UpdateData", self)

func _on_text_changed() -> void:
	Utils.call_deferred_once("_UpdateData", self)

