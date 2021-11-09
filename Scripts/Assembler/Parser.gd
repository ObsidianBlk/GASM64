extends Reference
class_name Parser

#
# GASM Parser
#
# Loosely based on assembly style as described at...
# https://www.masswerk.at/6502/assembler.html
#
# Will formalize this soon!
#

# ---------------------------------------------------------------------------
# ENUMs
# ---------------------------------------------------------------------------
enum ASTNODE {
	NUMBER,
	STRING,
	LABEL,
	DIRECTIVE,
	HERE,
	BLOCK,
	INST,
	HILO,
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
var _skip_EOL : bool = false

var _ast = null
var _errors = []

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------
func _init(lex : Lexer = null) -> void:
	if lex != null:
		parse(lex)


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
		return Utils.hex_to_int(token.symbol.substr(1))
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
		return GASM.is_instruction(t.symbol)
	return false

func _IsDirective() -> bool:
	var t = _PeekToken()
	if t.type == Lexer.TOKEN.DIRECTIVE:
		return true
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

func _SkipEOL() -> void:
	while _IsTokenConsume(Lexer.TOKEN.EOL):
		pass

func _ParseBlock(terminator : int = Lexer.TOKEN.EOF):
	var tok = _PeekToken()
	var node = {"type":ASTNODE.BLOCK, "expressions":[], "line":tok.line, "col":tok.col}
	while not (_IsToken(terminator) or _IsToken(Lexer.TOKEN.EOF)) :
		if _IsTokenConsume(Lexer.TOKEN.EOL): # Just skip empty lines
			continue
		var ex = _ParseExpression()
		if _errors.size() > 0:
			return null
		if ex != null:
			node.expressions.append(ex)
		if not _skip_EOL:
			if not _IsTokenConsume(Lexer.TOKEN.EOL):
				var token = _PeekToken()
				_StoreError("Expected end of line.", token.line, token.col)
				return null
		else:
			_skip_EOL = false
	tok = _ConsumeToken()
	if tok.type != terminator:
		_StoreError(
			"Unexpected end of block. Expected token " + _lexer.get_token_name(terminator) + ". Found End of Line",
			tok.line, tok.col
		)
		return null
	return node

func _ParseDelimited(stype : int, etype : int, dtype : int, parse_func : String):
	var toEOL = (stype < 0 or etype < 0)
	var el = []
	var first = true
	var token = null
	if not toEOL:
		token = _ConsumeToken()
		if token.type != stype:
			_StoreError(
				"Unexpected token type " + _lexer.get_token_name(token.type) + ". Expected " + _lexer.get_token_name(stype),
				token.line, token.col
			)
			return null
		_SkipEOL()
	while ((not _IsToken(Lexer.TOKEN.EOF)) and (not toEOL and not _IsToken(etype))) or (toEOL and not _IsToken(Lexer.TOKEN.EOL)):
		if not first:
			token = _ConsumeToken()
			if token.type != dtype:
				_StoreError(
					"Unexpected token type " + _lexer.get_token_name(token.type) + ". Expected " + _lexer.get_token_name(dtype),
					token.line, token.col
				)
				return null
			if not toEOL:
				_SkipEOL()
		first = false
		var e = call(parse_func)
		if e != null:
			el.append(e)
		elif _errors.size() > 0:
			return null
		if not toEOL:
			_SkipEOL()
	if not toEOL:
		token = _ConsumeToken()
		if token.type != etype:
			_StoreError(
				"Unexpected token type " + _lexer.get_token_name(token.type) + ". Expected " + _lexer.get_token_name(etype),
				token.line, token.col
			)
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
	elif _IsDirective():
		return _ParseDirectives()
	
	var t = _ConsumeToken()
	if t.type == Lexer.TOKEN.MULT:
		return _ParseHere(t)
	elif t.type == Lexer.TOKEN.LT or t.type == Lexer.TOKEN.GT:
		return _ParseHILO(t)
	elif t.type == Lexer.TOKEN.NUMBER:
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
		"value": t.symbol.substr(1, t.symbol.length() - 2),
		"line": t.line,
		"col": t.col
	}

func _ParseLabel(t):
	var label_node = {
		"type": ASTNODE.LABEL,
		"value": t.symbol,
		"line": t.line,
		"col": t.col
	}
	
	if _IsInstruction() or _IsTokenConsume(Lexer.TOKEN.COLON):
		_skip_EOL = true
		return {
			"type": ASTNODE.ASSIGNMENT,
			"op": "=",
			"left": label_node,
			"right": _ParseHere(t),
			"line": t.line,
			"col": t.col
		}
	return label_node


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

