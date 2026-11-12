class_name SaveManager

# Handles mid-run auto-save, Omaha Kingpin Legacy meta-progression (Street Cred & Perks),
# and the Hall of Fame leaderboard in user://save_game.json.

const SAVE_PATH := "user://save_game.json"
const SAVE_VERSION := 1


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
		"hall_of_fame": [],
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


static func record_finished_run(meta: Dictionary, state: GameState, player_name: String = "Omaha Hustler") -> void:
	var earned := state.street_cred_earned if state.run_completed else 0
	meta["street_cred"] = int(meta.get("street_cred", 0)) + earned
	meta["total_cred_earned"] = int(meta.get("total_cred_earned", 0)) + earned

	var hof: Array = meta.get("hall_of_fame", [])
	hof.append({
		"name": player_name,
		"net_worth": state.final_net_worth if (state.run_completed or state.game_over) else state.get_net_worth(),
		"days": state.day,
		"max_days": state.max_days,
		"district": OmahaCatalog.get_district(state.current_district_id)["name"],
		"survived": state.run_completed and not state.game_over,
		"fate": state.end_fate if state.end_fate != "" else "Retired Early",
		"cred_earned": earned
	})
	hof.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("net_worth", 0)) > int(b.get("net_worth", 0))
	)
	if hof.size() > 15:
		hof.resize(15)
	meta["hall_of_fame"] = hof
	meta["current_run"] = {}
