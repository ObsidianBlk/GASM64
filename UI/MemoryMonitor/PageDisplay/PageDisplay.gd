extends Control


onready var page_data_node = get_node("Page/Data")
onready var page_label_node = get_node("Label")


func set_page(page : int) -> void:
	if not page_label_node:
		return
	page_label_node.text = "0x" + GASM.int_to_hex(page & 0xFF, 2)


func set_data(data : PoolByteArray, offset : int = 0) -> void:
	if not page_data_node:
		return
	
	var idx : int = 0
	for child in page_data_node.get_children():
		for _i in range(16):
			var line = ""
			if idx + offset >= 0 and idx + offset < data.size():
				line += GASM.int_to_hex(data[idx + offset], 2) + " "
			else:
				line += "00 "
				print("WARNING: Data index out of bounds at: ", idx + offset)
			idx += 1
			child.get_node("Data").text = line

