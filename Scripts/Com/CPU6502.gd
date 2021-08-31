extends Node
class_name CPU6502



# --------------------------------------------------------------------------
# Enums
# --------------------------------------------------------------------------
enum R {A=0, X=1, Y=2, STK=3,FLAGS=4}
enum FLAG {C=0, Z=1, I=2, D=3, B=4, V=6, N=7}


# --------------------------------------------------------------------------
# Export Variables
# --------------------------------------------------------------------------
export var bus_node_path : NodePath = ""


# --------------------------------------------------------------------------
# Variables
# --------------------------------------------------------------------------

var _Bus : Bus = null


# Program Counter
var _PC : int = 0

# Registers (8-bit)
var _Reg = PoolByteArray([0,0,0,0,0])

# Address Mode Method Lookup Table
var _AddrModeLUP : Dictionary = {
	GASM.MODES.IMM: "",
	GASM.MODES.IMP: "",
	GASM.MODES.ACC: "",
	GASM.MODES.ABS: "_AddrAbsolute",
	GASM.MODES.ABSX: "",
	GASM.MODES.ABSY: "",
	GASM.MODES.ZP: "",
	GASM.MODES.ZPX: "",
	GASM.MODES.ZPY: "",
	GASM.MODES.IND: "",
	GASM.MODES.INDX: "",
	GASM.MODES.INDY: "",
	GASM.MODES.REL: ""
}

# Variables used for processing operations
var _fetched : int = 0
var _opcode : int = -1
var _opcycles : int = 0
var _opbytes : int = 0

var _cycle : int = 0
var _addr : int = 0
var _process_addr : bool = false
var _reladdr : int = 0

# --------------------------------------------------------------------------
# Setters / Getters
# --------------------------------------------------------------------------
func get_flag(f : int) -> int:
	var flg : int = _Reg[R.FLAGS]
	match f:
		FLAG.C:
			return flg & 0x01
		FLAG.Z:
			return (flg & 0x02) >> 1
		FLAG.I:
			return (flg & 0x04) >> 2
		FLAG.D:
			return (flg & 0x08) >> 3
		FLAG.B:
			return (flg & 0x10) >> 4
		FLAG.V:
			return (flg & 0x40) >> 6
		FLAG.N:
			return (flg & 0x80) >> 7
	return -1


func set_flag(f : int, v : int) -> void:
	v = max(0, min(1, v))
	var flg = _Reg[R.FLAGS]
	match f:
		FLAG.C:
			flg = (flg & ~0x01) | v
		FLAG.Z:
			flg = (flg & ~0x02) | (v << 1)
		FLAG.I:
			flg = (flg & ~0x04) | (v << 2)
		FLAG.D:
			flg = (flg & ~0x08) | (v << 3)
		FLAG.B:
			flg = (flg & ~0x10) | (v << 4)
		FLAG.V:
			flg = (flg & ~0x40) | (v << 6)
		FLAG.N:
			flg = (flg & ~0x80) | (v << 7)
	_Reg[R.FLAGS] = flg


# --------------------------------------------------------------------------
# Override Methods
# --------------------------------------------------------------------------
func _ready() -> void:
	var b = get_node_or_null(bus_node_path)
	if b is Bus:
		_Bus = b

# --------------------------------------------------------------------------
# Private Addressing Mode Methods
# --------------------------------------------------------------------------

func _AddrAbsolute() -> bool:
	if _cycle == 2:
		_addr = _fetched
	elif _cycle == 3:
		_addr = _addr | (_fetched << 8)
		return true
	return false

# --------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------

func clock() -> void:
	if not _Bus:
		return
	
	if _opbytes > 0 or _opcode < 0:
		_fetched = _Bus.read(_PC)
		_PC += 1
		_opbytes -= 1
	
	var mode = GASM.get_op_mode_id(_opcode)
	if _opcode < 0: # Grab next Op code
		_opcode = _fetched
		_opcycles = GASM.get_op_cycles(_opcode)
		_opbytes = GASM.get_op_bytes(_opcode) - 1
		_cycle = 1
		_addr = 0
		_process_addr = false
	elif mode >= 0 and _AddrModeLUP[mode] != "":
		if not _process_addr:
			_process_addr = call(_AddrModeLUP[mode])
		
		if _process_addr and _addr > 0:
			pass
	else:
		if _addr >= 0:
			_fetched = _Bus.read(_addr)
		# Handle OPeration
		
		_cycle += 1
		if _cycle == _opcycles:
			_opcode = -1

