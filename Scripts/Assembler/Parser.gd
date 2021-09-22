extends Reference
class_name Parser


# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum ASTNODE {
	BLOCK,
	ADDR_ACC,
	ADDR_IMP,
	ADDR_IMM,
	ADDR_IND,
	ADDR_INDX,
	ADDR_INDY,
	ADDR_LBL,
	ADDR_ABS,
	ADDR_ZP,
	ADDR_REL
}


# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _lexer : Lexer = null
var _tidx : int = 0

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------
func _init(lex : Lexer) -> void:
	if lex.is_valid():
		_lexer = lex
		_Parse()


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

func _Parse() -> void:
	pass

func _Instruction():
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

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func is_valid() -> bool:
	return false

func get_ast() -> void:
	pass