func _ParseHILO(t):
	var val = _ParseAtom()
	if val != null:
		return {
			"type": ASTNODE.HILO,
			"operator": "<" if t.type == Lexer.TOKEN.LT else ">",
			"value": val,
			"line": t.line,
			"col": t.col
		}
	return null

func _ParseHere(t):
	return {
		"type": ASTNODE.HERE,
		"line": t.line,
		"col": t.col
	}

func _ParseInstruction():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type != Lexer.TOKEN.LABEL:
		return null
	if not GASM.is_instruction(token.symbol):
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


func _AddrImplied(ignore_errors : bool = false):
	var token = _PeekToken()
	if token.type == Lexer.TOKEN.EOL:
		return {"addr":GASM.MODE.IMP}
	elif token.type == Lexer.TOKEN.LABEL and token.symbol.to_lower() == "a":
		_ConsumeToken()
		return {"addr":GASM.MODE.ACC}
	elif not ignore_errors:
		_StoreError("Unexpected token " + _lexer.get_token_name(token.type) + ".", token.line, token.col)
	return null

func _AddrImmediate():
	_RememberToken()
	var token = _ConsumeToken()
	if token.type == Lexer.TOKEN.HASH:
		var val = _ParseAtom()
		if val != null:
			return {"addr":GASM.MODE.IMM, "value":val}
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
				return {"addr": GASM.MODE.IND, "value":val}
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
						return {"addr": GASM.MODE.INDX, "value":val}
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
						return {"addr": GASM.MODE.INDY, "value":val}
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
						"addr" : GASM.MODE.ABSX if sym == "x" else GASM.MODE.ABSY,
						"value":val
					}
				else:
					_StoreError("Syntax Error! Expected LABEL token of 'X' or 'Y'.", token.line, token.col)
			else:
				_StoreError("Syntax Error! Expected LABEL token of 'X' or 'Y'.", token.line, token.col)
		elif token.type == Lexer.TOKEN.EOL:
			return {"addr":GASM.MODE.ABS, "value":val}
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
			var node = _AddrImplied(true) # This will check for "Accumulator" addressing
			if node != null or _errors.size() > 0:
				return node
			
			return _AddrAbs()
		Lexer.TOKEN.GT:
			return _AddrAbs()
		Lexer.TOKEN.LT:
			return _AddrAbs()
		_:
			_StoreError("Syntax Error! Unexpected token.", token.line, token.col)
	return null

func _ParseByteDirective(directive : String):
	var token = _PeekToken()
	var vals = null
	if _IsToken(Lexer.TOKEN.BRACE_L):
		vals = _ParseDelimited(Lexer.TOKEN.BRACE_L, Lexer.TOKEN.BRACE_R, Lexer.TOKEN.COMMA, "_ParseAtom")
	else:
		vals = _ParseDelimited(-1, -1, Lexer.TOKEN.COMMA, "_ParseAtom")
	if vals != null:
		return {
			"type": ASTNODE.DIRECTIVE,
			"directive": directive,
			"values": vals,
			"line": token.line,
			"col": token.col
			}
	return null

func _ParseTextDirective(directive : String):
	var token = _PeekToken()
	var vals = null
	if _IsToken(Lexer.TOKEN.BRACE_L):
		vals = _ParseDelimited(Lexer.TOKEN.BRACE_L, Lexer.TOKEN.BRACE_R, Lexer.TOKEN.COMMA, "_ParseAtom")
	else:
		vals = _ParseDelimited(-1, -1, Lexer.TOKEN.COMMA, "_ParseAtom")
	if vals != null:
		for v in vals:
			if v.type != ASTNODE.STRING and v.type != ASTNODE.LABEL:
				_StoreError("Expected a string literal.", v.line, v.col)
				return null
		return {
			"type": ASTNODE.DIRECTIVE,
			"directive": directive,
			"values": vals,
			"line": token.line,
			"col": token.col
		}
	return null

func _ParseFillDirective():
	var token = _PeekToken()
	var amount = _ParseAtom()
	if amount == null:
		_StoreError("Directive '.fill' expects at least one EXPRESSION argument.", token.line, token.col)
		return null
	var val = null
	if not _IsToken(Lexer.TOKEN.EOL):
		val = _ParseAtom()
		if val == null:
			return null
	return {
		"type": ASTNODE.DIRECTIVE,
		"directive":".fill",
		"value": val,
		"bytes": amount,
		"line": token.line,
		"col": token.col}

