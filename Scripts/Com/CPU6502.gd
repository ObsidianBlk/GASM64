extends Node
class_name CPU6502



# --------------------------------------------------------------------------
# Enums
# --------------------------------------------------------------------------
enum CYCLE_STATE {INST=0, MODE=1, ADDR=2, OP=3, RESET=4}
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
var _cycle_state = CYCLE_STATE.RESET
var _IRQ : bool = false
var _NMI : bool = false

var _fetched : int = 0
var _opcode : int = -1
var _opcycles : int = 0
var _opbytes : int = 0

var _cycle : int = 1
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
	match _cycle:
		2:
			_addr = (_fetched + _Reg[R.X]) & 0x00FF
		_:
			return true
	return false

func _AddrZeroPageY() -> bool:
	match _cycle:
		2:
			_addr = (_fetched + _Reg[R.Y]) & 0x00FF
		_:
			return true
	return false

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
	set_flag(FLAG.Z, _fetched == 0)
	set_flag(FLAG.N, _fetched & 0x80)

func _LDX() -> void:
	_Reg[R.X] = _fetched
	set_flag(FLAG.Z, _fetched == 0)
	set_flag(FLAG.N, _fetched & 0x80)

func _LDY() -> void:
	_Reg[R.Y] = _fetched
	set_flag(FLAG.Z, _fetched == 0)
	set_flag(FLAG.N, _fetched & 0x80)

func _STA() -> void:
	_Bus.write(_addr, _Reg[R.A])

func _STX() -> void:
	_Bus.write(_addr, _Reg[R.X])

func _STY() -> void:
	_Bus.write(_addr, _Reg[R.Y])

func _TAX() -> void:
	_Reg[R.X] = _Reg[R.A]
	set_flag(FLAG.Z, _Reg[R.X] == 0)
	set_flag(FLAG.N, _Reg[R.X] & 0x80)

func _TAY() -> void:
	_Reg[R.Y] = _Reg[R.A]
	set_flag(FLAG.Z, _Reg[R.Y] == 0)
	set_flag(FLAG.N, _Reg[R.Y] & 0x80)

func _TXA() -> void:
	_Reg[R.A] = _Reg[R.X]
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _TYA() -> void:
	_Reg[R.A] = _Reg[R.Y]
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _TXS() -> void:
	_Reg[R.STK] = _Reg[R.X]

func _TSX() -> void:
	_Reg[R.X] = _Reg[R.STK]
	set_flag(FLAG.Z, _Reg[R.X] == 0)
	set_flag(FLAG.N, _Reg[R.X] & 0x80)

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
	match _Reg[R.STK]:
		0xFF:
			_Reg[R.STK] = 0
		_:
			_Reg[R.STK] += 1
	_Reg[R.A] = _Bus.read(0x0100 | _Reg[R.STK])
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _PLP() -> void:
	match _Reg[R.STK]:
		0xFF:
			_Reg[R.STK] = 0
		_:
			_Reg[R.STK] += 1
	_Reg[R.FLAGS] = _Bus.read(0x0100 | _Reg[R.STK])

func _AND() -> void:
	_Reg[R.A] = _Reg[R.A] & _fetched
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _EOR() -> void:
	_Reg[R.A] = _Reg[R.A] ^ _fetched
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _ORA() -> void:
	_Reg[R.A] = _Reg[R.A] | _fetched
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _BIT() -> void:
	var res = _Reg[R.A] & _fetched
	set_flag(FLAG.Z, res == 0)
	_Reg[R.FLAGS] = (_Reg[R.FLAGS] & ~0x20) | (_fetched & 0x20) # Setting Bit 6
	_Reg[R.FLAGS] = (_Reg[R.FLAGS] & ~0x40) | (_fetched & 0x40) # Setting Bit 7

func _ADC() -> void:
	var r = _Reg[R.A] + _fetched + get_flag(FLAG.C)
	set_flag(FLAG.C, r & 0x100)
	var overflow : bool = (_Reg[R.A] & 0x80) == (_fetched & 0x80) && (_fetched & 0x80) != (r & 0x80)
	set_flag(FLAG.V, overflow)
	_Reg[R.A] = r & 0xFF
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _SBC() -> void:
	# NOTE: ((_fetched & 0x00FF) ^ 0x00FF) = _fetched inverted
	#  Based on an idea from https://www.youtube.com/watch?v=8XmxKPJDGU0&t=3141s
	var r = _Reg[R.A] + ((_fetched & 0x00FF) ^ 0x00FF) + get_flag(FLAG.C)
	set_flag(FLAG.C, r & 0x100)
	var overflow : bool = (_Reg[R.A] & 0x80) == (_fetched & 0x80) && (_fetched & 0x80) != (r & 0x80)
	set_flag(FLAG.V, overflow)
	_Reg[R.A] = r & 0xFF
	set_flag(FLAG.Z, _Reg[R.A] == 0)
	set_flag(FLAG.N, _Reg[R.A] & 0x80)

