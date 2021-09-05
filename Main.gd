extends Node2D



func _ready() -> void:
	var v = 0b11111110
	var s = -1 * ((v & 0x80) >> 7)
	print((v ^ 0xFF) & 0b01111111)
	pass
	#GASM.print_mode_chart()
