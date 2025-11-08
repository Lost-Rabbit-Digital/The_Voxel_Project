## ChunkCache - Manages chunk serialization and disk caching
## Saves generated chunks to disk to avoid regeneration when revisiting areas
class_name ChunkCache
extends RefCounted

## Cache configuration
var cache_enabled: bool = true
var cache_directory: String = "user://chunk_cache/"
var world_seed: int = 0
var max_cache_size_mb: int = 500  # Maximum cache size in megabytes

## Statistics
var cache_hits: int = 0
var cache_misses: int = 0
var chunks_saved: int = 0
var chunks_loaded: int = 0

func _init(seed: int = 0, enabled: bool = true) -> void:
	world_seed = seed
	cache_enabled = enabled

	if cache_enabled:
		_ensure_cache_directory()

## Ensure cache directory exists
func _ensure_cache_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("chunk_cache"):
			var error := dir.make_dir("chunk_cache")
			if error == OK:
				print("[ChunkCache] Created cache directory at %s" % cache_directory)
			else:
				print("[ChunkCache] ERROR: Failed to create cache directory: %d" % error)
				cache_enabled = false
	else:
		print("[ChunkCache] ERROR: Failed to access user:// directory")
		cache_enabled = false

## Get cache file path for a chunk
func _get_cache_path(chunk_pos: Vector3i) -> String:
	# Include world seed in path to invalidate cache when seed changes
	var seed_dir := "%s%d/" % [cache_directory, world_seed]
	var filename := "%d_%d_%d.chunk" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	return seed_dir + filename

## Check if a chunk is cached
func has_cached_chunk(chunk_pos: Vector3i) -> bool:
	if not cache_enabled:
		return false

	var cache_path := _get_cache_path(chunk_pos)
	return FileAccess.file_exists(cache_path)

## Load a chunk from cache
func load_chunk(chunk_pos: Vector3i) -> Chunk:
	if not cache_enabled:
		cache_misses += 1
		return null

	var cache_path := _get_cache_path(chunk_pos)

	if not FileAccess.file_exists(cache_path):
		cache_misses += 1
		return null

	var file := FileAccess.open(cache_path, FileAccess.READ)
	if not file:
		print("[ChunkCache] ERROR: Failed to open cache file: %s" % cache_path)
		cache_misses += 1
		return null

	# Read chunk data
	var data_json := file.get_as_text()
	file.close()

	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(data_json)
	if parse_result != OK:
		print("[ChunkCache] ERROR: Failed to parse chunk data: %s" % json.get_error_message())
		cache_misses += 1
		return null

	var data: Dictionary = json.data

	# Deserialize chunk
	var chunk := Chunk.deserialize(data)
	if chunk:
		cache_hits += 1
		chunks_loaded += 1
		return chunk
	else:
		cache_misses += 1
		return null

## Save a chunk to cache
func save_chunk(chunk: Chunk) -> bool:
	if not cache_enabled or not chunk:
		return false

	# Ensure seed-specific directory exists
	var seed_dir := "%s%d/" % [cache_directory, world_seed]
	var dir := DirAccess.open(cache_directory)
	if dir and not dir.dir_exists(str(world_seed)):
		dir.make_dir(str(world_seed))

	var cache_path := _get_cache_path(chunk.position)

	# Serialize chunk
	var data := chunk.serialize()

	# Convert to JSON
	var json_string := JSON.stringify(data)

	# Write to file
	var file := FileAccess.open(cache_path, FileAccess.WRITE)
	if not file:
		print("[ChunkCache] ERROR: Failed to create cache file: %s" % cache_path)
		return false

	file.store_string(json_string)
	file.close()

	chunks_saved += 1
	return true

## Clear all cached chunks for current seed
func clear_cache() -> void:
	var seed_dir := "%s%d/" % [cache_directory, world_seed]
	var dir := DirAccess.open(seed_dir)
	if not dir:
		return

	print("[ChunkCache] Clearing cache for seed %d..." % world_seed)

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var deleted_count := 0

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".chunk"):
			var error := dir.remove(file_name)
			if error == OK:
				deleted_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()

	print("[ChunkCache] Cleared %d cached chunks" % deleted_count)

	# Reset statistics
	chunks_saved = 0
	chunks_loaded = 0
	cache_hits = 0
	cache_misses = 0

## Clear entire cache directory (all seeds)
func clear_all_caches() -> void:
	var dir := DirAccess.open(cache_directory)
	if not dir:
		return

	print("[ChunkCache] Clearing entire cache directory...")

	# Remove all seed directories
	dir.list_dir_begin()
	var dir_name := dir.get_next()
	var deleted_seeds := 0

	while dir_name != "":
		if dir.current_is_dir() and dir_name != "." and dir_name != "..":
			_remove_directory_recursive(cache_directory + dir_name)
			deleted_seeds += 1
		dir_name = dir.get_next()

	dir.list_dir_end()

	print("[ChunkCache] Cleared %d seed caches" % deleted_seeds)

## Recursively remove a directory and its contents
func _remove_directory_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	# Remove all files
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Remove the directory itself
	var parent_dir := DirAccess.open(path.get_base_dir())
	if parent_dir:
		parent_dir.remove(path.get_file())

## Get cache statistics
func get_stats() -> Dictionary:
	return {
		"enabled": cache_enabled,
		"seed": world_seed,
		"cache_hits": cache_hits,
		"cache_misses": cache_misses,
		"hit_rate": (float(cache_hits) / max(cache_hits + cache_misses, 1)) * 100.0,
		"chunks_saved": chunks_saved,
		"chunks_loaded": chunks_loaded,
		"cache_size_mb": _get_cache_size_mb()
	}

## Get current cache size in megabytes
func _get_cache_size_mb() -> float:
	var seed_dir := "%s%d/" % [cache_directory, world_seed]
	var dir := DirAccess.open(seed_dir)
	if not dir:
		return 0.0

	var total_bytes := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".chunk"):
			var file_path := seed_dir + file_name
			var file := FileAccess.open(file_path, FileAccess.READ)
			if file:
				total_bytes += file.get_length()
				file.close()
		file_name = dir.get_next()

	dir.list_dir_end()

	return total_bytes / (1024.0 * 1024.0)

## Check if cache size exceeds maximum
func is_cache_full() -> bool:
	return _get_cache_size_mb() >= max_cache_size_mb

## Print cache statistics
func print_stats() -> void:
	var stats := get_stats()
	print("========================================")
	print("[ChunkCache] Statistics:")
	print("  Enabled: %s" % stats.enabled)
	print("  World Seed: %d" % stats.seed)
	print("  Cache Hits: %d" % stats.cache_hits)
	print("  Cache Misses: %d" % stats.cache_misses)
	print("  Hit Rate: %.1f%%" % stats.hit_rate)
	print("  Chunks Saved: %d" % stats.chunks_saved)
	print("  Chunks Loaded: %d" % stats.chunks_loaded)
	print("  Cache Size: %.2f MB / %d MB" % [stats.cache_size_mb, max_cache_size_mb])
	print("========================================")

## Update world seed (invalidates current cache)
func set_world_seed(new_seed: int) -> void:
	if new_seed != world_seed:
		print("[ChunkCache] World seed changed from %d to %d" % [world_seed, new_seed])
		world_seed = new_seed

		# Reset statistics for new seed
		cache_hits = 0
		cache_misses = 0
		chunks_saved = 0
		chunks_loaded = 0

		_ensure_cache_directory()