func _CMP() -> void:
	var r = _Reg[R.A] - _fetched
	set_flag(FLAG.C, r & 0x100)
	set_flag(FLAG.Z, r == 0)
	set_flag(FLAG.N, (r & 0x80))

func _CPX() -> void:
	var r = _Reg[R.X] - _fetched
	set_flag(FLAG.C, r & 0x100)
	set_flag(FLAG.Z, r == 0)
	set_flag(FLAG.N, (r & 0x80))

func _CPY() -> void:
	var r = _Reg[R.Y] - _fetched
	set_flag(FLAG.C, r & 0x100)
	set_flag(FLAG.Z, r == 0)
	set_flag(FLAG.N, (r & 0x80))

func _INC() -> void:
	var r = (_fetched + 1) & 0xFF
	var uf = (_fetched & 0xFF00) >> 8
	if _addr >= 0:
		if uf != r :
			_fetched = _fetched | (r << 8)
		else:
			set_flag(FLAG.Z, uf == 0)
			set_flag(FLAG.N, uf & 0x80)
			_Bus.write(_addr, uf)
			_addr = -1

func _INX() -> void:
	_Reg[R.X] = (_Reg[R.X] + 1) & 0xFF
	set_flag(FLAG.Z, _Reg[R.X] == 0)
	set_flag(FLAG.N, _Reg[R.X] & 0x80)

func _INY() -> void:
	_Reg[R.Y] = (_Reg[R.Y] + 1) & 0xFF
	set_flag(FLAG.Z, _Reg[R.Y] == 0)
	set_flag(FLAG.N, _Reg[R.Y] & 0x80)

func _DEC() -> void:
	var r = (_fetched - 1) & 0xFF
	var uf = (_fetched & 0xFF00) >> 8
	if _addr >= 0:
		if uf != r :
			_fetched = _fetched | (r << 8)
		else:
			set_flag(FLAG.Z, uf == 0)
			set_flag(FLAG.N, uf & 0x80)
			_Bus.write(_addr, uf)
			_addr = -1

func _DEX() -> void:
	_Reg[R.X] = (_Reg[R.X] - 1) & 0xFF
	set_flag(FLAG.Z, _Reg[R.X] == 0)
	set_flag(FLAG.N, _Reg[R.X] & 0x80)

func _DEY() -> void:
	_Reg[R.Y] = (_Reg[R.Y] - 1) & 0xFF
	set_flag(FLAG.Z, _Reg[R.Y] == 0)
	set_flag(FLAG.N, _Reg[R.Y] & 0x80)

func _ASL() -> void:
	match _opcode:
		0x0A: # Accumulator mode
			set_flag(FLAG.C, _Reg[R.A] & 0x80)
			_Reg[R.A] = (_Reg[R.A] << 1) & 0xFF
			set_flag(FLAG.Z, _Reg[R.A] == 0)
			set_flag(FLAG.N, _Reg[R.A] & 0x80)
		_: # All other addressing modes! We're working with a memory address here!
			var oc = _opcycles - _cycle
			match oc:
				2:
					set_flag(FLAG.C, _fetched & 0x80)
					_fetched = (_fetched << 1) & 0xFF
				1:
					set_flag(FLAG.Z, _fetched == 0)
					set_flag(FLAG.N, _fetched & 0x80)
					_Bus.write(_addr, _fetched)


func _LSR() -> void:
	match _opcode:
		0x4A: # Accumulator mode
			set_flag(FLAG.C, _Reg[R.A] & 0x01)
			_Reg[R.A] = (_Reg[R.A] >> 1) & 0xFF
			set_flag(FLAG.Z, _Reg[R.A] == 0)
			set_flag(FLAG.N, _Reg[R.A] & 0x80)
		_: # All other addressing modes! We're working with a memory address here!
			var oc = _opcycles - _cycle
			match oc:
				2:
					set_flag(FLAG.C, _fetched & 0x01)
					_fetched = (_fetched >> 1) & 0xFF
				1:
					set_flag(FLAG.Z, _fetched == 0)
					set_flag(FLAG.N, _fetched & 0x80)
					_Bus.write(_addr, _fetched)

