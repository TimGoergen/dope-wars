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

	# 5. Verify Per-Game-Mode Hall of Fame Tracking & Migration
	_assert_eq(SaveManager.get_mode_key(31), "31", "31 days mode key")
	_assert_eq(SaveManager.get_mode_key(60), "60", "60 days mode key")
	_assert_eq(SaveManager.get_mode_key(90), "90", "90 days mode key")
	_assert_eq(SaveManager.get_mode_key(0), "endless", "0 days endless mode key")
	_assert_eq(SaveManager.get_mode_key(-1), "endless", "-1 days endless mode key")

	var hof_meta := SaveManager.create_default_meta()
	_assert_true(hof_meta.get("hall_of_fame") is Dictionary, "Default meta has dictionary hall_of_fame")
	for m in SaveManager.MODE_KEYS:
		_assert_true(hof_meta["hall_of_fame"].has(m), "Default meta has mode '%s'" % m)

	# Simulate finished runs across different modes
	# 31-day run
	var s31 := GameState.new(tuning, 101)
	s31.new_run(31, [], 101)
	s31.cash = 500000
	s31.day = 31
	s31.run_completed = true
	s31.final_net_worth = 500000
	s31.end_fate = "Retired Kingpin"
	SaveManager.record_finished_run(hof_meta, s31, "Sprint Player")

	# 60-day run
	var s60 := GameState.new(tuning, 102)
	s60.new_run(60, [], 102)
	s60.cash = 1200000
	s60.day = 60
	s60.run_completed = true
	s60.final_net_worth = 1200000
	s60.end_fate = "Midwest Legend"
	SaveManager.record_finished_run(hof_meta, s60, "Mid-Distance Player")

	# Endless run
	var sendless := GameState.new(tuning, 103)
	sendless.new_run(0, [], 103)
	sendless.cash = 9999999
	sendless.day = 145
	sendless.game_over = true
	sendless.final_net_worth = 9999999
	sendless.end_fate = "Downed in Firefight"
	SaveManager.record_finished_run(hof_meta, sendless, "Endless Hustler")

	# Verify isolation between modes
	var hof_31 := SaveManager.get_hall_of_fame(hof_meta, "31")
	var hof_60 := SaveManager.get_hall_of_fame(hof_meta, "60")
	var hof_90 := SaveManager.get_hall_of_fame(hof_meta, "90")
	var hof_endless := SaveManager.get_hall_of_fame(hof_meta, "endless")

	_assert_eq(hof_31.size(), 1, "Mode 31 has exactly 1 entry")
	_assert_eq(hof_60.size(), 1, "Mode 60 has exactly 1 entry")
	_assert_eq(hof_90.size(), 0, "Mode 90 has 0 entries")
	_assert_eq(hof_endless.size(), 1, "Mode endless has exactly 1 entry")

	_assert_eq(int(hof_31[0]["net_worth"]), 500000, "Mode 31 net worth matches")
	_assert_eq(int(hof_60[0]["net_worth"]), 1200000, "Mode 60 net worth matches")
	_assert_eq(int(hof_endless[0]["net_worth"]), 9999999, "Mode endless net worth matches")

	# Add a second 31-day run with higher net worth and verify sorting descending
	var s31_b := GameState.new(tuning, 104)
	s31_b.new_run(31, [], 104)
	s31_b.cash = 800000
	s31_b.day = 31
	s31_b.run_completed = true
	s31_b.final_net_worth = 800000
	s31_b.end_fate = "Top Omaha Boss"
	SaveManager.record_finished_run(hof_meta, s31_b, "Sprint Boss")

	var hof_31_sorted := SaveManager.get_hall_of_fame(hof_meta, "31")
	_assert_eq(hof_31_sorted.size(), 2, "Mode 31 now has 2 entries")
	_assert_eq(int(hof_31_sorted[0]["net_worth"]), 800000, "Top 31-day score is sorted first")
	_assert_eq(int(hof_31_sorted[1]["net_worth"]), 500000, "Second 31-day score is sorted second")

	# Verify combined get_hall_of_fame with empty string
	var all_hof := SaveManager.get_hall_of_fame(hof_meta, "")
	_assert_eq(all_hof.size(), 4, "All modes combined has 4 entries")
	_assert_eq(int(all_hof[0]["net_worth"]), 9999999, "Highest net worth is first in combined list")

	# 6. Verify legacy flat Array migration
	var legacy_meta := {
		"hall_of_fame": [
			{"name": "Legacy 31", "net_worth": 100000, "max_days": 31, "days": 31},
			{"name": "Legacy 90", "net_worth": 3000000, "max_days": 90, "days": 90},
			{"name": "Legacy Endless", "net_worth": 5000000, "max_days": 0, "days": 50}
		]
	}
	var migrated_31 := SaveManager.get_hall_of_fame(legacy_meta, "31")
	var migrated_90 := SaveManager.get_hall_of_fame(legacy_meta, "90")
	var migrated_endless := SaveManager.get_hall_of_fame(legacy_meta, "endless")
	_assert_eq(migrated_31.size(), 1, "Legacy array filtered for 31 days")
	_assert_eq(migrated_90.size(), 1, "Legacy array filtered for 90 days")
	_assert_eq(migrated_endless.size(), 1, "Legacy array filtered for endless")

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
