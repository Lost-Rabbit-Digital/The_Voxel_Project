# chunk_cache.gd
class_name ChunkCache
extends Resource

const CACHE_DIR := "user://chunk_cache"
const MAX_CACHED_CHUNKS := 1000

var cache_enabled: bool = true
var dirty_chunks: Dictionary = {}

func _init() -> void:
	# Create cache directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)

func get_chunk_filename(chunk_pos: Vector3) -> String:
	return CACHE_DIR.path_join("%d_%d_%d.chunk" % [chunk_pos.x, chunk_pos.y, chunk_pos.z])

func has_cached_chunk(chunk_pos: Vector3) -> bool:
	if not cache_enabled:
		return false
	return FileAccess.file_exists(get_chunk_filename(chunk_pos))

func save_chunk(chunk_pos: Vector3, chunk_data: ChunkData) -> void:
	if not cache_enabled:
		return
		
	var filename = get_chunk_filename(chunk_pos)
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		# Serialize chunk data
		var data = {
			"position": {
				"x": chunk_pos.x,
				"y": chunk_pos.y,
				"z": chunk_pos.z
			},
			"voxels": {}
		}
		
		# Convert voxel dictionary to serializable format
		for pos in chunk_data.voxels:
			var key = "%d_%d_%d" % [pos.x, pos.y, pos.z]
			data.voxels[key] = chunk_data.voxels[pos]
		
		# Save to file
		file.store_var(data)
		file.close()

func load_chunk(chunk_pos: Vector3) -> ChunkData:
	if not cache_enabled:
		return null
		
	var filename = get_chunk_filename(chunk_pos)
	if not FileAccess.file_exists(filename):
		return null
		
	var file = FileAccess.open(filename, FileAccess.READ)
	if not file:
		return null
		
	var data = file.get_var()
	file.close()
	
	if not data:
		return null
	
	# Create new chunk data and populate it
	var chunk_data = ChunkData.new(chunk_pos)
	
	# Convert serialized voxel data back to Vector3 keys
	for pos_str in data.voxels:
		var pos_parts = pos_str.split("_")
		var pos = Vector3(
			int(pos_parts[0]),
			int(pos_parts[1]),
			int(pos_parts[2])
		)
		chunk_data.set_voxel(pos, data.voxels[pos_str])
	
	return chunk_data

func clean_cache() -> void:
	if not cache_enabled:
		return
		
	var dir = DirAccess.open(CACHE_DIR)
	if not dir:
		return
		
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".chunk"):
			files.append({"name": file_name, "time": FileAccess.get_modified_time(CACHE_DIR.path_join(file_name))})
		file_name = dir.get_next()
	
	# If we have too many cached chunks, remove the oldest ones
	if files.size() > MAX_CACHED_CHUNKS:
		files.sort_custom(func(a, b): return a.time < b.time)
		for i in range(files.size() - MAX_CACHED_CHUNKS):
			var path = CACHE_DIR.path_join(files[i].name)
			DirAccess.remove_absolute(path)
