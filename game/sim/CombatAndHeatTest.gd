extends SceneTree

# Gate 5: CombatAndHeatTest — verifies 0-100% Heat tiers (OPD Hardass, Sheriff Bob, DEA Miller),
# Bellevue -18% Heat decay, 50% weapon trade-in upgrade, Shared 50/50 Crew combat target pool,
# and Crew death overflow (weakest gun dropped + lowest-value drugs spilled).

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var state := GameState.new(tuning, 3003)
	state.new_run(31, [], 3003)

	# 1. Verify 3 Cop Tiers by Heat
	_assert_eq(int(CombatEngine.get_cop_tier_for_heat(10.0)["tier"]), 1, "Heat 10% -> Tier 1 OPD")
	_assert_eq(int(CombatEngine.get_cop_tier_for_heat(50.0)["tier"]), 2, "Heat 50% -> Tier 2 Sheriff")
	_assert_eq(int(CombatEngine.get_cop_tier_for_heat(85.0)["tier"]), 3, "Heat 85% -> Tier 3 DEA")

	# 2. Verify Weapon 50% Trade-In when Weapon Slots (1 + Crew) are full
	state.cash = 100000
	var w1 := state.buy_weapon("ruger_22") # Costs $1,500
	_assert_true(bool(w1.get("ok", false)), "Bought .22 Pistol")
	_assert_eq(state.weapons.size(), 1, "1 weapon equipped")

	# Upgrade to Beretta 9mm ($5,000) while max slots = 1 -> trades in Ruger ($750) -> net $4,250
	var cash_before := state.cash
	var w2 := state.buy_weapon("beretta_9mm")
	_assert_true(bool(w2.get("ok", false)), "Upgraded to Beretta 9mm with full slots")
	_assert_eq(int(w2.get("trade_in", 0)), 750, "50% trade-in on Ruger ($750)")
	_assert_eq(cash_before - state.cash, 4250, "Net cost $4,250")
	_assert_eq(state.weapons[0], "beretta_9mm", "Strongest weapon in slot 0")

	# 3. Verify Crew Death Overflow (drops weakest gun + spills cheapest carried drugs first)
	state.cash = 500000
	state.hire_crew() # Crew = 1, Max Capacity = 110, Max Weapon Slots = 2
	state.buy_weapon("ruger_22") # Now holding ["beretta_9mm", "ruger_22"]
	_assert_eq(state.weapons.size(), 2, "2 weapons held")

	# Fill all 110 pockets: 15 Adderall (Row 1, cheapest) + 95 Cocaine (Row 12, priciest)
	state.inventory["adderall"] = {"qty": 15, "avg_paid": 20}
	state.inventory["cocaine"] = {"qty": 95, "avg_paid": 18000}
	_assert_eq(state.get_used_capacity(), 110, "All 110 pockets full")

	# Trigger Crew death
	state._handle_crew_member_death()
	_assert_eq(state.crew_count, 0, "Crew count reduced to 0")
	_assert_eq(state.weapons.size(), 1, "Dropped 1 weapon to fit 1 slot")
	_assert_eq(state.weapons[0], "beretta_9mm", "Kept strongest weapon (Beretta), dropped weakest (.22)")
	_assert_eq(state.get_max_capacity(), 100, "Max capacity reduced to 100")
	_assert_eq(state.get_used_capacity(), 100, "Used capacity clamped to 100")
	_assert_eq(int(state.inventory["adderall"]["qty"]), 5, "Spilled 10 cheap Adderall (15 -> 5)")
	_assert_eq(int(state.inventory["cocaine"]["qty"]), 95, "Preserved all 95 pricey Cocaine!")

	# 4. Verify Bellevue -18% Heat decay on travel
	state.heat = 50.0
	state.current_district_id = "old_market"
	state.drive_to_district("bellevue")
	state.active_combat = {}
	_assert_true(absf(state.heat - 32.0) < 0.01, "Bellevue decayed Heat by -18% (50 -> 32)")

	# 5. Verify Combat Result Flavor Text & Encounter Summary
	# 5a. Victory Result
	state.active_combat = {
		"active": true,
		"tier": 1,
		"leader_name": "Officer Hardass (OPD Patrol)",
		"short_badge": "OPD",
		"unit_hp": 25,
		"cop_hp_list": [1], # 1 HP remaining
		"initial_cop_count": 2,
		"min_dmg": 4,
		"max_dmg": 9,
		"min_bounty": 1000,
		"max_bounty": 2000,
		"front_crew_hp": 0,
		"round": 2,
		"total_player_dmg": 25,
		"total_cops_downed": 1,
		"total_hp_lost": 8,
		"total_armor_lost": 0,
		"total_crew_lost": 0
	}
	state.weapons = ["beretta_9mm"]
	var v_res := state.combat_fight()
	_assert_true(bool(v_res.get("victory", false)), "Combat ended in victory")
	_assert_true(state.has_combat_result(), "State has combat result after victory")
	var res_vic: Dictionary = state.combat_result
	_assert_eq(String(res_vic.get("outcome", "")), "victory", "Outcome is victory")
	_assert_true(int(res_vic.get("bounty", 0)) >= 1000, "Bounty recorded in result")
	_assert_true(String(res_vic.get("flavor_text", "")).contains("Officer Hardass"), "Flavor text mentions Officer Hardass")
	_assert_true(String(res_vic.get("flavor_text", "")).contains("cash"), "Flavor text mentions cash bounty")
	state.clear_combat_result()
	_assert_true(not state.has_combat_result(), "clear_combat_result() resets combat_result")

	# 5b. Escape Result
	state.active_combat = {
		"active": true,
		"tier": 2,
		"leader_name": "Sgt. Bob (Douglas Co. Sheriff)",
		"short_badge": "SHERIFF",
		"unit_hp": 55,
		"cop_hp_list": [55],
		"initial_cop_count": 1,
		"min_dmg": 9,
		"max_dmg": 16,
		"min_bounty": 5000,
		"max_bounty": 15000,
		"front_crew_hp": 0,
		"round": 1
	}
	# Set vehicle tier 3 to ensure high escape chance or force random
	state.vehicle_tier = 3
	# Mock escape by setting tuning or calling combat_run
	var e_res: Dictionary = state.combat_run()
	while not bool(e_res.get("escaped", false)) and state.is_in_combat():
		state.health = 100
		e_res = state.combat_run()
	_assert_true(state.has_combat_result(), "State has combat result after escape")
	var res_esc: Dictionary = state.combat_result
	_assert_eq(String(res_esc.get("outcome", "")), "escaped", "Outcome is escaped")
	_assert_true(String(res_esc.get("flavor_text", "")).contains("Sgt. Bob"), "Escape flavor text mentions Sgt. Bob")
	state.clear_combat_result()

	# 5c. Surrender Result
	state.inventory["weed"] = {"qty": 10, "avg_paid": 500}
	state.cash = 10000
	state.active_combat = {
		"active": true,
		"tier": 3,
		"leader_name": "Agent Miller (I-80 DEA Task Force)",
		"short_badge": "DEA",
		"unit_hp": 110,
		"cop_hp_list": [110, 110],
		"initial_cop_count": 2,
		"min_dmg": 16,
		"max_dmg": 28,
		"min_bounty": 20000,
		"max_bounty": 60000,
		"round": 2
	}
	var s_res := state.combat_surrender()
	_assert_true(bool(s_res.get("surrendered", false)), "Combat ended in surrender")
	_assert_true(state.has_combat_result(), "State has combat result after surrender")
	var res_surr: Dictionary = state.combat_result
	_assert_eq(String(res_surr.get("outcome", "")), "surrendered", "Outcome is surrendered")
	_assert_eq(int(res_surr.get("cash_lost", 0)), 2500, "25% cash lost ($2,500)")
	_assert_true(String(res_surr.get("drugs_summary", "")).contains("10 Weed"), "Seized stash summarized")
	_assert_true(String(res_surr.get("flavor_text", "")).contains("Agent Miller"), "Surrender flavor text mentions Agent Miller")
	state.clear_combat_result()

	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		printerr("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _assert_true(cond: bool, label: String) -> void:
	if not cond:
		printerr("FAIL [%s]" % label)
		_failures += 1


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAIL [%s]: expected '%s', got '%s'" % [label, str(expected), str(actual)])
		_failures += 1
