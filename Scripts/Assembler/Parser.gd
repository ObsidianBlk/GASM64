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
	ASSIGNMENT,
	CALL
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
var _tidx_mem : int = -1

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

func _RememberToken() -> void:
	_tidx_mem = _tidx

func _RecallToken() -> bool:
	if _tidx_mem >= 0 and _tidx_mem < _lexer.token_count():
		_tidx = _tidx_mem
		return true
	return false

func _IsToken(type : int, sym : String = "", consume_on_true : bool = false) -> bool:
	var t = _PeekToken()
	if t.type == type:
		if sym == "" or sym == t.symbol:
			if consume_on_true:
				_ConsumeToken()
			return true
	return false

func _IsTokenConsume(type : int, sym : String = "") -> bool:
	return _IsToken(type, sym, true)

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


func _ParseBlock(terminator : int = Lexer.TOKEN.EOF, ignoreEOL : bool = false):
	var explist = []
	while not (_IsToken(terminator) or _IsToken(Lexer.TOKEN.EOF)) :
		if _IsTokenConsume(Lexer.TOKEN.EOL): # Just skip empty lines
			continue
		var ex = _ParseExpression()
		if _errors.size() > 0:
			return null
		if ex != null:
			explist.append(ex)
		if not ignoreEOL:
			if not _IsTokenConsume(Lexer.TOKEN.EOL):
				var token = _PeekToken()
				_StoreError("Expected end of line.", token.line, token.col)
				return null
	var tok = _ConsumeToken()
	if tok.type != terminator:
		_StoreError(
			"Unexpected end of block. Expected token " + _lexer.get_token_name(terminator) + ". Found End of Line",
			tok.line, tok.col
		)
		return null
	return {"type":ASTNODE.BLOCK, "expressions":explist}

func _ParseDelimited(stype : int, etype : int, dtype : int, parse_func : String):
	var toEOL = (stype < 0 or etype < 0)
	var el = []
	var first = true
	var token = _ConsumeToken()
	if not toEOL:
		if token.type != stype:
			_StoreError("Unexpected token type " + _lexer.get_token_name(token.type) + ".", token.line, token.col)
			return null
		token = _ConsumeToken()
	while ((not token.type == Lexer.TOKEN.EOF) and (not toEOL and token.type != etype)) or (toEOL and token.type == Lexer.TOKEN.EOL):
		if not first:
			if token.type != dtype:
				_StoreError("Unexpected token type " + _lexer.get_token_name(token.type) + ".", token.line, token.col)
				return null
			token = _ConsumeToken()
		first = false
		var e = call(parse_func)
		if e != null:
			el.push(e)
		elif _errors.size() > 0:
			return null
		token = _ConsumeToken()
	if not toEOL:
		if token.type != etype:
			_StoreError("Unexpected token type " + _lexer.get_token_name(token.type) + ".", token.line, token.col)
			return null
	return el

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
	_RememberToken()
	var token = _ConsumeToken()
	if token.type != Lexer.TOKEN.LABEL:
		return null
	if not GASM.is_op(token.symbol):
		return null
	var addr = _Addressing()
	if addr != null:
		return {
			"type": ASTNODE.INST,
			"inst": token.symbol.to_upper(),
			"addr": addr.addr,
			"value": null if not ("value" in addr) else addr.value,
			"line": token.line,
			"col": token.col
		}
	_RecallToken()
	return null


func _AddrImplied():
	var token = _PeekToken()
	if token.type == Lexer.TOKEN.EOL:
		return {"addr":GASM.MODES.IMP}
	elif token.type == Lexer.TOKEN.LABEL and token.symbol.to_lower() == "a":
		_ConsumeToken()
		return {"addr":GASM.MODES.ACC}
	else:
		_StoreError("Unexpected token " + _lexer.get_token_name(token.type) + ".", token.line, token.col)
	return null

func _AddrImmediate():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type == Lexer.TOKEN.HASH:
		var val = _ParseAtom()
		if val != null:
			return {"addr":GASM.MODES.IMM, "value":val}
	_RecallToken()
	return null

func _AddrIndirect():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type == Lexer.TOKEN.PAREN_L:
		var val = _ParseAtom()
		if val != null:
			token = _ConsumeToken()
			if token.type == Lexer.TOKEN.PAREN_R:
				return {"addr": GASM.MODES.IND, "value":val}
			# NOTE: If the above IF is false, this is NOT neccessarily a syntax error.
			# This could be an INDX or INDY situation.
	_RecallToken()
	return null

