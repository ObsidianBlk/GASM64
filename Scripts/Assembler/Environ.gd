extends Reference
class_name Environ


var _env : Dictionary = {}


func reset() -> void:
	_env.clear()

func has_label(label : String) -> bool:
	if label in _env:
		return true
	return false

func get_label(label : String):
	if label in _env:
		return _env[label].value
	return null

func set_label(label : String, value, global : bool = false) -> void:
	if value != null and not (label in _env):
		_env[label] = {
			"value":value,
			"global":global
		}

func get_global_labels() -> Array:
	var glabels = []
	for key in _env.keys():
		if _env[key].global:
			glabels.append({
				"label":key,
				"value":_env[key].value,
			})
	return glabels

func import(e : Environ) -> void:
	var glabels = e.get_global_labels()
	for gl in glabels:
		if not gl.label in _env:
			_env[gl.label] = {
				"value": gl.value,
				"global": true,
			}
		else:
			pass # TODO: Throw an error of some kind.


