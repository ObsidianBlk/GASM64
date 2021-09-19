extends Container

const CMDLINE = preload("res://UI/ASMEdit/DataView/cmdline.tscn")

# -----------------------------------------------------------------------------
# Export Variables
# -----------------------------------------------------------------------------
export var font_size : int = 16						setget set_font_size
export var command_color : Color = Color(1,1,1,1)	setget set_command_color
export var byte_color : Color = Color(1,1,1,1)		setget set_byte_color
export var available_lines : int = 0				setget set_available_lines


# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
var _cmdlines : Array = []

# -----------------------------------------------------------------------------
# Onready Variables
# -----------------------------------------------------------------------------
onready var lines_node = get_node("Lines")

# -----------------------------------------------------------------------------
# Setters / Getters
# -----------------------------------------------------------------------------
func set_font_size(s : int) -> void:
	font_size = s
	_UpdateCmdLines()

func set_command_color(c : Color) -> void:
	command_color = c
	_UpdateCmdLines()

func set_byte_color(c : Color) -> void:
	byte_color = c
	_UpdateCmdLines()

func set_available_lines(l : int) -> void:
	if l >= 0:
		available_lines = l
		_UpdateCmdLines()


# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready() -> void:
	_UpdateCmdLines()

# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------
func _UpdateCmdLines() -> void:
	if available_lines != _cmdlines.size():
		if lines_node:
			if available_lines > _cmdlines.size():
				for _i in range(available_lines - _cmdlines.size()):
					var cl = CMDLINE.instance()
					cl.font_size = font_size
					cl.command_color = command_color
					cl.byte_color = byte_color
					lines_node.add_child(cl)
					_cmdlines.append(cl)
			else:
				for _i in range(_cmdlines.size() - available_lines):
					var cl = _cmdlines.pop_back()
					lines_node.remove_child(cl)
					cl.queue_free()
	else:
		for line in _cmdlines:
			line.font_size = font_size
			line.command_color = command_color
			line.byte_color = byte_color

# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------
func clear() -> void:
	for i in range(_cmdlines.size()):
		set_line(i)

func clear_line(idx : int) -> void:
	set_line(idx)

func set_line(idx : int, cmd : int = -1, byte1 : int = -1, byte2 : int = -1) -> void:
	if idx >= 0 and idx < _cmdlines.size():
		_cmdlines[idx].set_line_bytes(cmd, byte1, byte2)

func push_line_top(cmd : int = -1, byte1 : int = -1, byte2 : int = -1) -> void:
	for i in range(_cmdlines.size()-1, 0, -1):
		_cmdlines[i].set_from_cmdline(_cmdlines[i-1])
	_cmdlines[0].set_line_bytes(cmd, byte1, byte2) 

func push_line_bottom(cmd : int = -1, byte1 : int = -1, byte2 : int = -1) -> void:
	for i in range(1, _cmdlines.size()):
		_cmdlines[i-1].set_from_cmdline(_cmdlines[i])
	_cmdlines[_cmdlines.size() - 1].set_line_bytes(cmd, byte1, byte2)


