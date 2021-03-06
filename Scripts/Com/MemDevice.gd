extends Node
class_name MemDevice


# ---------------------------------------------------------------------------
# Export Variables
# ---------------------------------------------------------------------------
export (int, 0, 255) var page = 0
export (int, 1, 256) var page_count = 1				setget set_page_count

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Setters / Getters
# ---------------------------------------------------------------------------
func set_page_count(count : int) -> void:
	if count >= 1 and count <= 256:
		page_count = count


# ---------------------------------------------------------------------------
# Override Methods
# ---------------------------------------------------------------------------


# ---------------------------------------------------------------------------
# Public Methods
# ---------------------------------------------------------------------------
func read(idx : int) -> int:
	return 0

func write(idx : int, val : int) -> void:
	pass

func set_mem_addr(idx : int, val : int) -> void:
	pass

func page_dump(offset : int) -> PoolByteArray:
	return PoolByteArray([])


func mem_dump(offset : int = -1, pages : int = -1) -> PoolByteArray:
	return PoolByteArray([])



