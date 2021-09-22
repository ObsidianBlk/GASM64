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
	return val


