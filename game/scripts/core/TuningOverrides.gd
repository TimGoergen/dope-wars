class_name TuningOverrides

# Dev/balance tuning overrides layered on top of res://config/tuning.tres.
# Identical pattern to American Tycoon: exported Android builds cannot write to res://,
# so the on-device Dev Tuning overlay writes changed constants to user://tuning_overrides.json.

const OVERRIDE_PATH := "user://tuning_overrides.json"
const OVERRIDE_FILENAME := "tuning_overrides.json"


static func load_overrides() -> Dictionary:
	if not FileAccess.file_exists(OVERRIDE_PATH):
		return {}
	var file := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


static func save(overrides: Dictionary) -> void:
	var file := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TuningOverrides: could not write " + OVERRIDE_PATH)
		return
	file.store_string(JSON.stringify(overrides, "\t", true, true))
	file.close()


static func clear() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(OVERRIDE_FILENAME):
		dir.remove(OVERRIDE_FILENAME)


static func apply(tuning: TuningConfig, overrides: Dictionary) -> void:
	for key in overrides.keys():
		var current: Variant = tuning.get(key)
		if current == null:
			continue
		var value: Variant = overrides[key]
		if not (value is float or value is int):
			continue
		if typeof(current) == TYPE_INT:
			tuning.set(key, int(value))
		else:
			tuning.set(key, float(value))
