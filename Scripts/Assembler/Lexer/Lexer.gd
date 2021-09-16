extends Reference
class_name Lexer

# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum TOKEN {
	LABEL,
	NUMBER,
	HERE,
	PAREN_L,
	PAREN_R,
	COMMA,
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
var _lines : PoolStringArray = PoolStringArray()
var _line : String = ""
var _idx : int = 0
var _col : int = 0

var _sym : String = ""
var _pos = {"l":0, "c":0}
var _tok = null

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------
func _init(src : String) -> void:
	_lines = src.replace("\r", "").replace("\t", " ").split("\n")

# ---------------------------------------------------------------------------
# Private Methods
# ---------------------------------------------------------------------------
func _StripLine(line : String) -> String:
	var ls = line.split(";", true, 1)
	return ls[0]

func _SymbolToToken():
	if _sym != "":
		var l = _sym.left(1)
		if l == "$" or l == "%" or "0123456789".find(l) >= 0:
			var r = _sym.substr(1)
			if r.is_valid_hex_number() or r.is_valid_integer():
				return {"type":TOKEN.NUMBER, "line": _pos.l, "col":_pos.c, "symbol":_sym}
		else:
			return {"type":TOKEN.LABEL, "line": _pos.l, "col": _pos.c, "symbol": _sym}
	return null

func _IsSingleToken(c : String):
	match c:
		"@":
			return {"type":TOKEN.HERE, "line":_idx, "col":_col, "symbol":""}
		"(":
			return {"type":TOKEN.PAREN_L, "line":_idx, "col":_col, "symbol":""}
		")":
			return {"type":TOKEN.PAREN_R, "line":_idx, "col":_col, "symbol":""}
		",":
			return {"type":TOKEN.COMMA, "line":_idx, "col":_col, "symbol":""}
		"=":
			return {"type":TOKEN.EQ, "line":_idx, "col":_col, "symbol":""}
		"+":
			return {"type":TOKEN.PLUS, "line":_idx, "col":_col, "symbol":""}
		"-":
			return {"type":TOKEN.MINUS, "line":_idx, "col":_col, "symbol":""}
		"/":
			return {"type":TOKEN.DIV, "line":_idx, "col":_col, "symbol":""}
		"*":
			return {"type":TOKEN.MULT, "line":_idx, "col":_col, "symbol":""}
	return null

# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func get_next_token() -> Dictionary:
	if _tok != null:
		var t = _tok
		_tok = null
		return t
	
	if _idx < _lines.size():
		if _line == "":
			_line = _StripLine(_lines[_idx])
			_col = 0
		while _col < _line.length():
			var c : String = _line.substr(_col, 1)
			if c == " ":
				pass
		_idx += 1
		_line = ""
		return {"type": TOKEN.EOL, "line":_idx - 1, "col": _col - 1, "sym":""}
	return {"type": TOKEN.EOF, "line":_idx, "col": 0, "sym":""}


