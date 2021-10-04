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
	_ProcessNode(ast)
	return _errors.size() <= 0 and _compiled != null

func _ProcessNode(node : Dictionary):
	match node.type:
		Parser.ASTNODE.BLOCK:
			pass
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
			pass
		Parser.ASTNODE.INST:
			pass
		Parser.ASTNODE.DIRECTIVE:
			pass
	return null

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
		if typeof(val) != TYPE_INT and typeof(val) != TYPE_STRING:
			_StoreError("ASSIGNMENT only supports NUMBERS and STRINGS.", right.line, right.col)
			return
		_env.set_label(left.value, val)
	return

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

