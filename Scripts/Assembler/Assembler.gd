extends Reference
class_name Assembler

# ----------------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------------
var _parent : Assembler = null
var _env : Environ = null
var _lexer : Lexer = null
var _parser : Parser = null
var _initpc : int = 0

var _compiled = null
var _errors = []

# ----------------------------------------------------------------------------
# Override Methods
# ----------------------------------------------------------------------------
func _init(parent : Assembler = null, ast : Dictionary = {}) -> void:
	if parent != null:
		_parent = parent
		_env = _parent.get_child_environment()
		if ast != {}:
			_Compile(ast)
	else:
		_env = Environ.new()


# ----------------------------------------------------------------------------
# Private Methods
# ----------------------------------------------------------------------------
func _StoreError(msg : String, line : int, col : int) -> void:
	_errors.append({
		"msg": msg,
		"line": line,
		"col": col
	})

func _Compile(ast : Dictionary) -> bool:
	_compiled = _ProcessNode(ast)
	return _errors.size() <= 0 and _compiled != null

func _ProcessNode(node : Dictionary):
	match node.type:
		Parser.ASTNODE.BLOCK:
			return _ProcessBlock(node)
		Parser.ASTNODE.ASSIGNMENT:
			_ProcessAssignment(node)
		Parser.ASTNODE.BINARY:
			return _ProcessBinary(node)
		Parser.ASTNODE.HERE:
			return _env.PC()
		Parser.ASTNODE.LABEL:
			if _env.has_label(node.value):
				return _env.get_label(node.value)
		Parser.ASTNODE.STRING:
			return node.value
		Parser.ASTNODE.NUMBER:
			return node.value
		Parser.ASTNODE.HILO:
			return _ProcessHILO(node)
		Parser.ASTNODE.INST:
			return _ProcessInstruction(node)
		Parser.ASTNODE.DIRECTIVE:
			pass
	return null

func _ProcessBlock(node : Dictionary):
	var block = {
		"elements": [],
		"line": node.line,
		"col": node.col
	}
	for ex in node.expressions:
		var e = _ProcessNode(ex)
		if _errors.size() <= 0:
			if typeof(e) == TYPE_DICTIONARY:
				block.elements.append(e)
		else:
			return null
	return block


func _ProcessHILO(node : Dictionary):
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Operand expected to evaluate to a NUMBER.", node.value.line, node.value.col)
		return null
	if val < 0 or val > 0xFFFF:
		_StoreError("HILO word out of bounds.", node.value.line, node.value.col)
		return null
	if node.operator == "<":
		return (val & 0xFF)
	return (val & 0xFF00) >> 8

func _ProcessBinary(node : Dictionary):
	var left = node.left
	var right = node.right
	
	var lval = _ProcessNode(left)
	var rval = _ProcessNode(right)
	if ["+", "-", "/", "*"].find(node.op) >= 0:
		if typeof(lval) != TYPE_INT:
			_StoreError("Left-hand operand expected to evaluate to a NUMBER.", left.line, left.col)
			return null
		
		if typeof(rval) != TYPE_INT:
			_StoreError("Right-hand operand expected to evalute to a NUMBER.", right.line, right.col)
			return null
		
		match(node.op):
			"+":
				return lval + rval
			"-":
				return lval - rval
			"/":
				# TODO: Handle div-by-zero?
				return lval / rval
			"*":
				return lval * rval
	
	match node.op:
		"<":
			return lval < rval
		">":
			return lval > rval
		">=":
			return lval >= rval
		"<=":
			return lval <= rval
		"==":
			return lval == rval
		"!=":
			return lval != rval
	
	_StoreError("Unexpected error in BINARY operation.", node.line, node.col)
	return null

func _ProcessAssignment(node : Dictionary) -> void:
	var left = node.left
	var right = node.right
	
	if left.type != Parser.ASTNODE.LABEL and left.type != Parser.ASTNODE.HERE:
		_StoreError("ASSIGNMENT expects LABEL or HERE as left-hand operand.", left.line, left.col)
		return
	
	var val = _ProcessNode(right)

	if left.type == Parser.ASTNODE.HERE:
		if typeof(val) != TYPE_INT:
			_StoreError("Program Address cannot be assigned STRING.", right.line, right.col)
			return
		if val < 0 or val > 0xFFFF:
			_StoreError("Program Address assignment is out of bounds.", right.line, right.col)
			return
		_env.PC(val)			
	else:
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_STRING and typeof(val) != TYPE_BOOL:
			_StoreError("ASSIGNMENT only supports NUMBERS, STRINGS, BOOLEANS.", right.line, right.col)
			return
		_env.set_label(left.value, val)
	return