func _ROL() -> void:
	match _opcode:
		0x2A: # Accumulator mode
			var c = _Reg[R.FLAGS] & 0x01
			set_flag(FLAG.C, _Reg[R.A] & 0x80)
			_Reg[R.A] = ((_Reg[R.A] << 1) & 0xFF) | c
			set_flag(FLAG.Z, _Reg[R.A] == 0)
			set_flag(FLAG.N, _Reg[R.A] & 0x80)
		_: # All other addressing modes! We're working with a memory address here!
			var oc = _opcycles - _cycle
			match oc:
				2:
					var c = _Reg[R.FLAGS] & 0x01
					set_flag(FLAG.C, _fetched & 0x80)
					_fetched = ((_fetched << 1) & 0xFF) | c
				1:
					set_flag(FLAG.Z, _fetched == 0)
					set_flag(FLAG.N, _fetched & 0x80)
					_Bus.write(_addr, _fetched)

func _ROR() -> void:
	match _opcode:
		0x6A: # Accumulator mode
			var c = _Reg[R.FLAGS] & 0x01
			set_flag(FLAG.C, _Reg[R.A] & 0x01)
			_Reg[R.A] = ((_Reg[R.A] >> 1) & 0xFF) | (c << 7)
			set_flag(FLAG.Z, _Reg[R.A] == 0)
			set_flag(FLAG.N, _Reg[R.A] & 0x80)
		_: # All other addressing modes! We're working with a memory address here!
			var oc = _opcycles - _cycle
			match oc:
				2:
					var c = _Reg[R.FLAGS] & 0x01
					set_flag(FLAG.C, _fetched & 0x01)
					_fetched = ((_fetched >> 1) & 0xFF) | (c << 7)
				1:
					set_flag(FLAG.Z, _fetched == 0)
					set_flag(FLAG.N, _fetched & 0x80)
					_Bus.write(_addr, _fetched)

func _JMP() -> void:
	_PC = _addr

func _JSR() -> void:
	var oc = _opcycles - _cycle
	match oc:
		2:
			_Bus.write(0x0100 | _Reg[R.STK], ((_PC - 1) & 0xFF00) >> 8)
			_Reg[R.STK] = (_Reg[R.STK] - 1) & 0xFF
		1:
			_Bus.write(0x0100 | _Reg[R.STK], (_PC - 1) & 0xFF)
			_Reg[R.STK] = (_Reg[R.STK] - 1) & 0xFF
		0:
			_PC = _addr

func _RTS() -> void:
	var oc = _opcycles - _cycle
	match oc:
		5:
			_Reg[R.STK] = (_Reg[R.STK] + 1) & 0xFF
		4:
			_addr = _Bus.read(0x0100 | _Reg[R.STK])
		3:
			_Reg[R.STK] = (_Reg[R.STK] + 1) & 0xFF
		2:
			_addr = _addr | (_Bus.read(0x0100 | _Reg[R.STK]) << 8)
		1:
			_PC = _addr
		0:
			_PC += 1

func _BCC() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x01 == 0:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BCS() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x01 == 1:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BEQ() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x02 == 0x02:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BMI() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x80 == 0x80:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BNE() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x02 != 0x02:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BPL() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x80 != 0x80:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BVC() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x40 != 0x40:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _BVS() -> void:
	match _cycle:
		2:
			if _Reg[R.FLAGS] & 0x40 == 0x40:
				_opcycles += 1
		3:
			_addr = _PC
			if _fetched & 0x80 == 0x80:
				_addr -= (_fetched ^ 0xFF) & 0xEF
			else:
				_addr += _fetched
			if (_addr & 0xFF00) != (_PC & 0xFF00):
				_opcycles += 1
			else:
				_PC = _addr
		4:
			_PC = _addr

func _CLC() -> void:
	set_flag(FLAG.C, 0)

func _CLD() -> void:
	set_flag(FLAG.D, 0)

func _CLI() -> void:
	set_flag(FLAG.I, 0)

func _CLV() -> void:
	set_flag(FLAG.V, 0)

func _SEC() -> void:
	set_flag(FLAG.C, 1)

func _SED() -> void:
	set_flag(FLAG.D, 1)

func _SEI() -> void:
	set_flag(FLAG.I, 1)

func _BRK() -> void:
	# NOTE: While this method is to handle the BRK instruction, it can also be
	#  used to handle NMI and IRQ interrupts as well
	match _cycle:
		2:
			set_flag(FLAG.B, 1)
			_Bus.write(0x0100 | _Reg[R.STK], (_PC & 0xFF00) >> 8)
			_Reg[R.STK] = (_Reg[R.STK] - 1) & 0xFF
		3:
			_Bus.write(0x0100 | _Reg[R.STK], (_PC & 0xFF) >> 8)
			_Reg[R.STK] = (_Reg[R.STK] - 1) & 0xFF
		4:
			_Bus.write(0x0100 | _Reg[R.STK], _Reg[R.FLAGS])
			_Reg[R.STK] = (_Reg[R.STK] - 1) & 0xFF
		5:
			if _NMI:
				_addr = _Bus.read(0xFFFA)
			else:
				_addr = _Bus.read(0xFFFE)
		6:
			if _NMI:
				_addr = _addr | (_Bus.read(0xFFFB) << 8)
			else:
				_addr = _addr | (_Bus.read(0xFFFF) << 8)
		7:
			if _NMI or _IRQ:
				_NMI = false
				_IRQ = false
				set_flag(FLAG.B, 0)
			else:
				set_flag(FLAG.B, 1)
			_PC = _addr

