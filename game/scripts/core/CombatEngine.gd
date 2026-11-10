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
		"initial_cop_count": cop_hp_list.size(),
		"min_dmg": int(tier_def["min_dmg"]),
		"max_dmg": int(tier_def["max_dmg"]),
		"min_bounty": int(tier_def["min_bounty"]),
		"max_bounty": int(tier_def["max_bounty"]),
		"front_crew_hp": tuning.crew_encounter_hp if crew_count > 0 else 0,
		"round": 1,
		"total_player_dmg": 0,
		"total_cops_downed": 0,
		"total_hp_lost": 0,
		"total_armor_lost": 0,
		"total_crew_lost": 0,
		"last_log": "🚨 Pulled over by %s (+%d backup)!" % [tier_def["leader_name"], backup_count]
	}


static func generate_flavor_text(res: Dictionary) -> String:
	var outcome: String = String(res.get("outcome", "victory"))
	var tier: int = int(res.get("tier", 1))
	var leader_name: String = String(res.get("leader_name", "OPD Patrol"))
	var district: String = String(res.get("district_name", "Omaha"))
	var rounds: int = int(res.get("rounds", 1))
	var bounty: int = int(res.get("bounty", 0))
	var cops_downed: int = int(res.get("cops_downed", 0))
	var crew_killed: int = int(res.get("crew_killed", 0))
	var cash_lost: int = int(res.get("cash_lost", 0))
	var drugs_summary: String = String(res.get("drugs_summary", ""))
	var vehicle_name: String = String(res.get("vehicle_name", "Crown Victoria"))
	var day: int = int(res.get("day", 1))

	match outcome:
		"victory":
			var text := ""
			if tier >= 3:
				text = "You won! A deafening silence falls over the pavement in %s. Against all odds, you took down Agent Miller's heavily armed DEA Task Force in a fierce %d-round firefight. Their tactical cruisers sit smoking and riddled with bullet holes on the shoulder. Rummaging through their command vehicle, you cracked a seized lockbox and pocketed %s in unmarked cash! You neutralized %d federal officers and melted away before state backup arrived." % [
					district, rounds, Money.format(bounty), cops_downed
				]
			elif tier == 2:
				text = "You won! The flashing red and blue lights flicker against the brick walls of %s as the last cruiser falls silent. Sgt. Bob and his Douglas County deputies completely underestimated your firepower over %d intense rounds. Prying open their cruiser lockbox, you secured %s in civil forfeiture cash. With %d cruisers decommissioned, you reloaded and vanished down the back streets." % [
					district, rounds, Money.format(bounty), cops_downed
				]
			else:
				text = "You won! The gunsmoke slowly clears over an empty parking lot in %s. Officer Hardass and the OPD patrol squad have been completely neutralized after %d rounds of close-quarters shooting. Radio dispatch crackles with frantic calls for backup, but you're already digging through their squad car. You pocketed %s in cash and took down %d cruiser units. The neighborhood is yours." % [
					district, rounds, Money.format(bounty), cops_downed
				]
			if crew_killed > 0:
				text += " In the crossfire, %d of your armed runners went down." % crew_killed
			return text

		"escaped":
			if rounds <= 1:
				return "You won! You slammed the accelerator on your %s the instant %s triggered their sirens in %s! Tires smoking and engine roaring, you whipped hard through a tight alleyway off 24th Street and sliced across oncoming traffic. Behind an old warehouse, you killed your lights in the darkness as the cruiser convoy blew past on the main avenue. Clean getaway—your stash and cash remain completely untouched." % [
					vehicle_name, leader_name, district
				]
			else:
				return "You won! After %d harrowing rounds evading roadblocks and taking fire in %s, you found an opening and floored your %s! Sparking off a concrete guardrail, you blew through a yellow light and weaved through heavy industrial traffic. %s's cruisers were trapped behind a stalled semi, losing your trail completely. You took some damage in the pursuit, but you shook the tail and escaped with your stash intact!" % [
					rounds, district, vehicle_name, leader_name
				]

		"surrendered":
			var stash_desc := drugs_summary if drugs_summary != "" else "No contraband found"
			return "You lose. Blinded by high-powered spotlights and pinned behind cover in %s, you realized you were hopelessly outgunned. You threw your piece onto the concrete and stepped out with your hands raised high.\n\n%s's officers slammed you against the cruiser hood and searched every pocket of your coat. They seized %s from your wallet and confiscated your entire drug stash (%s) as evidence.\n\nAfter a grueling night in central booking, your lawyer posted bail. You're back on the street with empty pockets, but your Heat has cooled down to 10%%." % [
				district, leader_name, Money.format(cash_lost), stash_desc
			]

		"killed":
			return "You lose. A devastating volley of gunfire from %s shatters your windshield and punches through your cover in %s. As your vision fades and the cold asphalt rushes up to meet you, the distant wail of sirens and flashing red-and-blue lights blur into the night. Your street run comes to a bloody end on Day %d—just another cautionary tale on the evening news." % [
				leader_name, district, day
			]

		_:
			return "The police encounter in %s with %s has concluded after %d rounds." % [
				district, leader_name, rounds
			]


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
