class_name SaveManager

# Handles mid-run auto-save, Omaha Kingpin Legacy meta-progression (Street Cred & Perks),
# and the Hall of Fame leaderboard in user://save_game.json.

const SAVE_PATH := "user://save_game.json"
const SAVE_VERSION := 1
const MODE_KEYS: Array[String] = ["31", "60", "90", "endless"]


static func create_default_meta() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"street_cred": 0,
		"total_cred_earned": 0,
		"unlocked_perks": [],
		"active_perks": [],
		"preferred_mode_days": 31,
		"muted": false,
		"haptics_enabled": true,
		"hall_of_fame": {
			"31": [],
			"60": [],
			"90": [],
			"endless": []
		},
		"seen_screen_hints": [],
		"current_run": {}
	}


static func load_save(custom_path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(custom_path):
		return create_default_meta()
	var file := FileAccess.open(custom_path, FileAccess.READ)
	if file == null:
		return create_default_meta()
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return create_default_meta()
	var meta := create_default_meta()
	for k in parsed.keys():
		meta[k] = parsed[k]
	if not ("seen_screen_hints" in meta) or not (meta["seen_screen_hints"] is Array):
		meta["seen_screen_hints"] = []

	# Normalize/migrate hall_of_fame to a per-mode dictionary
	var raw_hof: Variant = meta.get("hall_of_fame", null)
	if raw_hof is Array:
		var partitioned: Dictionary = {
			"31": [],
			"60": [],
			"90": [],
			"endless": []
		}
		for entry in raw_hof:
			if entry is Dictionary:
				var m_key := get_mode_key(int(entry.get("max_days", 31)))
				(partitioned[m_key] as Array).append(entry)
		for k in MODE_KEYS:
			(partitioned[k] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("net_worth", 0)) > int(b.get("net_worth", 0))
			)
			if (partitioned[k] as Array).size() > 15:
				(partitioned[k] as Array).resize(15)
		meta["hall_of_fame"] = partitioned
	elif raw_hof is Dictionary:
		for k in MODE_KEYS:
			if not (k in raw_hof) or not (raw_hof[k] is Array):
				raw_hof[k] = []
		meta["hall_of_fame"] = raw_hof
	else:
		meta["hall_of_fame"] = {
			"31": [],
			"60": [],
			"90": [],
			"endless": []
		}

	return meta


static func save_data(meta: Dictionary, custom_path: String = SAVE_PATH) -> void:
	meta["version"] = SAVE_VERSION
	var file := FileAccess.open(custom_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: could not write " + custom_path)
		return
	file.store_string(JSON.stringify(meta, "\t", true))
	file.close()


static func unlock_perk(meta: Dictionary, perk_id: String) -> Dictionary:
	var unlocked: Array = meta.get("unlocked_perks", [])
	if unlocked.has(perk_id):
		return {"ok": false, "reason": "Already unlocked"}
	var p_def := OmahaCatalog.get_perk(perk_id)
	var cost := int(p_def["cost"])
	var cred := int(meta.get("street_cred", 0))
	if cred < cost:
		return {"ok": false, "reason": "Insufficient Street Cred"}
	meta["street_cred"] = cred - cost
	unlocked.append(perk_id)
	meta["unlocked_perks"] = unlocked

	# Automatically toggle ON newly unlocked perk (no slot limit per GDD v1.1 §9.1)
	var active: Array = meta.get("active_perks", [])
	if not active.has(perk_id):
		active.append(perk_id)
	meta["active_perks"] = active
	return {"ok": true, "street_cred": meta["street_cred"]}


static func toggle_perk(meta: Dictionary, perk_id: String) -> Dictionary:
	var unlocked: Array = meta.get("unlocked_perks", [])
	if not unlocked.has(perk_id):
		return {"ok": false, "reason": "Perk not unlocked yet"}
	var active: Array = meta.get("active_perks", [])
	if active.has(perk_id):
		active.erase(perk_id)
	else:
		active.append(perk_id)
	meta["active_perks"] = active
	return {"ok": true, "enabled": active.has(perk_id)}


static func get_mode_key(max_days: int) -> String:
	if max_days <= 0:
		return "endless"
	elif max_days == 60:
		return "60"
	elif max_days == 90:
		return "90"
	return "31"


static func get_mode_title(mode_key: String) -> String:
	match mode_key:
		"60":
			return "60 Days"
		"90":
			return "90 Days"
		"endless":
			return "Endless"
		_:
			return "31 Days"


static func get_mode_subtitle(mode_key: String) -> String:
	match mode_key:
		"60":
			return "South O to West Dodge • Run 24th St"
		"90":
			return "Florence to Bellevue • Own the Metro"
		"endless":
			return "River City Turf • No Deadlines"
		_:
			return "30th & Ames Sprint • Beat Big Sal"


static func get_hall_of_fame(meta: Dictionary, mode_key: String = "") -> Array:
	var raw: Variant = meta.get("hall_of_fame", null)
	if raw is Dictionary:
		if mode_key != "":
			var list: Variant = raw.get(mode_key, [])
			return list if list is Array else []
		var combined: Array = []
		for k in MODE_KEYS:
			var list: Variant = raw.get(k, [])
			if list is Array:
				combined.append_array(list)
		combined.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("net_worth", 0)) > int(b.get("net_worth", 0))
		)
		return combined
	elif raw is Array:
		if mode_key == "":
			return raw
		var filtered: Array = []
		for entry in raw:
			if entry is Dictionary and get_mode_key(int(entry.get("max_days", 31))) == mode_key:
				filtered.append(entry)
		return filtered
	return []


static func record_finished_run(meta: Dictionary, state: GameState, player_name: String = "Omaha Hustler") -> void:
	var earned := state.street_cred_earned if state.run_completed else 0
	meta["street_cred"] = int(meta.get("street_cred", 0)) + earned
	meta["total_cred_earned"] = int(meta.get("total_cred_earned", 0)) + earned

	var mode_key := get_mode_key(state.max_days)

	var raw_hof: Variant = meta.get("hall_of_fame", null)
	var hof_dict: Dictionary = {}
	if raw_hof is Dictionary:
		hof_dict = raw_hof
	elif raw_hof is Array:
		hof_dict = {"31": [], "60": [], "90": [], "endless": []}
		for entry in raw_hof:
			if entry is Dictionary:
				var k := get_mode_key(int(entry.get("max_days", 31)))
				(hof_dict[k] as Array).append(entry)
	else:
		hof_dict = {"31": [], "60": [], "90": [], "endless": []}

	for k in MODE_KEYS:
		if not (k in hof_dict) or not (hof_dict[k] is Array):
			hof_dict[k] = []

	var target_list: Array = hof_dict[mode_key]
	target_list.append({
		"name": player_name,
		"net_worth": state.final_net_worth if (state.run_completed or state.game_over) else state.get_net_worth(),
		"days": state.day,
		"max_days": state.max_days,
		"is_endless": state.is_endless,
		"district": OmahaCatalog.get_district(state.current_district_id)["name"],
		"survived": state.run_completed and not state.game_over,
		"fate": state.end_fate if state.end_fate != "" else "Retired Early",
		"cred_earned": earned
	})
	target_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("net_worth", 0)) > int(b.get("net_worth", 0))
	)
	if target_list.size() > 15:
		target_list.resize(15)

	hof_dict[mode_key] = target_list
	meta["hall_of_fame"] = hof_dict
	meta["current_run"] = {}
