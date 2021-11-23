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
export var address_color : Color = Color(1,1,1,1)	setget set_address_color
export var command_color : Color = Color(1,1,1,1)	setget set_command_color
export var byte_color : Color = Color(1,1,1,1)		setget set_byte_color

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
var data : PoolByteArray = PoolByteArray()

# -----------------------------------------------------------------------------
# Onready Variables
# -----------------------------------------------------------------------------
onready var addr_node = get_node("addr")
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
	_UpdateColoring()

func set_byte_color(c : Color) -> void:
	byte_color = c
	_UpdateColoring()

func set_address_color(c : Color) -> void:
	address_color = c
	_UpdateColoring()

# -----------------------------------------------------------------------------
# Override Methods
# -----------------------------------------------------------------------------
func _ready() -> void:
	set_font_size(font_size)
	set_command_color(command_color)
	set_byte_color(byte_color)
	clear_line()


# -----------------------------------------------------------------------------
# Private Methods
# -----------------------------------------------------------------------------
func _SetLineBytes(addr: int = -1, cmd: int = -1, byte1: int = -1, byte2: int = -1) -> void:
	if addr_node:
		if addr >= 0:
			addr_node.text = Utils.int_to_hex(addr & 0xFFFF, 4)
		else:
			addr_node.text = "    "
	if cmd_node:
		if cmd >= 0:
			cmd_node.text = Utils.int_to_hex(cmd & 0xFF, 2)
		else:
			cmd_node.text = "  "
	if byte1_node:
		if byte1 >= 0:
			byte1_node.text = Utils.int_to_hex(byte1 & 0xFF, 2)
		else:
			byte1_node.text = "  "
	if byte2_node:
		if byte2 >= 0:
			if byte2 < 256:
				byte2_node.text = Utils.int_to_hex(byte2 & 0xFF, 2)
			else:
				byte2_node.text = "**"
		else:
			byte2_node.text = "  "

func _UpdateColoring() -> void:
	if addr_node:
		addr_node.set("custom_colors/font_color", address_color)
	if cmd_node:
		if data.size() <= 3:
			cmd_node.set("custom_colors/font_color", command_color)
		else:
			cmd_node.set("custom_colors/font_color", byte_color)
	if byte1_node:
		byte1_node.set("custom_colors/font_color", byte_color)
	if byte2_node:
		byte2_node.set("custom_colors/font_color", byte_color)

# -----------------------------------------------------------------------------
# Public Methods
# -----------------------------------------------------------------------------
func clear_line() -> void:
	_SetLineBytes()

func set_line(addr : int, dat : PoolByteArray) -> void:
	data = dat
	_UpdateColoring()
	var cmd = -1
	if dat.size() >= 1:
		cmd = dat[0]
	var byte1 = -1
	if dat.size() >= 2:
		byte1 = dat[1]
	var byte2 = -1
	if dat.size() == 3:
		byte2 = dat[2]
	elif dat.size() > 3:
		byte2 = 256
	_SetLineBytes(addr, cmd, byte1, byte2)

func get_line() -> Dictionary:
	var addr = -1
	if addr_node:
		addr = Utils.hex_to_int(addr_node.text)
	return {
		"addr": addr,
		"data": PoolByteArray(data)
	}

func copy_from(node : MCLine) -> void:
	var linfo = node.get_line()
	if linfo.addr >= 0:
		set_line(linfo.addr, linfo.data)
	else:
		_SetLineBytes()


