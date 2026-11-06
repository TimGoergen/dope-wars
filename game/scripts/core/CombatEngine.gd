class_name CombatEngine

# Pure headless Police Heat & Combat resolution engine (GDD v1.1 §6).
# Implements the 3 Omaha law enforcement tiers (OPD Hardass, Sheriff Bob, DEA Miller)
# and the Shared 50/50 Target Pool with 30 HP per-encounter Crew durability.


static func get_cop_tier_for_heat(heat: float) -> Dictionary:
	if heat >= 70.0:
		return {
			"tier": 3,
			"leader_name": "Agent Miller (I-80 DEA Task Force)",
			"short_badge": "DEA",
			"min_backup": 2,
			"max_backup": 5,
			"unit_hp": 110,
			"min_dmg": 16,
			"max_dmg": 28,
			"min_bounty": 20000,
			"max_bounty": 60000
		}
	if heat >= 35.0:
		return {
			"tier": 2,
			"leader_name": "Sgt. Bob (Douglas Co. Sheriff)",
			"short_badge": "SHERIFF",
			"min_backup": 1,
			"max_backup": 3,
			"unit_hp": 55,
			"min_dmg": 9,
			"max_dmg": 16,
			"min_bounty": 5000,
			"max_bounty": 15000
		}
	return {
		"tier": 1,
		"leader_name": "Officer Hardass (OPD Patrol)",
		"short_badge": "OPD",
		"min_backup": 0,
		"max_backup": 2,
		"unit_hp": 25,
		"min_dmg": 4,
		"max_dmg": 9,
		"min_bounty": 1000,
		"max_bounty": 4000
	}


static func get_ambush_chance_pct(
	district_id: String,
	heat: float,
	has_scanner_perk: bool,
	tuning: TuningConfig
) -> float:
	var district := OmahaCatalog.get_district(district_id)
	var base_pct := float(district.get("base_cop_pct", 15.0))
	var raw := base_pct + (heat * tuning.heat_ambush_scale)
	if has_scanner_perk:
		raw -= tuning.scanner_perk_ambush_reduction
	return clampf(raw, 5.0, 75.0)


static func create_encounter(
	heat: float,
	crew_count: int,
	tuning: TuningConfig,
	rng: RandomNumberGenerator
) -> Dictionary:
	var tier_def := get_cop_tier_for_heat(heat)
	var backup_count := rng.randi_range(int(tier_def["min_backup"]), int(tier_def["max_backup"]))
	var unit_hp := int(tier_def["unit_hp"])
	var cop_hp_list: Array[int] = []
	# Backup officers sit in front of the lead officer.
	for _i in range(backup_count):
		cop_hp_list.append(unit_hp)
	cop_hp_list.append(unit_hp) # Lead officer last

	return {
		"active": true,
		"tier": int(tier_def["tier"]),
		"leader_name": String(tier_def["leader_name"]),
		"short_badge": String(tier_def["short_badge"]),
		"unit_hp": unit_hp,
		"cop_hp_list": cop_hp_list,
		"min_dmg": int(tier_def["min_dmg"]),
		"max_dmg": int(tier_def["max_dmg"]),
		"min_bounty": int(tier_def["min_bounty"]),
		"max_bounty": int(tier_def["max_bounty"]),
		"front_crew_hp": tuning.crew_encounter_hp if crew_count > 0 else 0,
		"round": 1,
		"last_log": "🚨 Pulled over by %s (+%d backup)!" % [tier_def["leader_name"], backup_count]
	}


static func get_escape_chance(
	encounter: Dictionary,
	vehicle_tier: int,
	tuning: TuningConfig
) -> float:
	var cops: Array = encounter.get("cop_hp_list", [])
	var backup_alive := maxi(0, cops.size() - 1)
	var v_def := OmahaCatalog.get_vehicle(vehicle_tier)
	var v_bonus := float(v_def.get("escape_bonus", 0.0))
	var chance := tuning.base_escape_chance + v_bonus - (float(backup_alive) * tuning.escape_penalty_per_backup)
	return clampf(chance, 0.20, 0.85)
