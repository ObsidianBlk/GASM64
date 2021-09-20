extends TextEdit

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------
func _ready() -> void:
	_UpdateSyntaxColors()
	connect("cursor_changed", self, "_on_cursor_changed")
	

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


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Handler Methods
# ---------------------------------------------------------------------------
func _on_cursor_changed() -> void:
	var cl = cursor_get_line()
	var cc = cursor_get_column()
	var lcount = get_line_count()
	var lhidden = is_line_hidden(0)
	print("Cursor: (", cl, ", ", cc, ") | Num Lines: ", lcount, " | L0 Hidden: ", lhidden)


