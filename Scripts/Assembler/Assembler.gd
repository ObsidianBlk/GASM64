extends Reference
class_name Assembler

# ----------------------------------------------------------------------------
# Variables
# ----------------------------------------------------------------------------
var _parent : Assembler = null
var _env : Environ = null
var _lexer : Lexer = null
var _parser : Parser = null
var _ast : Dictionary = {}

var _errors = []

var _segments = {}
var _active_segment = ""

# ----------------------------------------------------------------------------
# Override Methods
# ----------------------------------------------------------------------------
func _init(parent : Assembler = null, ast : Dictionary = {}) -> void:
	if parent != null:
		_parent = parent
		_env = _parent.get_child_environment()
		if not ast.empty():
			_ast = ast
			process()
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

func _init_default_segments() -> void:
	if not _segments.empty():
		_segments.clear()
	
	for seg_name in GASM_Segment.get_default_segment_names():
		var seg = GASM_Segment.get_segment(seg_name)
		if seg.start >= 0 and seg.start <= 0xFF00:
			_add_segment(seg_name, seg.start, seg.bytes)
		else:
			print("WARNING: 'Default' segment '", seg_name, "' has invalid starting address.")

func _add_segment(seg_name : String, start_addr : int, bytes : int, auto_activate : bool = false) -> void:
	if not seg_name in _segments:
		_segments[seg_name] = {"start": start_addr, "bytes": bytes, "data": [], "PC": start_addr}
		if _active_segment == "" or auto_activate:
			_active_segment = seg_name


func _activate_segment(seg_name : String) -> void:
	if seg_name in _segments:
		_active_segment = seg_name

func _PC() -> int:
	if _active_segment == "":
		print("WARNING: Attempting to perform a PC adjustment without an active segment.")
		return -1
	return _segments[_active_segment].PC

func _movePC(amount : int) -> void:
	if _active_segment == "":
		print("WARNING: Attempting to perform a PC adjustment without an active segment.")
		return
	_segments[_active_segment].PC += amount


func _ProcessNode(node : Dictionary):
	match node.type:
		Parser.ASTNODE.BLOCK:
			return _ProcessBlock(node)
		Parser.ASTNODE.ASSIGNMENT:
			_ProcessAssignment(node)
		Parser.ASTNODE.BINARY:
			return _ProcessBinary(node)
		Parser.ASTNODE.HERE:
			return _PC()
			#return _env.PC()
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

#func _ProcessBlock(node : Dictionary):
#	var block = {
#		"elements": [],
#		"line": node.line,
#		"col": node.col
#	}
#	for ex in node.expressions:
#		var e = _ProcessNode(ex)
#		if _errors.size() <= 0:
#			if typeof(e) == TYPE_DICTIONARY:
#				if "elements" in e:
#					for item in e.elements:
#						block.elements.append(item)
#				else:
#					block.elements.append(e)
#		else:
#			return null
#	return block

func _ProcessBlock(node : Dictionary):
	for ex in node.expressions:
		var e = _ProcessNode(ex)
		if _errors.size() <= 0:
			if e != null:
				_segments[_active_segment].data.append(e)
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

# This version of the method allows HERE to be assigned to, which we do not want to allow anymore.
#func _ProcessAssignment(node : Dictionary) -> void:
#	var left = node.left
#	var right = node.right
#
#	if left.type != Parser.ASTNODE.LABEL and left.type != Parser.ASTNODE.HERE:
#		_StoreError("ASSIGNMENT expects LABEL or HERE as left-hand operand.", left.line, left.col)
#		return
#
#	var val = _ProcessNode(right)
#
#	if left.type == Parser.ASTNODE.HERE:
#		if typeof(val) != TYPE_INT:
#			_StoreError("Program Address cannot be assigned STRING.", right.line, right.col)
#			return
#		if val < 0 or val > 0xFFFF:
#			_StoreError("Program Address assignment is out of bounds.", right.line, right.col)
#			return
#		_env.PC(val)			
#	else:
#		if typeof(val) != TYPE_INT and typeof(val) != TYPE_STRING and typeof(val) != TYPE_BOOL:
#			_StoreError("ASSIGNMENT only supports NUMBERS, STRINGS, BOOLEANS.", right.line, right.col)
#			return
#		_env.set_label(left.value, val)
#	return

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

	if inst != null:
		_movePC(inst.data.size())
		#_env.PC_next(inst.data.size())
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
	#var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
		var here = _PC() #_env.PC()
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
	#var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
	
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
	#var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
	
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
	#var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
	#var inst = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var inst = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
	#var res = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var res = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
	for v in node.values:
		var val = _ProcessNode(v)
		if typeof(val) != TYPE_INT:
			_StoreError("Directive '.bytes' expects all values to evaluate to NUMBERS.", v.line, v.col)
			return null
		res.data.append(val)
	if res.data.size() > 0:
		_movePC(res.data.size())
		#_env.PC_next(res.data.size())
	return res

func _ProcessDirWords(node : Dictionary):
	var dbytes = node.directive == ".dbytes"
	#var res = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var res = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
	if res.data.size() > 0:
		_movePC(res.data.size())
		#_env.PC_next(res.data.size())
	return res

func _ProcessDirText(node : Dictionary):
	#var res = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var res = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
	if res.data.size() > 0:
		_movePC(res.data.size())
		#_env.PC_next(res.data.size())
	return res

func _ProcessDirFill(node : Dictionary):
	#var res = {"data":[], "line":node.line, "col":node.col, "PC":_env.PC()}
	var res = {"data":[], "line":node.line, "col":node.col, "PC":_PC()}
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
	if res.data.size() > 0:
		_movePC(res.data.size())
		#_env.PC_next(res.data.size())
	return res

func _ProcessDirImport(node : Dictionary):
	#var res = {"asm":null, "line":node.line, "col":node.col, "PC":_env.PC()}
	var res = {"asm":null, "line":node.line, "col":node.col, "PC":_PC()}
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
			_activate_segment(val)
		else:
			_add_segment(val, segment.start, segment.bytes, true)
	return null


# ----------------------------------------------------------------------------
# Public Methods
# ----------------------------------------------------------------------------
func is_assembled() -> bool:
	for seg_name in _segments.keys():
		if _segments[seg_name].data.size() > 0:
			return _errors.size() <= 0
	return _errors.size() <= 0


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

func process_from_source(source : String) -> bool:
	_lexer = Lexer.new(source)
	if _lexer.is_valid():
		_parser = Parser.new(_lexer)
		if _parser.is_valid():
			_ast = _parser.get_ast()
			return process()
	return false

func process() -> bool:
	if not _ast.empty():
		_init_default_segments()
		_ProcessNode(_ast)
	return false

func get_object():
	return null
	#return _compiled;

func get_binary_line(idx : int) -> Dictionary:
#	if _compiled:
#		for item in _compiled.elements:
#			if item.line == idx:
#				return {
#					"addr": item.PC,
#					"line": idx,
#					"data": PoolByteArray(item.data)
#				}
	return {"addr": -1, "line": 0, "data": null}

func get_binary_lines(start : int, end :int) -> Array:
	var lines = []
#	if _compiled and start >= 0 and end >= start:
#		if start == end:
#			return [get_binary_line(start)]
#		for item in _compiled.elements:
#			if item.line >= start and item.line <= end:
#				lines.append({
#					"addr": item.PC,
#					"line": item.line,
#					"data": PoolByteArray(item.data)
#				})
	return lines

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