func _ParseSegmentDirective():
	var token = _PeekToken()
	var val = _ParseAtom()
	if val == null:
		_StoreError("Directive '.segment' expects at least one EXPRESSION argument.", token.line, token.col)
		return null
	return {
		"type": ASTNODE.DIRECTIVE,
		"directive":".segment",
		"value": val,
		"line": token.line,
		"col": token.col}

func _ParseDirectives():
	# TODO: Should I pass this token to all of the _Parse*Directive() methods?
	# This token holds the true line/col position for the directive after all.
	var token = _ConsumeToken()
	match token.symbol:
		".segment":
			return _ParseSegmentDirective()
		".bytes", ".words", ".dbytes":
			return _ParseByteDirective(token.symbol)
		".text", ".ascii", ".petsci", ".include":
			return _ParseTextDirective(token.symbol)
		".fill":
			return _ParseFillDirective()
		_:
			_StoreError("Unrecognized directive '" + token.symbol + "'.", token.line, token.col)
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
				"type": ASTNODE.ASSIGNMENT if tok.type == Lexer.TOKEN.ASSIGN else ASTNODE.BINARY,
				"op": operator,
				"left": ltok,
				"right": rtok,
				"line": tok.line,
				"col": tok.col
			}, pres)
	return ltok

func _ASTNodeToBuffer(ast : Dictionary, store_line_col : bool = false) -> PoolByteArray:
	var data : PoolByteArray = PoolByteArray([])
	data.append(ast.type)
	if store_line_col:
		data.append_array(Utils.int_to_buffer(ast.line, 4))
		data.append_array(Utils.int_to_buffer(ast.col, 2))
	# NOTE: ASTNODE.HERE is automatically handled by the code above and needs no entry
	# in the match list.
	match ast.type:
		ASTNODE.BLOCK:
			data.append_array(Utils.int_to_buffer(ast.expressions.size(), 8))
			for e in ast.expressions:
				data.append_array(_ASTNodeToBuffer(e, store_line_col))
		ASTNODE.ASSIGNMENT, ASTNODE.BINARY:
			data.append(ast.op.ord_at(0))
			data.append_array(_ASTNodeToBuffer(ast.left, store_line_col))
			data.append_array(_ASTNodeToBuffer(ast.right, store_line_col))
		ASTNODE.HILO:
			data.append(ast.operator.ord_at(0))
			data.append_array(_ASTNodeToBuffer(ast.value, store_line_col))
		ASTNODE.INST:
			var ibuf = ast.inst.to_utf8()
			data.append(ibuf.size())
			data.append_array(ibuf)
			data.append(ast.addr)
			if ast.value != null:
				data.append_array(_ASTNodeToBuffer(ast.value, store_line_col))
		ASTNODE.LABEL, ASTNODE.STRING:
			data.append_array(Utils.int_to_buffer(ast.value.size(), 4))
			data.append_array(ast.value.to_utf8())
		ASTNODE.NUMBER:
			data.append_array(Utils.int_to_buffer(ast.value, 2))
		ASTNODE.DIRECTIVE:
			data.append(ast.directive.size())
			data.append_array(ast.directive.to_utf8())
			
			match ast.directive:
				".segment":
					data.append(ast.value.size())
					data.append_array(ast.value.to_utf8())
				".bytes", ".words", ".dbytes", ".text", ".ascii", ".petsci", ".include":
					data.append_array(Utils.int_to_buffer(ast.values.size(), 4))
					for v in ast.values:
						data.append_array(_ASTNodeToBuffer(v, store_line_col))
				".fill":
					data.append_array(_ASTNodeToBuffer(ast.value, store_line_col))
					data.append_array(_ASTNodeToBuffer(ast.bytes, store_line_col))
	return data


