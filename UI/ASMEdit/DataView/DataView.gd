extends Container

const MCLINE = preload("res://UI/ASMEdit/DataView/MCLine.tscn")

# -----------------------------------------------------------------------------
# Export Variables
# -----------------------------------------------------------------------------
export var available_lines : int = 0				setget set_available_lines


# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
var _mclines : Array = []
var _font_size : int = 16
var _cmd_color : Color = Color(1,1,1)
var _num_color : Color = Color(1,1,1) 

# -----------------------------------------------------------------------------
# Onready Variables
# -----------------------------------------------------------------------------
onready var lines_node = get_node("Lines")

# -----------------------------------------------------------------------------
# Setters / Getters
# -----------------------------------------------------------------------------
func set_available_lines(l : int) -> void:
	print("Available lines: ", l)
	if l >= 0:
		available_lines = l
		_UpdateCmdLines()


# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready() -> void:
	call_deferred("_UpdateView")

# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------
func _findASM() -> ASMEdit:
	var node = get_parent()
	while node != null and not (node is ASMEdit):
		node = node.get_parent()
	return node

 
func _UpdateView() -> void:
	var parent = _findASM()
	if parent:
		var fnt = parent.get_font("font", "ASMEdit")
		if fnt is DynamicFont:
			_font_size = fnt.size
		_cmd_color = parent.get_color("function_color", "ASMEdit")
		_num_color = parent.get_color("number_color", "ASMEdit")
	_UpdateCmdLines()


func _UpdateCmdLines() -> void:
	if available_lines != _mclines.size():
		if lines_node:
			if available_lines > _mclines.size():
				for _i in range(available_lines - _mclines.size()):
					var cl = MCLINE.instance()
					cl.font_size = _font_size
					cl.command_color = _cmd_color
					cl.byte_color = _num_color
					lines_node.add_child(cl)
					_mclines.append(cl)
			else:
				for _i in range(_mclines.size() - available_lines):
					var cl = _mclines.pop_back()
					lines_node.remove_child(cl)
					cl.queue_free()
	else:
		for line in _mclines:
			line.font_size = _font_size
			line.command_color = _cmd_color
			line.byte_color = _num_color

# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------
func clear() -> void:
	for i in range(_mclines.size()):
		_mclines[i].clear_line()

func clear_line(idx : int) -> void:
	if idx >= 0 and idx < _mclines.size():
		_mclines[idx].clear_line()

func set_available_lines_to_height(height : int) -> void:
	var mclheight = 0
	var rect = null
	if _mclines.size() <= 0:
		var mcl = MCLINE.instance()
		mcl.font_size = _font_size
		rect = mcl.get_rect()
		mcl.queue_free()
	else:
		rect = _mclines[0].get_rect()
	
	var sep = lines_node.get_constant("separation")
	mclheight = rect.size.y + sep
	if mclheight > 0:
		var lines = floor(height / mclheight)
		set_available_lines(lines)
	else:
		set_available_lines(0)


func set_line(idx : int, addr : int, data : PoolByteArray) -> void:
	if idx >= 0 and idx < _mclines.size():
		_mclines[idx].set_line(addr, data)

#func push_line_top(cmd : int = -1, byte1 : int = -1, byte2 : int = -1) -> void:
#	for i in range(_mclines.size()-1, 0, -1):
#		_mclines[i].set_from_cmdline(_mclines[i-1])
#	_mclines[0].set_line_bytes(cmd, byte1, byte2) 
#
#func push_line_bottom(cmd : int = -1, byte1 : int = -1, byte2 : int = -1) -> void:
#	for i in range(1, _mclines.size()):
#		_mclines[i-1].set_from_cmdline(_mclines[i])
#	_mclines[_mclines.size() - 1].set_line_bytes(cmd, byte1, byte2)


