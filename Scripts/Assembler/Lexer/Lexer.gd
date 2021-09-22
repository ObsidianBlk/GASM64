extends Reference
class_name Lexer

# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum TOKEN {
	ERROR=-1,
	LABEL,
	NUMBER,
	HERE,
	PAREN_L,
	PAREN_R,
	BLOCK_L,
	BLOCK_R,
	COMMA,
	PERIOD,
	QUOTE,
	COLON,
	EQ,
	PLUS,
	MINUS,
	DIV,
	MULT,
	EOL,
	EOF
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
var _first_line = 0
var _lines : PoolStringArray = PoolStringArray()
var _sym : String = ""
var _pos = {"l":0, "c":0}

var _token = []
var _token_lines = []

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------
func _init(src : String, firstLine : int = 0) -> void:
	if firstLine >= 0:
		_first_line = firstLine
		_lines = src.replace("\r", "").replace("\t", " ").split("\n")
		_LexSource()

# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _StoreToken(token : Dictionary) -> void:
	var lidx = token.line - _first_line
	var tidx = _token.size()
	_token.append(token)
	if lidx >= 0 and lidx < _token_lines.size():
		_token_lines[lidx].append(tidx)
	elif lidx == _token_lines.size():
		_token_lines.append([tidx])
	else:
		print("WARNING: Token line, ", token.line, ", is out of bounds.")


func _StripLine(line : String) -> String:
	var ls = line.split(";", true, 1)
	return ls[0]

func _ErrorToken(msg : String, idx : int, col : int, symbol: String = "") -> Dictionary:
	return {
		"type": TOKEN.ERROR,
		"line": idx,
		"col": col,
		"symbol":symbol,
		"msg": msg
	}

func _SymbolToToken():
	var token = {"type":TOKEN.LABEL, "line": _pos.l, "col":_pos.c, "symbol":_sym}
	var l = _sym.left(1)
	if l == "$" or l == "%":
		var r = _sym.substr(1)
		if r.is_valid_hex_number() or r.is_valid_integer():
			token.type = TOKEN.NUMBER
		else:
			token = _ErrorToken("Symbol expected to be hex, binary number.", _pos.l, _pos.c, _sym)
	elif "0123456789".find(l) >= 0:
		if _sym.is_valid_integer():
			token.type = TOKEN.NUMBER
		else:
			token = _ErrorToken("Symbol expected to be integer number.", _pos.l, _pos.c, _sym)
	_sym = ""
	return token

func _IsSingleToken(c : String, idx : int, col : int):
	match c:
		"@":
			return {"type":TOKEN.HERE, "line":idx, "col":col, "symbol":""}
		"(":
			return {"type":TOKEN.PAREN_L, "line":idx, "col":col, "symbol":""}
		")":
			return {"type":TOKEN.PAREN_R, "line":idx, "col":col, "symbol":""}
		"{":
			return {"type":TOKEN.BLOCK_L, "line":idx, "col":col, "symbol":""}
		"}":
			return {"type":TOKEN.BLOCK_R, "line":idx, "col":col, "symbol":""}
		",":
			return {"type":TOKEN.COMMA, "line":idx, "col":col, "symbol":""}
		".":
			return {"type":TOKEN.PERIOD, "line":idx, "col":col, "symbol":""}
		"\"":
			return {"type":TOKEN.QUOTE, "line":idx, "col":col, "symbol":""}
		":":
			return {"type":TOKEN.COLON, "line":idx, "col":col, "symbol":""}
		"=":
			return {"type":TOKEN.EQ, "line":idx, "col":col, "symbol":""}
		"+":
			return {"type":TOKEN.PLUS, "line":idx, "col":col, "symbol":""}
		"-":
			return {"type":TOKEN.MINUS, "line":idx, "col":col, "symbol":""}
		"/":
			return {"type":TOKEN.DIV, "line":idx, "col":col, "symbol":""}
		"*":
			return {"type":TOKEN.MULT, "line":idx, "col":col, "symbol":""}
	return null

func _LexSource() -> void:
	for idx in range(_lines.size()):
		var line : String = _StripLine(_lines[idx])
		for col in range(line.length()):
			var c : String = line.substr(col, 1)
			if c == " ":
				if _sym != "":
					var tok = _SymbolToToken()
					_StoreToken(tok)
					if tok.type == TOKEN.ERROR:
						return
			else:
				var tok = _IsSingleToken(c, _first_line + idx, col)
				if tok != null:
					if _sym != "":
						var toksym = _SymbolToToken()
						_StoreToken(toksym)
						if toksym.type == TOKEN.ERROR:
							return
					_StoreToken(tok)
				else:
					if _sym == "":
						_pos.l = _first_line + idx
						_pos.c = col
					_sym += c
		if _sym != "":
			var toksym = _SymbolToToken()
			_StoreToken(toksym)
			if toksym.type == TOKEN.ERROR:
				return
		_StoreToken({"type": TOKEN.EOL, "line":_first_line + idx, "col": line.length() - 1, "symbol":""})
	_StoreToken({"type": TOKEN.EOF, "line":_first_line + (_lines.size() - 1), "col": 0, "symbol":""})

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func is_valid() -> bool:
	if _token.size() > 0:
		return _token[_token.size()-1].type != TOKEN.ERROR
	return false

func line_count() -> int:
	return _lines.size()

func token_count() -> int:
	return _token.size()

func get_token(idx : int) -> Dictionary:
	if idx >= 0 and idx < _token.size():
		var tok = _token[idx]
		return {
			"type": tok.type,
			"line": tok.line,
			"col": tok.col,
			"symbol": tok.symbol
		}
	return {"type": TOKEN.EOF, "line":_first_line + (_lines.size() - 1), "col": 0, "symbol":""}

func first_line_index() -> int:
	return _first_line

func get_line(idx : int) -> String:
	idx -= _first_line
	if idx >= 0 and idx < _lines.size():
		return _lines[idx]
	return ""

func get_line_tokens(idx : int) -> Array:
	var res = []
	idx -= _first_line
	if idx >= 0 and idx < _token_lines.size():
		for tidx in _token_lines[idx]:
			res.append(get_token(tidx))
	return res

func get_error_token():
	if _token.size() > 0:
		var tok = _token[_token.size() - 1]
		if tok.type == TOKEN.ERROR:
			return tok
	return null

#func get_next_token() -> Dictionary:
#	if _tok != null:
#		var t = _tok
#		_tok = null
#		return t
#
#	if _idx < _lines.size():
#		if _line == "":
#			_line = _StripLine(_lines[_idx])
#			_col = 0
#		while _col < _line.length():
#			var c : String = _line.substr(_col, 1)
#			if c == " ":
#				var tok = _SymbolToToken()
#				if tok != null:
#					return tok
#			else:
#				_tok = _IsSingleToken(c)
#				if _tok != null:
#					var tok = _SymbolToToken()
#					if tok == null:
#						tok = _tok
#						_tok = null
#					return tok
#				if _sym == "":
#					_pos.l = _idx
#					_pos.c = _col
#				_sym += c
#			_col += 1
#		_idx += 1
#		_line = ""
#		return {"type": TOKEN.EOL, "line":_idx - 1, "col": _col - 1, "sym":""}
#	return {"type": TOKEN.EOF, "line":_idx, "col": 0, "sym":""}


