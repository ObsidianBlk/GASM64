extends Node
class_name CPU6502



# --------------------------------------------------------------------------
# Enums
# --------------------------------------------------------------------------
enum CYCLE_STATE {INST=0, MODE=1, ADDR=2, OP=3}
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
var _AddrModeLUT : Dictionary = {
	GASM.MODES.ABS: "_AddrAbsolute",
	GASM.MODES.ABSX: "_AddrAbsoluteX",
	GASM.MODES.ABSY: "_AddrAbsoluteY",
	GASM.MODES.ZP: "_AddrZeroPage",
	GASM.MODES.ZPX: "_AddrZeroPageX",
	GASM.MODES.ZPY: "_AddrZeroPageY",
	GASM.MODES.IND: "_AddrIndirect",
	GASM.MODES.INDX: "_AddrXIndirect",
	GASM.MODES.INDY: "_AddrIndirectY"
}

# Variables used for processing operations
var _cycle_state = CYCLE_STATE.CODE

var _fetched : int = 0
var _opcode : int = -1
var _opcycles : int = 0
var _opbytes : int = 0

var _cycle : int = 0
var _addr : int = 0
#var _process_addr : bool = false
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
	match _cycle:
		2:
			_addr = _fetched
		3:
			_addr = _addr | (_fetched << 8)
			return true
	return false

func _AddrAbsoluteX() -> bool:
	match _cycle:
		2:
			_addr = (_fetched + _Reg[R.X]) & 0x00FF
		3:
			if _addr < _Reg[R.X]:
				_addr = _addr | ((_fetched + 1) << 8)
				_opcycles += 1
			else:
				_addr = _addr | (_fetched << 8)
				return true
		4:
			return true
	return false

func _AddrAbsoluteY() -> bool:
	match _cycle:
		2:
			_addr = (_fetched + _Reg[R.Y]) & 0x00FF
		3:
			if _addr < _Reg[R.Y]:
				_addr = _addr | ((_fetched + 1) << 8)
				_opcycles += 1
			else:
				_addr = _addr | (_fetched << 8)
				return true
		4:
			return true
	return false

func _AddrZeroPage() -> bool:
	_addr = _fetched & 0x00FF
	return true

func _AddrZeroPageX() -> bool:
	_addr = (_fetched + _Reg[R.X]) & 0x00FF
	return true

func _AddrZeroPageY() -> bool:
	_addr = (_fetched + _Reg[R.Y]) & 0x00FF
	return true

func _AddrIndirect() -> bool:
	match _cycle:
		2:
			_reladdr = _fetched
		3:
			_reladdr = _reladdr | (_fetched << 8)
		4:
			_addr = _Bus.read(_reladdr)
		5:
			_addr = _addr | (_Bus.read(_reladdr+1) << 8)
			return true
	return false

func _AddrXIndirect() -> bool:
	match _cycle:
		2:
			_reladdr = (_fetched + _Reg[R.X]) & 0x00FF
		3:
			_addr = _Bus.read(_reladdr)
		4:
			_addr = _addr | (_Bus.read((_reladdr + 1) & 0x00FF) << 8)
			return true
	return false

func _AddrIndirectY() -> bool:
	match _cycle:
		2:
			_reladdr = (_fetched + _Reg[R.Y]) & 0x00FF
		3:
			_addr = _Bus.read(_reladdr)
		4:
			if _reladdr < _Reg[R.Y]:
				_addr = _addr | (((_Bus.read((_reladdr + 1) & 0x00FF) + 1) & 0xFF) << 8)
			else:
				_addr = _addr | (_Bus.read((_reladdr + 1) & 0x00FF) << 8)
				return true
		5:
			return true
	return false

# --------------------------------------------------------------------------
# Private Instruction Methods
# --------------------------------------------------------------------------
func _LDA() -> void:
	_Reg[R.A] = _fetched
	set_flag(FLAG.Z, 1 if _fetched == 0 else 0)
	set_flag(FLAG.N, 1 if _fetched & 0x80 == 0x80 else 0)

func _LDX() -> void:
	_Reg[R.X] = _fetched
	set_flag(FLAG.Z, 1 if _fetched == 0 else 0)
	set_flag(FLAG.N, 1 if _fetched & 0x80 == 0x80 else 0)

func _LDY() -> void:
	_Reg[R.Y] = _fetched
	set_flag(FLAG.Z, 1 if _fetched == 0 else 0)
	set_flag(FLAG.N, 1 if _fetched & 0x80 == 0x80 else 0)

func _STA() -> void:
	_Bus.write(_addr, _Reg[R.A])

func _STX() -> void:
	_Bus.write(_addr, _Reg[R.X])

func _STY() -> void:
	_Bus.write(_addr, _Reg[R.Y])

func _TAX() -> void:
	_Reg[R.X] = _Reg[R.A]
	set_flag(FLAG.Z, 1 if _Reg[R.X] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.X] & 0x80 == 0x80 else 0)

func _TAY() -> void:
	_Reg[R.Y] = _Reg[R.A]
	set_flag(FLAG.Z, 1 if _Reg[R.Y] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.Y] & 0x80 == 0x80 else 0)

func _TXA() -> void:
	_Reg[R.A] = _Reg[R.X]
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _TYA() -> void:
	_Reg[R.A] = _Reg[R.Y]
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _TXS() -> void:
	_Reg[R.STK] = _Reg[R.X]

func _TSX() -> void:
	_Reg[R.X] = _Reg[R.STK]
	set_flag(FLAG.Z, 1 if _Reg[R.X] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.X] & 0x80 == 0x80 else 0)

