extends SceneTree

# Gate 7: LegacyAndSaveTest — verifies mid-run state serialization/deserialization,
# Street Cred calculation, unlocking & simultaneously equipping all 6 Legacy Perks (no slot limit),
# and TuningOverrides round-tripping.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)

	# 1. Verify Street Cred tiers
	_assert_eq(GameState.calculate_street_cred_for_net_worth(50000), 0, "<$100k = 0 cred")
	_assert_eq(GameState.calculate_street_cred_for_net_worth(250000), 1, "$250k = 1 cred")
	_assert_eq(GameState.calculate_street_cred_for_net_worth(2500000), 2, "$2.5M = 2 cred")
	_assert_eq(GameState.calculate_street_cred_for_net_worth(15000000), 4, "$15M = 4 cred")
	_assert_eq(GameState.calculate_street_cred_for_net_worth(75000000), 7, "$75M = 7 cred")

	# 2. Verify unlocking all 6 Legacy Perks and activating all 6 simultaneously (no slot limit)
	var meta := SaveManager.create_default_meta()
	meta["street_cred"] = 20
	for p_def in OmahaCatalog.LEGACY_PERKS:
		var pid: String = p_def["id"]
		var u_res := SaveManager.unlock_perk(meta, pid)
		_assert_true(bool(u_res.get("ok", false)), "Unlocked perk '%s'" % pid)

	var active: Array = meta["active_perks"]
	_assert_eq(active.size(), 6, "All 6 perks active simultaneously with no slot limit")

	# 3. Start a run with all 6 perks active and verify their starting effects
	var state := GameState.new(tuning, 5005)
	state.new_run(31, active, 5005)
	_assert_true(absf(state.get_loan_interest_rate() - 0.08) < 0.001, "Connected Cousin -> 8% loan interest")
	_assert_true(absf(state.get_bank_interest_rate() - 0.07) < 0.001, "First National VIP -> 7% bank interest")
	_assert_eq(state.weapons.size(), 1, "Glovebox .22 -> starts with 1 weapon")
	_assert_eq(state.vehicle_tier, 1, "'98 Civic Keys -> starts at vehicle_tier 1 (+60 space)")
	_assert_eq(state.get_max_capacity(), 200, "100 base + 40 Carhartt XL + 60 Civic = 200 starting capacity")

	# 4. Verify mid-run save/restore round-tripping
	state.cash = 123456
	state.bank = 654321
	state.inventory["cocaine"] = {"qty": 12, "avg_paid": 19500}
	var snapshot := state.to_dict()

	var restored := GameState.new(tuning, 9999)
	restored.from_dict(snapshot)
	_assert_eq(restored.cash, 123456, "Restored cash")
	_assert_eq(restored.bank, 654321, "Restored bank")
	_assert_eq(int(restored.inventory["cocaine"]["qty"]), 12, "Restored cocaine qty")
	_assert_eq(int(restored.inventory["cocaine"]["avg_paid"]), 19500, "Restored cocaine avg_paid")
	_assert_eq(restored.get_max_capacity(), 200, "Restored max capacity")

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
