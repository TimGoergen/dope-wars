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