func _BufferToASTNode(buffer : PoolByteArray, offset : int, has_line_col : bool = false):
	var ast = {"type": buffer[offset], "line": 0, "col": 0}
	offset += 1
	if ASTNODE.values().find(ast.type) < 0:
		_StoreError("Unknown AST Node Type (" + ast.type + ") in buffer.", -1, 0)
		return null
	if has_line_col:
		ast.line = Utils.buffer_to_int(buffer, offset, 4)
		ast.col = Utils.buffer_to_int(buffer, offset + 4, 2)
		offset += 6
	if ast.type != ASTNODE.HERE:
		match ast.type:
			ASTNODE.BLOCK:
				var ecount = Utils.buffer_to_int(buffer, offset, 8)
				ast["expressions"] = []
				offset += 8
				for _i in range(ecount):
					var res = _BufferToASTNode(buffer, offset, has_line_col)
					if res == null:
						return null
					offset = res.offset
					ast.expressions.append(res.ast)
			ASTNODE.ASSIGNMENT, ASTNODE.BINARY:
				ast["op"] = "%c" % buffer[offset]
				var res = _BufferToASTNode(buffer, offset + 1, has_line_col)
				if res == null:
					return null
				ast["left"] = res.ast
				
				res = _BufferToASTNode(buffer, res.offset, has_line_col)
				if res == null:
					return null
				offset = res.offset
				ast["right"] = res.ast
			ASTNODE.HILO:
				ast["operator"] = "%c" % buffer[offset]
				var res = _BufferToASTNode(buffer, offset + 1, has_line_col)
				if res == null:
					return null
				offset = res.offset
				ast["value"] = res.ast
			ASTNODE.INST:
				var isize = buffer[offset]
				var inst = Utils.buffer_to_string(buffer, offset + 1, isize)
				if not GASM.is_instruction(inst):
					_StoreError("Unrecognized instruction name '" + inst + "' in AST buffer.", -1, 0)
					return null
				ast["inst"] = inst
				ast["value"] = null
				offset += isize + 1
				var addr = buffer[offset]
				if GASM.MODE.values().find(addr) < 0:
					_StoreError("Unrecognized instruction addressing more '" + addr + "' in AST buffer", -1, 0)
					return null
				if addr != GASM.MODE.IMP and addr != GASM.MODE.IMM:
					var res = _BufferToASTNode(buffer, offset + 1, has_line_col)
					if res == null:
						return null
					offset = res.offset
					ast.value = res.ast
			ASTNODE.LABEL, ASTNODE.STRING:
				var ssize = Utils.buffer_to_int(buffer, offset, 4)
				offset += 4
				var val = Utils.buffer_to_string(buffer, offset, ssize)
				ast["value"] = val
				offset += ssize
			ASTNODE.NUMBER:
				ast["value"] = Utils.buffer_to_int(buffer, offset, 2)
				offset += 2
			ASTNODE.DIRECTIVE:
				var size = buffer[offset]
				var directive = Utils.buffer_to_string(buffer, offset + 1, size)
				offset += size + 1
				
				match directive:
					".segment":
						size = buffer[offset]
						ast["value"] = Utils.buffer_to_string(buffer, offset + 1, size)
						offset += size + 1
					".bytes", ".words", ".dbytes", ".text", ".ascii", ".petsci", ".include":
						size = Utils.buffer_to_int(buffer, offset, 4)
						offset += 4
						var values = []
						for _i in range(size):
							var res = _BufferToASTNode(buffer, offset, has_line_col)
							if res == null:
								return null
							offset = res.offset
							values.append(res.ast)
						ast["values"] = values
					".fill":
						var res = _BufferToASTNode(buffer, offset, has_line_col)
						if res == null:
							return null
						ast["value"] = res.ast
						
						res = _BufferToASTNode(buffer, res.offset, has_line_col)
						if res == null:
							return null
						ast["bytes"] = res.ast
						offset = res.offset
					_:
						_StoreError("Unknown directive '" + directive + "' in AST buffer.", -1, 0)
						return null
				ast["directive"] = directive

	return {"offset": offset, "ast":ast}


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func is_valid() -> bool:
	return _ast != null and _errors.size() <= 0

func parse(lex : Lexer) -> bool:
	if lex.is_valid():
		_errors.clear()
		_lexer = lex
		_ast = _ParseBlock()
		if _errors.size() <= 0:
			return true
	return false

func parse_ast_buffer(buffer : PoolByteArray) -> bool:
	_errors.clear()
	var has_line_col = (buffer[0] == 1)
	var res = _BufferToASTNode(buffer, 1, has_line_col)
	if res != null:
		_ast = res.ast
		return true
	return false

func get_ast():
	return _ast

func get_ast_buffer(inc_line_col : bool = false) -> PoolByteArray:
	var buffer : PoolByteArray = PoolByteArray([])
	if _ast != null and _errors.size() <= 0:
		buffer.append(0 if not inc_line_col else 1)
		buffer.append_array(_ASTNodeToBuffer(_ast, inc_line_col))
	return buffer

func error_count() -> int:
	return _errors.size()

func get_error(i : int):
	if i >= 0 and i < _errors.size():
		return _errors[i]
	return null

func get_errors():
	return _errors

