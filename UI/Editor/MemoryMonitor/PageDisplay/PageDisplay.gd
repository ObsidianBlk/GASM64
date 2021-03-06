extends Control
tool


onready var page_data_node = get_node("Page/Data")
onready var page_label_node = get_node("Label")

func _ready() -> void:
	if has_font("PageDisplay_Title", "MemoryMonitor"):
		var fnt = get_font("PageDisplay_Title", "MemoryMonitor")
		page_label_node.add_font_override("font", fnt)
	
	for child in page_data_node.get_children():
		var lbl : Label = child.get_node("Label")
		if lbl and has_font("PageDisplay_Row", "MemoryMonitor"):
			var fnt = get_font("PageDisplay_Row", "MemoryMonitor")
			lbl.add_font_override("font", fnt)
		
		var data : RichTextLabel = child.get_node("Data")
		if data and has_font("PageDisplay_Normal", "MemoryMonitor"):
			var fnt = get_font("PageDisplay_Normal", "MemoryMonitor")
			data.add_font_override("normal_font", fnt)
			data.add_font_override("mono_font", fnt)
			data.add_font_override("bold_font", fnt)
			data.add_font_override("italics_font", fnt)
			data.add_font_override("bold_italics_font", fnt)
	if Engine.editor_hint:
		page_label_node.text = "0x00"


func set_page(page : int) -> void:
	if not page_label_node:
		return
	page_label_node.text = "0x" + Utils.int_to_hex(page & 0xFF, 2)


func set_data(data : PoolByteArray, offset : int = 0) -> void:
	if not page_data_node:
		return
	
	var idx : int = 0
	for child in page_data_node.get_children():
		var line = ""
		var inred = false
		for _i in range(16):
			if idx + offset >= 0 and idx + offset < data.size():
				if inred:
					inred = false
					line += "[/color]"
				line += Utils.int_to_hex(data[idx + offset], 2) + " "
			else:
				if not inred:
					inred = true
					line += "[color=#FF5500]"
				line += "00 "
			idx += 1
		if inred:
			line += "[/color]"
		child.get_node("Data").bbcode_text = line