func _ProcessInstruction(node : Dictionary):
	var inst = null
	match node.addr:
		GASM.MODES.IMP, GASM.MODES.ACC:
			inst = _ProcessAddrIMP(node)
		GASM.MODES.IMM:
			inst = _ProcessAddrIMM(node)
		GASM.MODES.IND:
			inst = _ProcessAddrIND(node)
		GASM.MODES.INDX, GASM.MODES.INDY:
			inst = _ProcessAddrINDXY(node)
		GASM.MODES.ABS:
			if GASM.op_has_mode(node.inst, GASM.MODES.REL):
				inst = _ProcessAddrIMM(node) # Immediate mode also handles Relative mode. BECAUSE I SAID SO!
			else:
				# This handles Zero Page if value is or under 0xFF
				inst = _ProcessAddrABS(node)
		GASM.MODES.ABSX, GASM.MODES.ABSY:
			inst = _ProcessABSXY(node)

	if inst != null:
		_env.PC_next(inst.data.size())
	return inst

func _ProcessAddrIMP(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	return inst

func _ProcessAddrIMM(node : Dictionary):
	var relmode = false
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		op = GASM.get_opcode_from_name_and_mode(node.inst, GASM.MODES.REL)
		if op < 0:
			_StoreError(
				"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
				node.line, node.col
			)
			return null
		relmode = true
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0 or val > 0xFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	if relmode:
		var here = _env.PC()
		var off = val - here
		if off < -128 or off > 127:
			_StoreError("Relative address target is out of range.", node.value.line, node.value.col)
			return null
		val = abs(off)
		if off < 0:
			val = val ^ 0xFF
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	return inst


func _ProcessAddrABS(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col}
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	var op = -1
	if val <= 0xFF and GASM.op_has_mode(node.inst, GASM.MODES.ZP):
		op = GASM.get_opcode_from_name_and_mode(node.inst, GASM.MODES.ZP)
		inst.data.append(op)
		inst.data.append(val & 0xFF)
		return inst
	
	if val > 0xFFFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
		
	op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	inst.data.append((val & 0xFF00) >> 8)
	return inst

func _ProcessABSXY(node : Dictionary):
	var ZPT = GASM.MODES.ZPX if node.addr == GASM.MODES.ABSX else GASM.MODES.ZPY 
	var inst = {"data":[], "line":node.line, "col":node.col}
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	var op = -1
	if val <= 0xFF and GASM.op_has_mode(node.inst, ZPT):
		op = GASM.get_opcode_from_name_and_mode(node.inst, ZPT)
		inst.data.append(op)
		inst.data.append(val & 0xFF)
		return inst
	
	if val > 0xFFFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
		
	op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	inst.data.append((val & 0xFF00) >> 8)
	return inst

func _ProcessAddrIND(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
			node.line, node.col
		)
		return null
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0 or val > 0xFFFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	inst.data.append((val & 0xFF00) >> 8)
	return inst


func _ProcessAddrINDXY(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_opcode_from_name_and_mode(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_mode_name_from_ID(node.addr),
			node.line, node.col
		)
		return null
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0 or val > 0xFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	return inst

# ----------------------------------------------------------------------------
# Public Methods
# ----------------------------------------------------------------------------
func get_child_environment() -> Environ:
	return Environ.new(_env)

func get_parser() -> Parser:
	if _parent != null:
		return _parent.get_parser()
	return _parser

func get_lexer() -> Lexer:
	if _parent != null:
		return _parent.get_lexer()
	return _lexer

func process(source : String) -> bool:
	_lexer = Lexer.new(source)
	if _lexer.is_valid():
		_parser = Parser.new(_lexer)
		if _parser.is_valid():
			return _Compile(_parser.get_ast())
	return false

func get_object():
	return _compiled;

func get_binary() -> PoolByteArray:
	var data = []
	if _compiled != null:
		for item in _compiled.elements:
			if "data" in item:
				data.append_array(item.data)
	return PoolByteArray(data)

func print_binary(across : int = 8) -> void:
	var bin : PoolByteArray = get_binary()
	var line : String = ""
	for i in range(bin.size()):
		if i % across == 0 and line != "":
			print(line)
			line = ""
		if line == "":
			line += Utils.int_to_hex(bin[i])
		else:
			line += " " + Utils.int_to_hex(bin[i])
	if line != "":
		print(line)

func error_count() -> int:
	if _lexer and not _lexer.is_valid():
		return 1
	elif _parser and not _parser.is_valid():
		return _parser.error_count()
	return _errors.size()

func get_error(idx : int):
	if _lexer and not _lexer.is_valid():
		var err = _lexer.get_error_token()
		return {"type":"LEXER", "msg": err.msg, "line": err.line, "col": err.col}
	elif _parser and not _parser.is_valid():
		var err = _parser.get_error(idx)
		return {"type":"PARSER", "msg": err.msg, "line": err.line, "col": err.col}
	elif _errors.size() > 0:
		var err = null
		if idx >= 0 and idx < _errors.size():
			err = _errors[idx]
		if err == null:
			err = _errors[0]
		return {"type":"ASSEMBLER", "msg": err.msg, "line": err.line, "col": err.col}
	return null

func print_error(idx : int) -> void:
	if error_count() > 0:
		var err = get_error(idx)
		print(err.type, " ERROR [Line: ", err.line, ", Col: ", err.col, "]: ", err.msg)

func print_errors() -> void:
	for i in range(error_count()):
		print_error(i)


