extends TextEdit

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal line_change(line_num, line_text)
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

# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	_UpdateSyntaxColors()
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
	var ops = GASM.get_ops()
	for op in ops:
		add_keyword_color(op.to_lower(), funcColor)
		add_keyword_color(op.to_upper(), funcColor)
	add_color_region(";", "\n", commentColor, true)


func _UpdateData() -> void:
	var cl = cursor_get_line()
	var cc = cursor_get_column()
	var line_count = get_line_count()
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


# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------
func _on_cursor_changed() -> void:
	Utils.call_deferred_once("_UpdateData", self)

func _on_text_changed() -> void:
	Utils.call_deferred_once("_UpdateData", self)

