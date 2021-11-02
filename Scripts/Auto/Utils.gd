extends Node

var _deferred = {}

func _call_and_release(key : String) -> void:
	if key in _deferred:
		var info = _deferred[key]
		_deferred.erase(key)
		if info.obj != null:
			info.obj.callv(info.method, info.args)
		else:
			callv(info.method, info.args)

func call_deferred_once(method : String, obj = null, args : Array = []) -> void:
	var key = ""
	if obj == null:
		key = "__NULL__" + method
	else:
		key = obj.to_string() + method
	if not (key in _deferred):
		_deferred[key] = {
			"obj":obj,
			"method":method,
			"args":args
		}
		call_deferred("_call_and_release", key)

func hex_to_int(hex : String) -> int:
	if hex.is_valid_hex_number() and not hex.is_valid_hex_number(true):
		hex = "0x" + hex
		return hex.hex_to_int()
	return -1

func int_to_hex(v : int, minlen : int = 0) -> String:
	var s = sign(v)
	v = abs(v)
	var hex = ""
	while hex == "" or v > 0:
		var code = v & 0xF
		match code:
			10:
				hex = "A" + hex
			11:
				hex = "B" + hex
			12:
				hex = "C" + hex
			13:
				hex = "D" + hex
			14:
				hex = "E" + hex
			15:
				hex = "F" + hex
			_:
				hex = String(code) + hex
		v = v >> 4
	while hex.length() < minlen:
		hex = "0" + hex
	return hex

func is_valid_binary(v : String) -> bool:
	if v.length() > 0:
		for c in v:
			if c != "1" and c != "0":
				return false
		return true
	return false

func binary_to_int(v : String) -> int:
	var ex = v.length() - 1
	var val = 0
	for c in v:
		if c == "1":
			val += pow(2, ex)
		ex -= 1
	return int(val)

func uuidv4(no_seperate : bool = false) -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var uuid = ""
	for i in range(0, 16):
		var byte = rng.randi_range(0, 256)
		if i == 6:
			byte = 0x40 | (0x0F & byte)
		elif i == 9:
			byte = 0x80 | (0x3F & byte)
		uuid += int_to_hex(byte, 2)
		if not no_seperate and (i == 3 or i == 5 or i == 7 or i == 9):
			uuid += "-"
	return uuid


