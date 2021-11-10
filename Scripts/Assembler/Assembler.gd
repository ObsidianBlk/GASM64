extends Reference
class_name Assembler

# ----------------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------------
var _parent : Assembler = null
var _env : Environ = null
var _segments : Segments = null
var _parser : Parser = null
var _ast : Dictionary = {}

var _errors = []

# ----------------------------------------------------------------------------
# Override Methods
# ----------------------------------------------------------------------------
func _init(parent : Assembler = null) -> void:
	_parser = Parser.new()
	if parent != null:
		_parent = parent
		_env = _parent.get_child_environment()
		_segments = _parent.get_segments()
	else:
		_env = Environ.new(Environ.new())
		_segments = Segments.new()


# ----------------------------------------------------------------------------
# Private Utility Methods
# ----------------------------------------------------------------------------
func _StoreError(msg : String, line : int, col : int, type : String = "ASSEMBLER") -> void:
	_errors.append({
		"type": type,
		"msg": msg,
		"line": line,
		"col": col
	})


# ----------------------------------------------------------------------------
# Private Process Methods
# ----------------------------------------------------------------------------

func _ProcessNode(node : Dictionary):
	match node.type:
		Parser.ASTNODE.BLOCK:
			return _ProcessBlock(node)
		Parser.ASTNODE.ASSIGNMENT:
			_ProcessAssignment(node)
		Parser.ASTNODE.BINARY:
			return _ProcessBinary(node)
		Parser.ASTNODE.HERE:
			return _segments.process_counter()
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
			return _ProcessDirective(node)
	return null


func _ProcessBlock(node : Dictionary):
	for ex in node.expressions:
		var e = _ProcessNode(ex)
		if _errors.size() <= 0:
			if e is Dictionary and "data" in e:
				_segments.push_data_line(e.data, get_instance_id(), e.line, e.col)
		else:
			break
	return null


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
	
	if left.type != Parser.ASTNODE.LABEL:
		_StoreError("ASSIGNMENT expects a LABEL as left-hand operand.", left.line, left.col)
		return
	
	var val = _ProcessNode(right)
	if typeof(val) != TYPE_INT and typeof(val) != TYPE_STRING and typeof(val) != TYPE_BOOL:
		_StoreError("ASSIGNMENT only supports NUMBERS, STRINGS, BOOLEANS.", right.line, right.col)
		return
	_env.set_label(left.value, val)


func _ProcessInstruction(node : Dictionary):
	var inst = null
	match node.addr:
		GASM.MODE.IMP, GASM.MODE.ACC:
			inst = _ProcessAddrIMP(node)
		GASM.MODE.IMM:
			inst = _ProcessAddrIMM(node)
		GASM.MODE.IND:
			inst = _ProcessAddrIND(node)
		GASM.MODE.INDX, GASM.MODE.INDY:
			inst = _ProcessAddrINDXY(node)
		GASM.MODE.ABS:
			if GASM.instruction_has_address_mode(node.inst, GASM.MODE.REL):
				inst = _ProcessAddrIMM(node) # Immediate mode also handles Relative mode. BECAUSE I SAID SO!
			else:
				# This handles Zero Page if value is or under 0xFF
				inst = _ProcessAddrABS(node)
		GASM.MODE.ABSX, GASM.MODE.ABSY:
			inst = _ProcessABSXY(node)

	return inst