func _NOP() -> void:
	pass # HEY! It's already written!

func _RTI() -> void:
	match _cycle:
		2:
			_Reg[R.STK] = (_Reg[R.STK] + 1) & 0xFF
			_Reg[R.FLAGS] = _Bus.read(0x0100 | _Reg[R.STK])
		3:
			_Reg[R.STK] = (_Reg[R.STK] + 1) & 0xFF
			_PC = _Bus.read(0x0100 | _Reg[R.STK])
		4:
			_Reg[R.STK] = (_Reg[R.STK] + 1) & 0xFF
			_PC = _Bus.read(0x0100 | _Reg[R.STK]) << 8
		5:
			pass
		6:
			pass

# --------------------------------------------------------------------------
# Private Methods
# --------------------------------------------------------------------------

func _HandleReset() -> void:
	# NOTE: All of the values used in this cycle list is just
	#  me trying to match the sequence of events as defined...
	#  https://www.pagetable.com/?p=410
	#
	# Realistically, this is meaningless at the moment and all I really needed
	# to do was put in the final values, but, hell, I'll stay accurate for now.
	match _cycle:
		1:
			_Reg[R.STK] = 0
			_Reg[R.FLAGS] = 0x02
			_Reg[R.A] = 0xAA
			_Reg[R.X] = 0
			_Reg[R.Y] = 0
		4:
			_Reg[R.STK] = 0xFF
		5:
			_Reg[R.STK] = 0xFE
			_Reg[R.FLAGS] = 0x06
		6:
			_Reg[R.STK] = 0xFD
		7:
			_PC = _Bus.read(0xFFFC)
			_Reg[R.FLAGS] = 0x16
		8:
			_PC = _PC | (_Bus.read(0xFFFD) << 8)

func _Interrupted() -> bool:
	if _cycle_state == CYCLE_STATE.INST:
		if _NMI or _IRQ:
			return true
	return false

# --------------------------------------------------------------------------
# Public Methods
# --------------------------------------------------------------------------

func reset() -> void:
	_cycle_state = CYCLE_STATE.RESET
	_opcycles = 8
	_cycle = 1

func interrupt() -> void:
	if get_flag(FLAG.I) == 1:
		_IRQ = true

func nmi() -> void:
	_NMI = true

func clock() -> void:
	if not _Bus:
		return
	
	print ("6502 Cycle: ", _PC)
	if _Interrupted():
		_fetched = 0x00 # We're abusing the BRK instruction :D
		_cycle_state = CYCLE_STATE.INST
	elif _opbytes > 0 or _cycle_state == CYCLE_STATE.INST:
		_PC = (_PC + 1) & 0xFFFF
		_fetched = _Bus.read(_PC)
		_opbytes -= 1

	match _cycle_state:
		CYCLE_STATE.RESET:
			_opcycles = 8 # This is a whee hack. Do not touch!
			_HandleReset()
		CYCLE_STATE.INST:
			_opcode = _fetched
			_opcycles = GASM.get_op_cycles(_opcode)
			_opbytes = GASM.get_op_bytes(_opcode) - 1
			_cycle = 1
			_cycle_state = CYCLE_STATE.MODE
			#_addr = -1
		CYCLE_STATE.MODE:
			var mode = GASM.get_op_mode_id(_opcode)
			if mode >= 0 and mode in _AddrModeLUT:
				if call(_AddrModeLUT[mode]):
					_cycle_state = CYCLE_STATE.ADDR
			else:
				_cycle_state = CYCLE_STATE.OP

		CYCLE_STATE.ADDR:
			_Bus.read(_addr)
			_cycle_state = CYCLE_STATE.OP
	
	if _cycle_state == CYCLE_STATE.OP:
		var inst = "_" + GASM.get_op_asm_name(_opcode)
		print("Calling Op: ", inst, " | Cycles: ", _opcycles, " | Op Code: ", _opcode)
		if has_method(inst):
			call(inst)
	
	if _cycle == _opcycles:
		print("Instruction time!")
		_cycle_state = CYCLE_STATE.INST
	_cycle += 1

