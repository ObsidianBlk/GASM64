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
	INST,
	BINARY,
	ASSIGNMENT
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const BINOP_INFO = {
	Lexer.TOKEN.ASSIGN : {"presidence":1, "symbol":"="},
	Lexer.TOKEN.LT : {"presidence":7, "symbol":"<"},
	Lexer.TOKEN.LTE : {"presidence":7, "symbol":"<="},
	Lexer.TOKEN.GT : {"presidence":7, "symbol":">"},
	Lexer.TOKEN.GTE : {"presidence":7, "symbol":">="},
	Lexer.TOKEN.EQ : {"presidence":7, "symbol":"=="},
	Lexer.TOKEN.NEQ : {"presidence":7, "symbol":"!="},
	Lexer.TOKEN.PLUS : {"presidence":10, "symbol":"+"},
	Lexer.TOKEN.MINUS : {"presidence":10, "symbol":"-"},
	Lexer.TOKEN.MULT : {"presidence":20, "symbol":"*"},
	Lexer.TOKEN.DIV : {"presidence":20, "symbol":"/"}
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
func _StoreError(msg : String, line : int, col : int) -> void:
	_errors.append({
		"msg": msg,
		"line": line,
		"col": col
	})

func _BinaryPresidence(TokType : int) -> int:
	if TokType in BINOP_INFO:
		return BINOP_INFO[TokType].presidence
	return -1

func _BinarySymbol(TokType : int) -> String:
	if TokType in BINOP_INFO:
		return BINOP_INFO[TokType].symbol
	return ""

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

func _IsBinaryOperator() -> bool:
	var t = _PeekToken()
	return [
		Lexer.TOKEN.LT,
		Lexer.TOKEN.LTE,
		Lexer.TOKEN.GT,
		Lexer.TOKEN.GTE,
		Lexer.TOKEN.EQ,
		Lexer.TOKEN.NEQ,
		Lexer.TOKEN.ASSIGN,
		Lexer.TOKEN.DIV,
		Lexer.TOKEN.PLUS,
		Lexer.TOKEN.MINUS,
		Lexer.TOKEN.MULT
	].find(t.type) >= 0


func _ParseBlock(terminator : int = Lexer.TOKEN.EOF):
	var explist = []
	while not (_IsToken(terminator) or _IsToken(Lexer.TOKEN.EOF)) :
		var ex = _ParseExpression()
		if _errors.size() > 0:
			return null
		if ex != null:
			explist.append(ex)
	var tok = _ConsumeToken()
	if tok.type != terminator:
		_StoreError(
			"Unexpected end of block. Expected token " + _lexer.get_token_name(terminator) + ". Found End of Line",
			tok.line, tok.col
		)
		return null
	return {"type":ASTNODE.BLOCK, "expressions":explist}

func _ParseExpression():
	pass

func _ParseAtom():
	if _IsToken(Lexer.TOKEN.PAREN_L):
		_ConsumeToken()
		var expression = _ParseExpression()
		if _IsToken(Lexer.TOKEN.PAREN_R):
			_ConsumeToken()
			return expression
	elif _IsToken(Lexer.TOKEN.BLOCK_L):
		_ConsumeToken()
		return _ParseBlock(Lexer.TOKEN.BLOCK_R)
	elif _IsInstruction():
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
	_StoreError(
		"Unexpected Token Type: " + _lexer.get_token_name(t.type),
		t.line, t.col	
	)
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
		_StoreError(
			"Malformed number token.",
			t.line, t.col
		)
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
	var token = _PeekToken()
	var node = null
	# TODO: All of these should end with an EOL consumed!!
	match token.type:
		Lexer.TOKEN.EOL:
			_ConsumeToken()
			node = {"addr":GASM.MODES.IMM}
		Lexer.TOKEN.HASH:
			token = _ConsumeToken()
			var val = _ParseExpression()
			if val != null:
				node = {
					"addr": GASM.MODES.IMM,
					"value": val
				}
		Lexer.TOKEN.PAREN_L:
			_ConsumeToken()
			var val = _ParseAtom()
			if val != null:
				var tok = _ConsumeToken()
				if tok.type == Lexer.TOKEN.PAREN_R:
					tok = _PeekToken()
					if tok.type == Lexer.TOKEN.EOL:
						node = {"addr": GASM.MODES.IND, "value":val}
					elif tok.type == Lexer.TOKEN.COMMA:
						_ConsumeToken()
						# TODO: Complete me!!!
				if tok.type == Lexer.TOKEN.COMMA:
					tok = _ConsumeToken()
					if tok.type != Lexer.TOKEN.LABEL:
						_StoreError("Expected label identifier 'X'.", tok.line, tok.col)
					else:
						if tok.symbol.to_lower() != "x":
							_StoreError("Expected label identifier 'X'.", tok.line, tok.col)
						else:
							tok = _PeekToken()
							if tok.type != Lexer.TOKEN.PAREN_R:
								_StoreError("Unexpected token " + _lexer.get_token_name(tok.type), tok.line, tok.col)
							else:
								_ConsumeToken()
								node = {"addr": GASM.MODES.INDX, "value":val}
			else:
				_StoreError("Malformed Instruction addressing syntax.", token.line, token.col)
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
	return node

func _ParseDirectives():
	return null


func _MaybeBinary(ltok, pres : int):
	if ltok != null and _IsBinaryOperator():
		var tok = _ConsumeToken()
		var cpres = _BinaryPresidence(tok.type)
		if cpres > pres:
			var rtok = _MaybeBinary(_ParseAtom(), cpres)
			if rtok == null:
				return null
			var operator = _BinarySymbol(tok.type)
			return _MaybeBinary({
				"Type": ASTNODE.ASSIGNMENT if tok.type == Lexer.TOKEN.ASSIGN else ASTNODE.BINARY,
				"op": operator,
				"left": ltok,
				"right": rtok,
				"line": tok.line,
				"col": tok.col
			}, pres)
	return ltok


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func is_valid() -> bool:
	return false

func get_ast() -> void:
	pass


