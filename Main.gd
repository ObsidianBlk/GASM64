extends Node2D

const HZ = 1000000

onready var cpu = get_node("Computer/CPU6502")

func _ready() -> void:
	var bus = $Computer/Bus
	bus.set_mem_addr(0xFFFC, 0x00)
	bus.set_mem_addr(0xFFFD, 0x02)

func _process(delta : float) -> void:
	var cycles = floor(HZ * delta)
	for _i in range(cycles):
		cpu.clock()
