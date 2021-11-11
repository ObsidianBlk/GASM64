extends Node2D

const HZ = 1000000

onready var editormodeui_node = get_node("UI/UIContainer/EditorModeUI")

#onready var dv_node = get_node("UI/EditorModeUI/Main/DataView")

func _ready() -> void:
	var bus = $Computer/Bus
	bus.fill(0, 16, 0xEA)
	bus.fill(255, 255, 0xEA)
	bus.set_mem_addr(0xFFFC, 0x00)
	bus.set_mem_addr(0xFFFD, 0x02)
	
	var clock = $Computer/Clock
	#print(GASM.DATA)
	#clock.enable()
	
	#randomize()


#func _RandDVLine() -> Array:
#	var cmd = int(max(-1, min(255, floor(rand_range(-96, 256)))))
#	var byte1 = -1
#	var byte2 = -1
#	if cmd >= 0:
#		byte1 = int(max(-1, min(255, floor(rand_range(-96, 256)))))
#		if byte1 >= 0:
#			byte2 = int(max(-1, min(255, floor(rand_range(-96, 256)))))
#	return [cmd, byte1, byte2]


func _on_quit():
	get_tree().quit()


func _on_Timer_timeout():
	pass




func _on_mode_change(mode):
	match mode:
		"game":
			editormodeui_node.visible = false
		"editor":
			editormodeui_node.visible = true
