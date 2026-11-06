extends SceneTree

# Gate 3: TradingAndCapacityTest — verifies buying, weighted average cost (Avg Paid), selling,
# dumping unlisted products, and capacity stacking (Carhartt + Crew + Vehicles) without gun weight.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var state := GameState.new(tuning, 1001)
	state.new_run(31, [], 1001)

	# Force deterministic prices for weed
	state.cash = 50000
	state.market_prices["weed"] = 400
	state.market_signals["weed"] = "normal"

	# 1. Buy 10 Weed @ $400 -> Avg Paid = $400
	var b1 := state.buy_product("weed", 10)
	_assert_true(bool(b1.get("ok", false)), "First buy ok")
	_assert_eq(int(state.inventory["weed"]["qty"]), 10, "Held 10 weed")
	_assert_eq(int(state.inventory["weed"]["avg_paid"]), 400, "Avg paid 400")
	_assert_eq(state.get_used_capacity(), 10, "Used capacity 10")

	# 2. Price rises to $600; Buy 10 more Weed -> Avg Paid = (10*400 + 10*600)/20 = $500
	state.market_prices["weed"] = 600
	state.buy_product("weed", 10)
	_assert_eq(int(state.inventory["weed"]["qty"]), 20, "Held 20 weed")
	_assert_eq(int(state.inventory["weed"]["avg_paid"]), 500, "Weighted avg paid 500")

	# 3. Sell 5 Weed @ $800 -> profit = 5 * (800 - 500) = $1,500; Avg Paid remains $500
	state.market_prices["weed"] = 800
	var s1 := state.sell_product("weed", 5)
	_assert_eq(int(s1.get("profit", 0)), 1500, "Profit on partial sale")
	_assert_eq(int(state.inventory["weed"]["qty"]), 15, "Remaining 15 weed")
	_assert_eq(int(state.inventory["weed"]["avg_paid"]), 500, "Avg paid preserved after partial sale")

	# 4. Unlisted product dump test
	state.market_prices["weed"] = 0
	var sell_unlisted := state.sell_product("weed", 5)
	_assert_true(not bool(sell_unlisted.get("ok", false)), "Cannot sell when unlisted")
	var d1 := state.dump_product("weed", 5)
	_assert_true(bool(d1.get("ok", false)), "Can dump when unlisted")
	_assert_eq(int(state.inventory["weed"]["qty"]), 10, "10 left after dump")

	# 5. Capacity progression & Guns not consuming drug pockets
	_assert_eq(state.get_max_capacity(), 100, "Initial capacity 100")
	state.cash = 1000000
	state.buy_weapon("ruger_22")
	_assert_eq(state.get_max_capacity(), 100, "Guns do not reduce drug pockets")
	_assert_eq(state.get_free_capacity(), 90, "Free capacity still 90 with 10 weed + 1 gun")

	state.hire_crew() # +10 capacity
	_assert_eq(state.get_max_capacity(), 110, "Crew adds +10 capacity")
	state.buy_vehicle(2) # Chevy Tahoe +150 capacity
	_assert_eq(state.get_max_capacity(), 260, "Tahoe adds +150 trunk capacity")

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