func _ProcessAddrIMP(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	return inst

func _ProcessAddrIMM(node : Dictionary):
	var relmode = false
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		op = GASM.get_instruction_code(node.inst, GASM.MODE.REL)
		if op < 0:
			_StoreError(
				"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
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
		var here = _segments.process_counter()
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
	if val <= 0xFF and GASM.instruction_has_address_mode(node.inst, GASM.MODE.ZP):
		op = GASM.get_instruction_code(node.inst, GASM.MODE.ZP)
		inst.data.append(op)
		inst.data.append(val & 0xFF)
		return inst
	
	if val > 0xFFFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
		
	op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	inst.data.append((val & 0xFF00) >> 8)
	return inst

func _ProcessABSXY(node : Dictionary):
	var ZPT = GASM.MODE.ZPX if node.addr == GASM.MODE.ABSX else GASM.MODE.ZPY 
	var inst = {"data":[], "line":node.line, "col":node.col}
	
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_INT:
		_StoreError("Instruction requires a NUMBER value.", node.value.line, node.value.col)
		return null
	if val < 0:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
	
	var op = -1
	if val <= 0xFF and GASM.instruction_has_address_mode(node.inst, ZPT):
		op = GASM.get_instruction_code(node.inst, ZPT)
		inst.data.append(op)
		inst.data.append(val & 0xFF)
		return inst
	
	if val > 0xFFFF:
		_StoreError("Instruction value out of bounds.", node.value.line, node.value.col)
		return null
		
	op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
			node.line, node.col
		)
		return null
	inst.data.append(op)
	inst.data.append(val & 0xFF)
	inst.data.append((val & 0xFF00) >> 8)
	return inst

func _ProcessAddrIND(node : Dictionary):
	var inst = {"data":[], "line":node.line, "col":node.col}
	var op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
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
	var op = GASM.get_instruction_code(node.inst, node.addr)
	if op < 0:
		_StoreError(
			"Instruction '" + node.inst + "' does not support mode " + GASM.get_addr_mode_name(node.addr),
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

func _ProcessDirective(node : Dictionary):
	match node.directive:
		".segment":
			return _ProcessDirSegment(node)
		".bytes":
			return _ProcessDirBytes(node)
		".dbytes", ".words":
			return _ProcessDirWords(node)
		".text", ".ascii":
			return _ProcessDirText(node)
		".import":
			return _ProcessDirImport(node)
		".fill":
			return _ProcessDirFill(node)
	return null

func _ProcessDirBytes(node : Dictionary):
	var res = {"data":[], "line":node.line, "col":node.col}
	for v in node.values:
		var val = _ProcessNode(v)
		if typeof(val) != TYPE_INT:
			_StoreError("Directive '.bytes' expects all values to evaluate to NUMBERS.", v.line, v.col)
			return null
		res.data.append(val)
	return res

func _ProcessDirWords(node : Dictionary):
	var dbytes = node.directive == ".dbytes"
	var res = {"data":[], "line":node.line, "col":node.col}
	for v in node.values:
		var val = _ProcessNode(v)
		if typeof(val) != TYPE_INT:
			_StoreError("Directive '{dir}' expects all values to evaluate to NUMBERS.".format({"dir": node.directive}), v.line, v.col)
			return null
		if dbytes:
			res.data.append((val & 0xFF00) >> 8)
			res.data.append(val & 0xFF)
		else:
			res.data.append(val & 0xFF)
			res.data.append((val & 0xFF00) >> 8)
	return res

func _ProcessDirText(node : Dictionary):
	var res = {"data":[], "line":node.line, "col":node.col}
	for v in node.values:
		var val = _ProcessNode(v)
		if typeof(val) != TYPE_STRING:
			_StoreError("Directive '{dir}' expects all values to evaluate to STRINGS.".format({"dir": node.directive}), v.line, v.col)
			return null
		for i in range(val.length()):
			var cord = val.ord_at(i)
			if cord >= 0 and cord <= 0xFF:
				res.data.append(cord)
			else:
				res.data.append(32) # TODO: Do I really want to put a default "space" character here??!?!
	return res

func _ProcessDirFill(node : Dictionary):
	var res = {"data":[], "line":node.line, "col":node.col}
	var bytes = _ProcessNode(node.bytes)
	if typeof(bytes) != TYPE_INT:
		_StoreError("Directive '{dir}' expected byte count argument as NUMBER.".format({"dir": node.directive}), node.bytes.line, node.bytes.col)
		return null
	var val = 0
	if node.value != null:
		val = _ProcessNode(node.value)
		if typeof(bytes) != TYPE_INT:
			_StoreError("Directive '{dir}' expected value argument as NUMBER.".format({"dir": node.directive}), node.value.line, node.value.col)
			return null
		if val > 0xFF:
			_StoreError("Directive '{dir}' value argument out of bounds.".format({"dir": node.directive}), node.value.line, node.value.col)
			return null
	for _i in range(bytes):
		res.data.append(val)
	return res

func _ProcessDirImport(node : Dictionary):
	var res = {"asm":null, "line":node.line, "col":node.col}
	var paths = []
	for v in node.values:
		var path = _ProcessNode(v)
		if typeof(path) != TYPE_STRING:
			_StoreError("Directive '{dir}' expects all values to evaluate to STRINGS.".format({"dir": node.directive}), v.line, v.col)
			return null
		paths.append(path)
	if paths.size() > 0:
		var asms = []
		for path in paths:
			# TODO: Handle GASM project methodology then come back to me!
			pass
		if _errors.size() <= 0 and asms.size() > 0:
			res.asm = asms
			return res
	return null

func _ProcessDirSegment(node : Dictionary):
	var val = _ProcessNode(node.value)
	if typeof(val) != TYPE_STRING:
		_StoreError("Directive '{dir}' expects value to evaluate to a STRING.".format({"dir": node.directive}), node.value.line, node.value.col)
		return null
	var segment = GASM_Segment.get_segment(val)
	if segment.start >= 0:
		if val in _segments:
			_segments.set_activate_segment(val)
		else:
			_segments.add_segment(val, segment.start, segment.bytes, true)
	return null


# ----------------------------------------------------------------------------
# Public Methods
# ----------------------------------------------------------------------------
func is_assembled() -> bool:
	for seg_name in _segments.keys():
		if _segments[seg_name].data.size() > 0:
			return _errors.size() <= 0
	return _errors.size() <= 0

func get_root() -> Assembler:
	if _parent != null:
		return _parent.get_root()
	return self

func get_child_environment() -> Environ:
	return Environ.new(_env)


func get_segments() -> Segments:
	return _segments

func get_ast_buffer(include_debug_info : bool = false) -> PoolByteArray:
	if _parser and _parser.is_valid():
		return _parser.get_ast_buffer(include_debug_info)
	return PoolByteArray([])


func prime_source(source : String) -> bool:
	_errors.clear()
	var lexer : Lexer = Lexer.new(source)
	if lexer.is_valid():
		if _parser.parse(lexer):
			_ast = _parser.get_ast()
			return true
		else:
			for idx in range(_parser.error_count()):
				var err = _parser.get_error(idx)
				_StoreError(err.msg, err.line, err.col, "PARSER")
	else:
		var err = lexer.get_error_token()
		_StoreError(err.msg, err.line, err.col, "LEXER")
	return false


func prime_ast_buffer(buffer : PoolByteArray) -> bool:
	_errors.clear()
	if _parser.parse_ast_buffer(buffer):
		_ast = _parser.get_ast()
		return true
	else:
		for idx in range(_parser.error_count()):
			var err = _parser.get_error(idx)
			_StoreError(err.msg, err.line, err.col, "PARSER")
	return false


func process_from_source(source : String) -> bool:
	if prime_source(source):
		return process()
	return false


func process() -> bool:
	if not _ast.empty():
		if _parent == null:
			_segments.reset()
		_ProcessNode(_ast)
		if _errors.size() <= 0:
			return true
	return false


func get_binary_line(idx : int) -> Dictionary:
	return _segments.find_line_in_segments(get_instance_id(), idx)

func get_binary_lines(start : int, end :int) -> Array:
	return _segments.get_lines(get_instance_id(), start, end)

func get_binary() -> PoolByteArray:
	var data = []
#	if _compiled != null:
#		for item in _compiled.elements:
#			if "data" in item:
#				data.append_array(item.data)
	return PoolByteArray(data)

func print_binary(across : int = 8) -> void:
	var bin : PoolByteArray = get_binary()
	var line : String = ""
	for i in range(bin.size()):
		if i % across == 0 and line != "":
			print(line)
			line = ""
		if line == "":
			line += Utils.int_to_hex(bin[i], 2)
		else:
			line += " " + Utils.int_to_hex(bin[i], 2)
	if line != "":
		print(line)

func error_count() -> int:
	return _errors.size()

func get_error(idx : int):
	if idx >= 0 and idx < _errors.size():
		return {
			"type": _errors[idx].type,
			"msg": _errors[idx].msg,
			"line": _errors[idx].line,
			"col": _errors[idx].col
		}
	return null

func print_error(idx : int) -> void:
	if error_count() > 0:
		var err = get_error(idx)
		print(err.type, " ERROR [Line: ", err.line, ", Col: ", err.col, "]: ", err.msg)

func print_errors() -> void:
	for i in range(error_count()):
		print_error(i)


