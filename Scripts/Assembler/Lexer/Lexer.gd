extends Reference
class_name Lexer

# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum TOKEN {
	ERROR=-1,
	LABEL,
	NUMBER,
	STRING,
	HASH,
	PAREN_L,
	PAREN_R,
	BLOCK_L,
	BLOCK_R,
	LT,
	LTE,
	GT,
	GTE,
	COMMA,
	PERIOD,
	COLON,
	ASSIGN,
	EQ,
	NEQ,
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
func _StoreToken(lidx : int, token : Dictionary) -> void:
	var tidx = _token.size()
	_token.append(token)
	if lidx >= 0 and lidx < _token_lines.size():
		_token_lines[lidx].append(tidx)
	elif lidx == _token_lines.size():
		_token_lines.append([tidx])

func _GetTokenLineNumber(tidx : int) -> int:
	for tline_idx in range(_token_lines.size()):
		for tok_idx in _token_lines[tline_idx]:
			if tok_idx == tidx:
				return tline_idx
	return -1

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
	var token = {"type":TOKEN.LABEL, "col":_pos.c, "symbol":_sym}
	var l = _sym.left(1)
	if l == "$" or l == "%":
		var r = _sym.substr(1)
		if r.is_valid_hex_number() or Utils.is_valid_binary(r):
			token.type = TOKEN.NUMBER
		else:
			token = _ErrorToken("Symbol expected to be hex or binary number.", _pos.l, _pos.c, _sym)
	elif "0123456789".find(l) >= 0:
		if _sym.is_valid_integer():
			token.type = TOKEN.NUMBER
		else:
			token = _ErrorToken("Symbol '" + _sym + "' invalid.", _pos.l, _pos.c, _sym)
	_sym = ""
	return token

func _IsSingleToken(c : String, col : int):
	match c:
		"#":
			return {"type":TOKEN.HASH, "col":col, "symbol":""}
		"(":
			return {"type":TOKEN.PAREN_L, "col":col, "symbol":""}
		")":
			return {"type":TOKEN.PAREN_R, "col":col, "symbol":""}
		"{":
			return {"type":TOKEN.BLOCK_L, "col":col, "symbol":""}
		"}":
			return {"type":TOKEN.BLOCK_R, "col":col, "symbol":""}
		",":
			return {"type":TOKEN.COMMA, "col":col, "symbol":""}
		".":
			return {"type":TOKEN.PERIOD, "col":col, "symbol":""}
		":":
			return {"type":TOKEN.COLON, "col":col, "symbol":""}
		"+":
			return {"type":TOKEN.PLUS, "col":col, "symbol":""}
		"-":
			return {"type":TOKEN.MINUS, "col":col, "symbol":""}
		"/":
			return {"type":TOKEN.DIV, "col":col, "symbol":""}
		"*":
			return {"type":TOKEN.MULT, "col":col, "symbol":""}
	return null

func _IsOperatorToken(c1 : String, c2 : String, col : int):
	match c1:
		"=":
			if c2 == "=":
				return {"type":TOKEN.EQ, "col":col, "symbol":""}
			return {"type":TOKEN.ASSIGN, "col":col, "symbol":""}
		"<":
			if c2 == "=":
				return {"type":TOKEN.LTE, "col":col, "symbol":""}
			return {"type":TOKEN.LT, "col":col, "symbol":""}
		">":
			if c2 == "=":
				return {"type":TOKEN.GTE, "col":col, "symbol":""}
			return {"type":TOKEN.GT, "col":col, "symbol":""}
		"!":
			if c2 == "=":
				return {"type":TOKEN.NEQ, "col":col, "symbol":""}
			#return {"type":TOKEN.NOT, "col":col, "symbol":""}
	return null

func _StoreSymIfExists() -> bool:
	if _sym != "":
		var toksym = _SymbolToToken()
		_StoreToken(_pos.l, toksym)
		if toksym.type == TOKEN.ERROR:
			return false
	return true

func _LexLine(idx : int, line : String) -> bool:
	var skip_c = false
	for col in range(line.length()):
		if skip_c:
			skip_c = false
			continue
			
		var c : String = line.substr(col, 1)
		var sym_is_string = _sym != "" and _sym.left(1) == "\""
		if c == "\"" or sym_is_string:
			if _sym == "":
				_pos.l = idx
				_pos.c = col
			_sym += c
			if sym_is_string:
				_StoreToken(idx, {"type":TOKEN.STRING, "col": _pos.c, "symbol":_sym})
				_sym = ""
		elif c == " ":
			if not _StoreSymIfExists():
				return false
		else:
			var tok = _IsSingleToken(c, col)
			if tok == null and col + 1 < line.length():
				var c2 : String = line.substr(col + 1, 1) # Sniffing ahead a character
				tok = _IsOperatorToken(c, c2, col)
			if tok != null:
				if not _StoreSymIfExists():
					return false
				_StoreToken(idx, tok)
				if [TOKEN.LTE, TOKEN.GTE, TOKEN.EQ, TOKEN.NEQ].find(tok.type) >= 0:
					skip_c = true # If the above is true, we technically used a character
							# we sniffed ahead on, so we don't want to process that character again.
			else:
				if _sym == "":
					_pos.l = idx
					_pos.c = col
				_sym += c
	if not _StoreSymIfExists():
		return false
	_StoreToken(idx, {"type": TOKEN.EOL, "col": line.length() - 1, "symbol":""})
	return true


func _LexSource() -> void:
	for idx in range(_lines.size()):
		var line : String = _StripLine(_lines[idx])
		if not _LexLine(idx, line):
			return
	_StoreToken((_lines.size() - 1), {"type": TOKEN.EOF, "col": 0, "symbol":""})

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
		var tidx = _GetTokenLineNumber(idx)
		if tidx >= 0:
			var res = {
				"type": tok.type,
				"line": tidx + _first_line,
				"col": tok.col,
				"symbol": tok.symbol
			}
			if tok.type == TOKEN.ERROR:
				res["msg"] = tok.msg
			return res
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

func get_token_name(type : int) -> String:
	for key in TOKEN.keys():
		if TOKEN[key] == type:
			return key
	return ""

func get_error_token():
	if _token.size() > 0:
		var tok = get_token(_token.size() - 1)
		if tok.type == TOKEN.ERROR:
			return tok
	return null


