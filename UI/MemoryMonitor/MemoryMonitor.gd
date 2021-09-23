extends Control


# --------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------
export var bus_node_path : NodePath = ""			setget set_bus_node_path
export var cpu_node_path : NodePath = ""			setget set_cpu_node_path
export (int, 1, 30) var updates_per_second = 10		setget set_updates_per_second

# --------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------

var _bus : Bus = null
var _cpu : CPU6502 = null
var _pageOffset : int = 0

var _utime = 0
var _utime_interval = 0

# --------------------------------------------------------------------------
# Onready Variables
# --------------------------------------------------------------------------
onready var A_node = get_node("VBC/CPUStatus/MC/VBC/Registers/A/Val")
onready var X_node = get_node("VBC/CPUStatus/MC/VBC/Registers/X/Val")
onready var Y_node = get_node("VBC/CPUStatus/MC/VBC/Registers/Y/Val")
onready var STK_node = get_node("VBC/CPUStatus/MC/VBC/Registers/STK/Val")
onready var PC_node = get_node("VBC/CPUStatus/MC/VBC/Registers/PC/Val")

onready var Carry_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/Carry/CB")
onready var Zero_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/Zero/CB")
onready var IRQD_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/IRQD/CB")
onready var DecMode_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/DecMode/CB")
onready var Break_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/Break/CB")
onready var Overflow_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/Overflow/CB")
onready var Neg_node = get_node("VBC/CPUStatus/MC/VBC/ProcState/Neg/CB")

onready var PD1_node = get_node("VBC/PageMonitor/HBC/PDContainer/VBC/PD1")
onready var PD2_node = get_node("VBC/PageMonitor/HBC/PDContainer/VBC/PD2")

onready var PDSlider_node = get_node("VBC/PageMonitor/HBC/Scroller/PDSlider")

# --------------------------------------------------------------------------
# Setters / Getters
# --------------------------------------------------------------------------
func set_bus_node_path(p : NodePath) -> void:
	bus_node_path = p
	if bus_node_path != "":
		var bus = get_node(p)
		if bus is Bus:
			_bus = bus
	else:
		_bus = null


func set_cpu_node_path(p : NodePath) -> void:
	cpu_node_path = p
	if cpu_node_path != "":
		var cpu = get_node(cpu_node_path)
		if cpu is CPU6502:
			_cpu = cpu
	else:
		_cpu = null

func set_updates_per_second(u : int) -> void:
	if u > 0 and u <= 30:
		updates_per_second = u
		_utime_interval = 1.0 / float(updates_per_second)

# --------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------

func _ready() -> void:
	set_updates_per_second(updates_per_second)
	if bus_node_path != "" and _bus == null:
		set_bus_node_path(bus_node_path)
	if cpu_node_path != "" and _cpu == null:
		set_cpu_node_path(cpu_node_path)

func _process(delta : float) -> void:
	_utime += delta
	if _utime >= _utime_interval:
		_utime -= _utime_interval
		_UpdateMonitor()
		

# --------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------

func _UpdateMonitor() -> void:
	if not (_cpu and _bus and PD1_node and PD2_node):
		return
	_UpdatePageDisplays()
	_UpdateCPUDisplays()


func _UpdatePageDisplays() -> void:
	PD1_node.set_page(_pageOffset)
	PD1_node.set_data(_bus.page_dump(_pageOffset))
		
	PD2_node.set_page(_pageOffset+1)
	PD2_node.set_data(_bus.page_dump(_pageOffset+1))

func _UpdateCPUDisplays() -> void:
	var info = _cpu.get_state_info()
	A_node.text = Utils.int_to_hex(info.A, 2)
	X_node.text = Utils.int_to_hex(info.X, 2)
	Y_node.text = Utils.int_to_hex(info.Y, 2)
	STK_node.text = Utils.int_to_hex(info.SP, 2)
	PC_node.text = Utils.int_to_hex(info.PC, 4)
	
	Carry_node.pressed = (info.Status & 0x01) == 0x01
	Zero_node.pressed = (info.Status & 0x02) == 0x02
	IRQD_node.pressed = (info.Status & 0x04) == 0x04
	DecMode_node.pressed = (info.Status & 0x08) == 0x08
	Break_node.pressed = (info.Status & 0x10) == 0x10
	Overflow_node.pressed = (info.Status & 0x40) == 0x40
	Neg_node.pressed = (info.Status & 0x80) == 0x80

# --------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------

func _on_PDSlider_value_changed(value):
	_pageOffset = 254 - int(value)
	if not (_bus and PD1_node and PD2_node):
		_UpdatePageDisplays()


func _on_ScrollUp_pressed():
	if not PDSlider_node:
		return
	if PDSlider_node.value < 254:
		PDSlider_node.value += 1
		_on_PDSlider_value_changed(PDSlider_node.value)



func _on_ScrollDown_pressed():
	if not PDSlider_node:
		return
	if PDSlider_node.value > 0:
		PDSlider_node.value -= 1
		_on_PDSlider_value_changed(PDSlider_node.value)


