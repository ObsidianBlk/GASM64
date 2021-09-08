extends Node2D

const HZ = 1000000

func _ready() -> void:
	var bus = $Computer/Bus
	bus.set_mem_addr(0xFFFC, 0x00)
	bus.set_mem_addr(0xFFFD, 0x02)
	
	var clock = $Computer/Clock
	#clock.enable()