func _AddrIndX():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type == Lexer.TOKEN.PAREN_L:
		var val = _ParseAtom()
		if val != null:
			token = _ConsumeToken()
			if token.type == Lexer.TOKEN.COMMA:
				token = _ConsumeToken()
				if token.type == Lexer.TOKEN.LABEL and token.symbol.to_lower() == "x":
					# NOTE: The COMMA and LABEL tokens can fail without it being an error.
					# However, if they pass, then the PAREN_R and EOL ~MUST~ also follow to be
					# Syntactically correct!
					token = _ConsumeToken()
					if token.type == Lexer.TOKEN.PAREN_R:
						return {"addr": GASM.MODES.INDX, "value":val}
					else:
						_StoreError("Syntax Error! Expected PAREN_R token.", token.line, token.col)
	_RecallToken()
	return null

func _AddrIndY():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type == Lexer.TOKEN.PAREN_L:
		var val = _ParseAtom()
		if val != null:
			token = _ConsumeToken()
			if token.type == Lexer.TOKEN.PAREN_R:
				token = _ConsumeToken()
				if token.type == Lexer.TOKEN.COMMA:
					token = _ConsumeToken()
					if token.type == Lexer.TOKEN.LABEL and token.symbol.to_lower() == "y":
						# NOTE: The PAREN_R, COMMA, and LABEL tokens can fail without it being an error.
						# However, if they pass, then EOL ~MUST~ also follow to be Syntactically correct!
						return {"addr": GASM.MODES.INDY, "value":val}
	_RecallToken()
	return null


func _AddrAbs():
	# NOTE: This will handle both "Absolute" and "Zero Page" with X and Y variants.
	# This is due to the fact that which mode is completely dependant on the resulting
	# value and NOT the structure of the address mode.
	# Given that the value may be undetermined until a later stage, there is no way
	# to know for sure which address more we're working with.
	# As such, only ABS, ABSX, and ABSY will result on success.
	_RememberToken()
	var val = _ParseAtom()
	if val != null:
		var token = _PeekToken() # We don't actually want to consume an EOL, so let's peek first.
		if token.type == Lexer.TOKEN.COMMA:
			_ConsumeToken()
			token = _ConsumeToken()
			if token.type == Lexer.TOKEN.LABEL:
				var sym = token.symbol.to_lower()
				if sym == "x" or sym == "y":
					return {
						"addr" : GASM.MODES.ABSX if sym == "x" else GASM.MODES.ABSY,
						"value":val
					}
				else:
					_StoreError("Syntax Error! Expected LABEL token of 'X' or 'Y'.", token.line, token.col)
			else:
				_StoreError("Syntax Error! Expected LABEL token of 'X' or 'Y'.", token.line, token.col)
		elif token.type == Lexer.TOKEN.EOL:
			return {"addr":GASM.MODES.ABS, "value":val}
	_RecallToken()
	return null



func _Addressing():
	var token = _PeekToken()
	# TODO: All of these should end with an EOL consumed!!
	match token.type:
		Lexer.TOKEN.EOL:
			return _AddrImplied()
		Lexer.TOKEN.HASH:
			return _AddrImmediate()
		Lexer.TOKEN.PAREN_L:
			var node = _AddrIndirect()
			if node != null or _errors.size() > 0:
				return node
			
			node = _AddrIndX()
			if node != null or _errors.size() > 0:
				return node
			
			node = _AddrIndY()
			if node != null or _errors.size() > 0:
				return node
			
			node = _AddrAbs()
			if node != null or _errors.size() > 0:
				return node
			_StoreError("Syntax Error! Instruction addressing is malformed.", token.line, token.col)
		Lexer.TOKEN.NUMBER:
			return _AddrAbs()
		Lexer.TOKEN.LABEL:
			var node = _AddrImplied() # This will check for "Accumulator" addressing
			if node != null or _errors.size() > 0:
				return node
			
			return _AddrAbs()
		_:
			_StoreError("Syntax Error! Unexpected token.", token.line, token.col)
	return null

func _ParseDirectives():
	return null

func _ParseCall(f):
	var args = _ParseDelimited(Lexer.TOKEN.PAREN_L, Lexer.TOKEN.PAREN_R, Lexer.TOKEN.COMMA, "_ParseExpression")
	if args != null:
		return {
			"type": ASTNODE.CALL,
			"func": f,
			"args": args
		}
	return null

func _ParseExpression():
	var expr = _MaybeBinary(_ParseAtom(), 0)
	if expr != null:
		var token = _PeekToken()
		if token.type == Lexer.TOKEN.PAREN_L:
			return _ParseCall(expr)
	return expr

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
	return _ast != null and _errors.size() <= 0

func get_ast():
	return _ast

func error_count() -> int:
	return _errors.size()

func get_error(i : int):
	if i >= 0 and i < _errors.size():
		return _errors[i]
	return null

func get_errors():
	return _errors

