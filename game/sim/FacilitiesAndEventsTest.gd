extends SceneTree

# Gate 6: FacilitiesAndEventsTest — verifies Benson Clinic healing & kidney sale (Max HP -> 80),
# Council Bluffs 90% Bank-wired Cage Chip Laundering (-15% Heat) & High-Card bet,
# Old Market Lawyer Heat reduction, and Blackstone VIP actionable Intel.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var state := GameState.new(tuning, 4004)
	state.new_run(31, [], 4004)

	# 1. Benson Clinic: Heal & Sell a Kidney
	state.health = 60
	state.cash = 10000
	var h_res := state.heal_player(40)
	_assert_true(bool(h_res.get("ok", false)), "Clinic heal ok")
	_assert_eq(state.health, 100, "Healed to 100")

	var cash_before_kidney := state.cash
	var k_res := state.sell_kidney()
	_assert_true(bool(k_res.get("ok", false)), "First kidney sale ok")
	_assert_eq(state.max_health, 80, "Max HP capped at 80 after kidney sale")
	_assert_eq(state.health, 80, "Current HP clamped to 80")
	_assert_eq(state.cash - cash_before_kidney, 2500, "+$2,500 emergency cash from kidney")
	var k_second := state.sell_kidney()
	_assert_true(not bool(k_second.get("ok", false)), "Cannot sell kidney twice")

	# 2. Council Bluffs Riverboat Casino: Cage Chip Laundering (10% cut -> 90% wired to Bank, -15% Heat)
	state.cash = 20000
	state.bank = 0
	state.heat = 40.0
	var wash_res := state.casino_launder_chips(10000)
	_assert_true(bool(wash_res.get("ok", false)), "Cage chip launder ok")
	_assert_eq(state.cash, 10000, "$10k deducted from pocket cash")
	_assert_eq(state.bank, 9000, "$9k (90%) wired directly to Bank")
	_assert_true(absf(state.heat - 25.0) < 0.01, "Heat dropped by -15% (40 -> 25)")

	# 3. West Omaha Defense Attorney: Suppress (40% of heat) and Expunge All
	state.cash = 50000
	var part_cost := state.get_lawyer_cost(false)
	var all_cost := state.get_lawyer_cost(true)
	_assert_true(abs(part_cost - int(round(all_cost * 0.40))) <= 1, "Suppress cost is 40% of expunge all cost")
	var supp_res := state.hire_lawyer(false)
	_assert_true(bool(supp_res.get("ok", false)), "Lawyer suppress ok")
	_assert_true(absf(state.heat - 15.0) < 0.01, "Heat reduced by 40% (25 -> 15)")
	var law_res := state.hire_lawyer(true)
	_assert_true(bool(law_res.get("ok", false)), "Lawyer clear all heat ok")
	_assert_true(absf(state.heat) < 0.01, "Heat cleared to 0%")

	# 4. Blackstone VIP Booth: "spike_buy_now" only picks a drug sold in Blackstone TODAY
	state.current_district_id = "blackstone"
	state._roll_market_for_current_district()
	state.cash = 50000
	var vip_res := state.buy_vip_intel("spike_buy_now")
	_assert_true(bool(vip_res.get("ok", false)), "Bought VIP intel")
	var tipped_pid := String(state.pending_forecast_event.get("product_id", ""))
	_assert_true(int(state.market_prices.get(tipped_pid, 0)) > 0, "Tipped spike drug '%s' is available to buy TODAY" % tipped_pid)

	# Drive to West Omaha tomorrow -> verify tipped drug is 100% guaranteed to SPIKE 4x!
	state.drive_to_district("west_omaha")
	state.active_combat = {}
	_assert_eq(String(state.market_signals.get(tipped_pid, "")), "spike", "Tipped drug '%s' spiked 4x tomorrow" % tipped_pid)

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
