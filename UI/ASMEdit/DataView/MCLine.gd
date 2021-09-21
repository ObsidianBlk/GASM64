extends Container
class_name MCLine
# MCLine : Machine Code Line


# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------
const FONT_MIN_SIZE = 4

# -----------------------------------------------------------------------------
# Export Variables
# -----------------------------------------------------------------------------
export var font_size : int = 16						setget set_font_size
export var command_color : Color = Color(1,1,1,1)	setget set_command_color
export var byte_color : Color = Color(1,1,1,1)		setget set_byte_color

# -----------------------------------------------------------------------------
# Onready Variables
# -----------------------------------------------------------------------------
onready var cmd_node = get_node("cmd")
onready var byte1_node = get_node("byte1")
onready var byte2_node = get_node("byte2")

# -----------------------------------------------------------------------------
# Setters / Getters
# -----------------------------------------------------------------------------
func set_font_size(s : int) -> void:
	if s > FONT_MIN_SIZE:
		font_size = s
		if cmd_node:
			cmd_node.get("custom_fonts/font").set_size(font_size)
		if byte1_node:
			byte1_node.get("custom_fonts/font").set_size(font_size)
		if byte2_node:
			byte2_node.get("custom_fonts/font").set_size(font_size)

func set_command_color(c : Color) -> void:
	command_color = c
	if cmd_node:
		cmd_node.set("custom_colors/font_color", command_color)

func set_byte_color(c : Color) -> void:
	byte_color = c
	if byte1_node:
		byte1_node.set("custom_colors/font_color", byte_color)
	if byte2_node:
		byte2_node.set("custom_colors/font_color", byte_color)

# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready() -> void:
	set_font_size(font_size)
	set_command_color(command_color)
	set_byte_color(byte_color)
	clear_line()


# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------
func clear_line() -> void:
	set_line_bytes()


func set_line_bytes(cmd: int = -1, byte1: int = -1, byte2: int = -1) -> void:
	if cmd_node:
		if cmd >= 0:
			cmd_node.text = GASM.int_to_hex(cmd & 0xFF, 2)
		else:
			cmd_node.text = "  "
	if byte1_node:
		if byte1 >= 0:
			byte1_node.text = GASM.int_to_hex(byte1 & 0xFF, 2)
		else:
			byte1_node.text = "  "
	if byte2_node:
		if byte2 >= 0:
			byte2_node.text = GASM.int_to_hex(byte2 & 0xFF, 2)
		else:
			byte2_node.text = "  "

func set_line(dat : PoolIntArray) -> void:
	var cmd = -1
	if dat.size() >= 1:
		cmd = dat[0]
	var byte1 = -1
	if dat.size() >= 2:
		byte1 = dat[1]
	var byte2 = -1
	if dat.size() >= 3:
		byte2 = dat[2]
	set_line_bytes(cmd, byte1, byte2)

func get_line() -> PoolIntArray:
	if cmd_node and byte1_node and byte2_node:
		return PoolIntArray([
			GASM.hex_to_int(cmd_node.text) if cmd_node.text != "  " else -1,
			GASM.hex_to_int(byte1_node.text) if byte1_node.text != "  " else -1,
			GASM.hex_to_int(byte2_node.text) if byte2_node.text != "  " else -1
		])
	else:
		return PoolIntArray([-1, -1, -1])

func set_from_cmdline(node : Container) -> void:
	if node.has_method("set_line") and node.has_method("get_line"):
		var dat = node.get_line()
		set_line(dat)


