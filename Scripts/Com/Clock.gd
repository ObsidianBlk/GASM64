extends Node
class_name Clock


# --------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------
export var hertz : float = 1.0			setget set_hertz
export var cpu_path : NodePath = ""		setget set_cpu_path

# --------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------
var _dtime : float = 0.0

var cpu_node : CPU6502 = null

# --------------------------------------------------------------------------
# Setters / Getters
# --------------------------------------------------------------------------
func set_hertz(hz : float) -> void:
	if hz > 0.0:
		hertz = hz

func set_cpu_path(p : NodePath) -> void:
	cpu_path = p
	if cpu_path == "":
		cpu_node = null
	else:
		var cpu = get_node(cpu_path)
		if cpu is CPU6502:
			cpu_node = cpu


# --------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------
func _ready() -> void:
	set_process(false)
	if cpu_node == null and cpu_path != "":
		set_cpu_path(cpu_path)

func _process(delta : float) -> void:
	if not cpu_node:
		return
	
	_dtime += delta
	var cycles = floor(_dtime * hertz)
	#print("DTime: ", _dtime, " | Cycles: ", cycles)
	if cycles > 0:
		_dtime -= cycles
		for _i in range(cycles):
			cpu_node.clock()


# --------------------------------------------------------------------------
# private Methods
# --------------------------------------------------------------------------


# --------------------------------------------------------------------------
# public Methods
# --------------------------------------------------------------------------
func enable(e : bool = true) -> void:
	set_process(e)

# --------------------------------------------------------------------------
# Handler Methods
# --------------------------------------------------------------------------

