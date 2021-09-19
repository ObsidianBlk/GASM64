extends Control

export var op_name : String = ""				setget _set_op_name

onready var lbl_op : Label = $MC/HBox/LBL_OP
onready var lbl_name : Label = $MC/HBox/Info/Info_Name/Text
onready var lbl_cat : Label = $MC/HBox/Info/Info_Category/Text
onready var lbl_desc : Label = $MC/HBox/Info/Info_Description/Text
onready var lbl_flags : Label = $MC/HBox/Info/Info_Flags/Text
onready var lbl_tags : Label = $MC/HBox/Info/Info_Tags/Text

func _set_op_name(n : String) -> void:
	var op : Dictionary = GASM.get_op_info(n)
	if op.mode != null:
		op_name = n
		_update_card(op)


func _update_card(op : Dictionary) -> void:
	pass
