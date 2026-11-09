extends SceneTree

# Gate 2: MarketEngineTest — verifies 12 products, district affinities, 100% Final Day guarantee,
# and all 12 products participating in 4x Spike and 1/4 Flood events.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 1. Verify Final Day guarantees all 12 products are listed
	for i in range(20):
		var res := MarketEngine.roll_daily_market("west_omaha", true, {}, tuning, rng)
		var prices: Dictionary = res["prices"]
		for p_def in OmahaCatalog.PRODUCTS:
			var pid: String = p_def["id"]
			if int(prices.get(pid, 0)) <= 0:
				printerr("FAIL: Product '%s' unlisted on Final Day!" % pid)
				_failures += 1

	# 2. Verify forced event (Blackstone VIP Intel / Tip-off) guarantees listing and multiplier
	for p_def in OmahaCatalog.PRODUCTS:
		var pid: String = p_def["id"]
		var max_normal := int(tuning.get(p_def["max_prop"]))
		var min_normal := int(tuning.get(p_def["min_prop"]))

		var spike_res := MarketEngine.roll_daily_market("bellevue", false, {"product_id": pid, "event_type": "spike"}, tuning, rng)
		var sp_price := int(spike_res["prices"][pid])
		var sp_sig := String(spike_res["signals"][pid])
		_assert_true(sp_price >= min_normal * 4, "Spike price for %s (%d >= %d)" % [pid, sp_price, min_normal * 4])
		_assert_eq(sp_sig, "spike", "Spike signal for %s" % pid)

		var flood_res := MarketEngine.roll_daily_market("bellevue", false, {"product_id": pid, "event_type": "flood"}, tuning, rng)
		var fl_price := int(flood_res["prices"][pid])
		var fl_sig := String(flood_res["signals"][pid])
		_assert_true(fl_price <= int(ceil(float(max_normal) / 4.0)), "Flood price for %s (%d)" % [pid, fl_price])
		_assert_eq(fl_sig, "flood", "Flood signal for %s" % pid)

	# 3. Verify District Affinities (West Omaha 1.20x Cocaine, Council Bluffs 0.80x Meth)
	var west_o := OmahaCatalog.get_district("west_omaha")
	var cb := OmahaCatalog.get_district("council_bluffs")
	_assert_true(absf(MarketEngine.get_district_affinity_multiplier(west_o, "cocaine", tuning) - 1.20) < 0.001, "West O Cocaine 1.20x")
	_assert_true(absf(MarketEngine.get_district_affinity_multiplier(cb, "meth", tuning) - 0.80) < 0.001, "Council Bluffs Meth 0.80x")

	# 4. Verify CHEAP ("low") and PRICY ("high") signals strictly match actual price quartiles
	for _day in range(50):
		for d_def in OmahaCatalog.DISTRICTS:
			var did := String(d_def["id"])
			var mres := MarketEngine.roll_daily_market(did, false, {}, tuning, rng)
			var mprices: Dictionary = mres["prices"]
			var msigs: Dictionary = mres["signals"]
			for p_def in OmahaCatalog.PRODUCTS:
				var pid: String = p_def["id"]
				var pr := int(mprices[pid])
				var sg := String(msigs[pid])
				var min_p := int(tuning.get(p_def["min_prop"]))
				var max_p := int(tuning.get(p_def["max_prop"]))
				var span := float(max_p - min_p)
				if sg == "low":
					_assert_true(float(pr) <= float(min_p) + span * 0.25, "Low signal price check (%s: %d)" % [pid, pr])
				elif sg == "high":
					_assert_true(float(pr) >= float(min_p) + span * 0.75, "High signal price check (%s: %d)" % [pid, pr])

	# 5. Verify Travel screen preview matches post-travel market prices & signals 100%
	var gs := GameState.new(tuning, 12345)
	gs.new_run(31, [], 12345)
	for target_id in ["council_bluffs", "benson", "west_omaha", "south_omaha"]:
		var preview := gs.get_next_day_market_preview(target_id)
		var prev_sigs: Dictionary = preview["signals"].duplicate()
		var prev_prices: Dictionary = preview["prices"].duplicate()
		gs.drive_to_district(target_id)
		for p_def in OmahaCatalog.PRODUCTS:
			var pid: String = p_def["id"]
			_assert_eq(gs.market_signals[pid], prev_sigs[pid], "Travel preview signal match (%s in %s)" % [pid, target_id])
			_assert_eq(gs.market_prices[pid], prev_prices[pid], "Travel preview price match (%s in %s)" % [pid, target_id])

	# Verify staying in the same district advances day and matches preview 100%
	var stay_id := gs.current_district_id
	var stay_prev := gs.get_next_day_market_preview(stay_id)
	var stay_sigs: Dictionary = stay_prev["signals"].duplicate()
	var stay_prices: Dictionary = stay_prev["prices"].duplicate()
	var prev_day := gs.day
	gs.drive_to_district(stay_id)
	_assert_eq(gs.day, prev_day + 1, "Stay for a day advances day count")
	_assert_eq(gs.current_district_id, stay_id, "Stay for a day preserves district")
	for p_def in OmahaCatalog.PRODUCTS:
		var pid: String = p_def["id"]
		_assert_eq(gs.market_signals[pid], stay_sigs[pid], "Stay preview signal match (%s in %s)" % [pid, stay_id])
		_assert_eq(gs.market_prices[pid], stay_prices[pid], "Stay preview price match (%s in %s)" % [pid, stay_id])

	# 6. Verify 5-tier price meter calculation across full range
	var t1 := MarketEngine.calc_price_tier(100, 100, 600)
	_assert_eq(t1["active_count"], 1, "Min price has 1 active dollar")
	_assert_eq(t1["label"], "★ STEAL", "Tier 1 label is STEAL")

	var t2 := MarketEngine.calc_price_tier(250, 100, 600)
	_assert_eq(t2["active_count"], 2, "30% position has 2 active dollars")
	_assert_eq(t2["label"], "CHEAP", "Tier 2 label is CHEAP")

	var t3 := MarketEngine.calc_price_tier(350, 100, 600)
	_assert_eq(t3["active_count"], 3, "50% position has 3 active dollars")
	_assert_eq(t3["label"], "FAIR", "Tier 3 label is FAIR")

	var t4 := MarketEngine.calc_price_tier(450, 100, 600)
	_assert_eq(t4["active_count"], 4, "70% position has 4 active dollars")
	_assert_eq(t4["label"], "HIGH", "Tier 4 label is HIGH")

	var t5 := MarketEngine.calc_price_tier(600, 100, 600)
	_assert_eq(t5["active_count"], 5, "Max price has 5 active dollars")
	_assert_eq(t5["label"], "PRICY", "Tier 5 label is PRICY")

	var t_spike := MarketEngine.calc_price_tier(1200, 100, 600)
	_assert_eq(t_spike["active_count"], 5, "Spike clamped to 5 active dollars")

	var t_flood := MarketEngine.calc_price_tier(25, 100, 600)
	_assert_eq(t_flood["active_count"], 1, "Flood clamped to 1 active dollar")

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
