extends Reference
class_name Parser


# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum ASTNODE {
	NUMBER,
	STRING,
	LABEL,
	BLOCK,
	INST
}


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _lexer : Lexer = null
var _tidx : int = 0

var _ast = null
var _errors = []

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------
func _init(lex : Lexer) -> void:
	if lex.is_valid():
		_lexer = lex
		_ast = _ParseBlock()


# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _TokenNumberToValue(token) -> int:
	var l = token.symbol.left(1)
	if l == "$":
		return GASM.hex_to_int(token.symbol.substr(1))
	elif l == "%":
		return Utils.binary_to_int(token.symbol.substr(1))
	return token.symbol.to_int()

func _ConsumeToken():
	var t = _lexer.get_token(_tidx)
	_tidx += 1
	return t

func _PeekToken(amount : int = 0):
	var idx = _tidx + amount
	if idx >= 0 and idx < _lexer.token_count():
		return _lexer.get_token(idx)
	return null

func _IsToken(type : int, sym : String = "") -> bool:
	var t = _PeekToken()
	if t.type == type:
		if sym == "" or sym == t.symbol:
			return true
	return false

func _IsInstruction() -> bool:
	var t = _PeekToken()
	if t.type == Lexer.TOKEN.LABEL:
		return GASM.is_op(t.symbol)
	return false

func _IsMathOperator() -> bool:
	var t = _PeekToken()
	return [Lexer.TOKEN.DIV, Lexer.TOKEN.PLUS, Lexer.TOKEN.MINUS, Lexer.TOKEN.MULT].find(t.type) >= 0


func _ParseBlock(terminator : int = Lexer.TOKEN.EOF):
	var explist = []
	while _PeekToken().type != terminator:
		var ex = _ParseExpression()
		if _errors.size() > 0:
			return null
		if ex != null:
			explist.append(ex)
	return {"type":ASTNODE.BLOCK, "expressions":explist}

func _ParseExpression():
	pass

func _ParseAtom():
	if _IsInstruction():
		return _ParseInstruction()
	elif _IsToken(Lexer.TOKEN.PERIOD):
		return _ParseDirectives()
	
	var t = _ConsumeToken()
	if t.type == Lexer.TOKEN.NUMBER:
		return _ParseNumber(t)
	elif t.type == Lexer.TOKEN.STRING:
		return _ParseString(t)
	elif t.type == Lexer.TOKEN.LABEL:
		return _ParseLabel(t)
	_errors.append({
		"msg": "Unexpected Token Type: " + _lexer.get_token_name(t.type),
		"line": t.line,
		"col": t.col
	})
	return null
		

func _ParseString(t):
	return {
		"type": ASTNODE.STRING,
		"value": t.symbol.substr(1, t.symbol.size() - 2),
		"line": t.line,
		"col": t.col
	}

func _ParseLabel(t):
	return {
		"type": ASTNODE.LABEL,
		"value": t.symbol,
		"line": t.line,
		"col": t.col
	}

func _ParseNumber(t):
	var l = t.symbol.left(1)
	var val = -1
	if l == "$":
		val = Utils.hex_to_int(t.symbol.substr(1))
	elif l == "%":
		val = Utils.binary_to_int(t.symbol.substr(1))
	else:
		val = t.symbol.to_int()
	if typeof(val) != TYPE_INT or val < 0:
		_errors.append({
			"msg": "Malformed number token.",
			"line": t.line,
			"col": t.col
		})
		return null
	return {
		"type":ASTNODE.NUMBER,
		"value": val,
		"line": t.line,
		"col": t.col
	}

func _ParseInstruction():
	var token = _PeekToken()
	if token.type == Lexer.TOKEN.LABEL:
		return null
	if not GASM.is_op(token.symbol):
		return null
	_ConsumeToken()
	var addr = _Addressing()
	# TODO: More Magic
	return null

func _Addressing():
	var token = _ConsumeToken()
	match token.type:
		Lexer.TOKEN.HASH:
			token = _ConsumeToken()
			match token.type:
				Lexer.TOKEN.LABEL:
					pass
				Lexer.TOKEN.NUMBER:
					pass
		Lexer.TOKEN.PAREN_L:
			pass
		Lexer.TOKEN.NUMBER:
			var val = _TokenNumberToValue(token)
			if val <= 0 or val > 0xFFFF:
				pass # Return an ERROR! Value is out of bounds
			token = _PeekToken()
			if token.type == Lexer.TOKEN.EOL:
				if val < 256:
					pass # Return Address Type ZERO PAGE
				# Return Address Type ABSOLUTE
		Lexer.TOKEN.LABEL:
			pass
	return null

func _ParseDirectives():
	return null

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func is_valid() -> bool:
	return false

func get_ast() -> void:
	pass


