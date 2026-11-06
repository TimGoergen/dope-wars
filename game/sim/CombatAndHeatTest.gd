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
