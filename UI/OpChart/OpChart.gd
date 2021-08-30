extends Container

var OPINFOBOX = preload("res://UI/OpChart/OpInfoBox.tscn")
var AXISINFO = preload("res://UI/OpChart/AxisInfo.tscn")

onready var chart_node = get_node("Chart")

func _ready() -> void:
	print("Starting")
	var ai = AXISINFO.instance()
	ai.axis_mode = 0
	ai.text = "Across: LSB\nDown: MSB"
	chart_node.add_child(ai)
	
	print("Adding across")
	for i in range(16):
		var aix = AXISINFO.instance()
		aix.axis_mode = 1
		aix.text = GASM.int_to_hex(i)
		chart_node.add_child(aix)
	
	
	for i in range(256):
		if i & 0x0F == 0:
			var aiy = AXISINFO.instance()
			aiy.axis_mode = 2
			aiy.text = GASM.int_to_hex((i & 0xF0) >> 4)
			chart_node.add_child(aiy)
		var oib = OPINFOBOX.instance()
		oib.op_code = i
		chart_node.add_child(oib)