func _PHA() -> void:
	_Bus.write(0x0100 | _Reg[R.STK], _Reg[R.A])
	match _Reg[R.STK]:
		0:
			_Reg[R.STK] = 0xFF
		_:
			_Reg[R.STK] -= 1

func _PHP() -> void:
	_Bus.write(0x0100 | _Reg[R.STK], _Reg[R.FLAGS])
	match _Reg[R.STK]:
		0:
			_Reg[R.STK] = 0xFF
		_:
			_Reg[R.STK] -= 1

func _PLA() -> void:
	_Reg[R.A] = _Bus.read(0x0100 | _Reg[R.STK])
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)
	match _Reg[R.STK]:
		0xFF:
			_Reg[R.STK] = 0
		_:
			_Reg[R.STK] += 1

func _PLP() -> void:
	_Reg[R.FLAGS] = _Bus.read(0x0100 | _Reg[R.STK])
	match _Reg[R.STK]:
		0xFF:
			_Reg[R.STK] = 0
		_:
			_Reg[R.STK] += 1

func _AND() -> void:
	_Reg[R.A] = _Reg[R.A] & _fetched
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _EOR() -> void:
	_Reg[R.A] = _Reg[R.A] ^ _fetched
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _ORA() -> void:
	_Reg[R.A] = _Reg[R.A] | _fetched
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _BIT() -> void:
	var res = _Reg[R.A] & _fetched
	set_flag(FLAG.Z, 1 if res == 0 else 0)
	_Reg[R.FLAGS] = (_Reg[R.FLAGS] & ~0x20) | (_fetched & 0x20) # Setting Bit 6
	_Reg[R.FLAGS] = (_Reg[R.FLAGS] & ~0x40) | (_fetched & 0x40) # Setting Bit 7

func _ADC() -> void:
	var r = _Reg[R.A] + _fetched + get_flag(FLAG.C)
	set_flag(FLAG.C, 1 if r > 255 else 0)
	var overflow : bool = (_Reg[R.A] & 0x80) == (_fetched & 0x80) && (_fetched & 0x80) != (r & 0x80)
	set_flag(FLAG.V, 1 if overflow else 0)
	_Reg[R.A] = r & 0xFF
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _SBC() -> void:
	var r = _Reg[R.A] + ((_fetched & 0x00FF) ^ 0x00FF) + get_flag(FLAG.C)
	set_flag(FLAG.C, 1 if r > 255 else 0)
	var overflow : bool = (_Reg[R.A] & 0x80) == (_fetched & 0x80) && (_fetched & 0x80) != (r & 0x80)
	set_flag(FLAG.V, 1 if overflow else 0)
	_Reg[R.A] = r & 0xFF
	set_flag(FLAG.Z, 1 if _Reg[R.A] == 0 else 0)
	set_flag(FLAG.N, 1 if _Reg[R.A] & 0x80 == 0x80 else 0)

func _CMP() -> void:
	pass

func _CPX() -> void:
	pass

func _CPY() -> void:
	pass

func _INC() -> void:
	pass

func _INX() -> void:
	pass

func _INY() -> void:
	pass

func _DEC() -> void:
	pass

func _DEX() -> void:
	pass

func _DEY() -> void:
	pass

func _ASL() -> void:
	pass

func _LSR() -> void:
	pass

func _ROL() -> void:
	pass

func _ROR() -> void:
	pass

func _JMP() -> void:
	pass

func _JSR() -> void:
	pass

func _RTS() -> void:
	pass

func _BCC() -> void:
	pass

func _BCS() -> void:
	pass

func _BEQ() -> void:
	pass

func _BMI() -> void:
	pass

func _BNE() -> void:
	pass

func _BPL() -> void:
	pass

func _BVC() -> void:
	pass

func _BVS() -> void:
	pass

func _CLC() -> void:
	pass

func _CLD() -> void:
	pass

func _CLI() -> void:
	pass

func _CLV() -> void:
	pass

func _SEC() -> void:
	pass

func _SED() -> void:
	pass

func _SEI() -> void:
	pass

func _BRK() -> void:
	pass

func _NOP() -> void:
	pass

func _RTI() -> void:
	pass


# --------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------

func clock() -> void:
	if not _Bus:
		return
	
	if _opbytes > 0 or _cycle_state == CYCLE_STATE.CODE:
		_fetched = _Bus.read(_PC)
		_PC += 1
		_opbytes -= 1

	match _cycle_state:
		CYCLE_STATE.INST:
			_opcode = _fetched
			_opcycles = GASM.get_op_cycles(_opcode)
			_opbytes = GASM.get_op_bytes(_opcode) - 1
			_cycle = 1
			#_addr = -1
		CYCLE_STATE.MODE:
			var mode = GASM.get_op_mode_id(_opcode)
			if mode >= 0 and _AddrModeLUT[mode] != "":
				if call(_AddrModeLUT[mode]):
					_cycle_state = CYCLE_STATE.ADDR
			else:
				_cycle_state = CYCLE_STATE.OP

		CYCLE_STATE.ADDR:
			_Bus.read(_addr)
			_cycle_state = CYCLE_STATE.OP
	
	if _cycle_state == CYCLE_STATE.OP:
		var inst = "_" + GASM.get_op_asm_name(_opcode)
		if has_method(inst):
			call(inst)
	
	if _cycle == _opcycles:
		_cycle_state = CYCLE_STATE.INST
	_cycle += 1

