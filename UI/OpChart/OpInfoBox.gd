extends Control


export (int, 0, 255) var op_code = 0


var ready : bool = false

onready var sep_node = get_node("VBC/Name/VSeparator")
onready var opname_node = get_node("VBC/Name/OpName")
onready var code_node = get_node("VBC/Name/Code")
onready var opmode_node = get_node("VBC/OpMode")
onready var bytes_node = get_node("VBC/Info/Bytes")
onready var cycles_node = get_node("VBC/Info/Cycles")
onready var info_node = get_node("VBC/Info")


func set_op_code(c : int) -> void:
	if c >= 0 and c < 256:
		op_code = c
		if ready:
			var cinfo = GASM.get_inst_code_info(c)
			if cinfo != null:
				info_node.visible = true
				opmode_node.visible = true
				sep_node.visible = true
				code_node.visible = true
				
				opname_node.text = GASM.get_inst_code_name(c)
				opmode_node.text = cinfo.addr_name
				code_node.text = Utils.int_to_hex(c)
				bytes_node.text = String(cinfo.bytes)
				cycles_node.text = String(cinfo.cycles)
			else:
				opname_node.text = "X"
				info_node.visible = false
				opmode_node.visible = false
				sep_node.visible = false
				code_node.visible = false


func _ready() -> void:
	ready = true
	set_op_code(op_code)
