extends SceneTree

# Gate 8: FullRunSimTest — runs 40 complete 31-day automated bot runs across all 8 Omaha districts
# to verify zero runtime errors, invariant preservation, and economy health.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var wins := 0
	var total_final_nw := 0

	for run_idx in range(40):
		var seed_val := 7000 + run_idx * 17
		var state := GameState.new(tuning, seed_val)
		state.new_run(31, ["glovebox_22", "carhartt_xl"], seed_val)

		while not state.game_over and not state.run_completed:
			# 1. Resolve combat if ambushed (run early unless well-armed, fight when upgraded)
			var safety := 0
			while state.is_in_combat() and not state.game_over and safety < 30:
				safety += 1
				var has_heavy_gun := (not state.weapons.is_empty()) and (state.weapons[0] != "ruger_22")
				if has_heavy_gun and state.health >= 55:
					state.combat_fight()
				else:
					state.combat_run()
			if state.game_over:
				break

			# 2. Accept Carhartt upgrade if offered
			if not state.pending_choice_event.is_empty():
				state.accept_choice_event()

			# 3. Sell any profitable held products (or liquidate everything on Day 31)
			for p_def in OmahaCatalog.PRODUCTS:
				var pid: String = p_def["id"]
				var held := int(state.inventory[pid]["qty"])
				var avg := int(state.inventory[pid]["avg_paid"])
				var mkt := int(state.market_prices.get(pid, 0))
				if held > 0 and mkt > 0:
					if state.is_final_day() or mkt > avg:
						state.sell_all(pid)

			# 4. Use local district facilities smartly
			if state.current_district_id == "north_omaha" and state.debt > 0 and state.cash > 0:
				var pay_amt := state.debt if state.cash >= state.debt * 2 else int(ceil(float(state.debt) * 0.20))
				state.pay_loan(mini(state.cash, pay_amt))
			elif state.current_district_id == "south_omaha" and state.cash >= 25000:
				if state.armor < 50:
					state.buy_armor(false)
				state.buy_weapon("mossberg_12g")
			elif state.current_district_id == "benson" and state.health < 75 and state.cash >= 5000:
				state.heal_player(state.max_health - state.health)
			elif state.current_district_id == "bellevue" and state.vehicle_tier == 0 and state.cash >= 20000:
				state.buy_vehicle(1)

			# 5. If Final Day, settle and finish run
			if state.is_final_day():
				state.finish_run()
				break

			# 6. Buy smartly: 1st priority Flood (1/4), 2nd priority below 65% of normal range
			var need_to_pay_sal := (state.debt > 0 and state.days_since_loan_payment >= 5)
			var reserve := mini(state.cash, int(ceil(float(state.debt) * 0.15))) if need_to_pay_sal else 0
			# Pass 1: Flood drugs
			for i in range(OmahaCatalog.PRODUCTS.size() - 1, -1, -1):
				var p_def: Dictionary = OmahaCatalog.PRODUCTS[i]
				var pid: String = p_def["id"]
				var price := int(state.market_prices.get(pid, 0))
				var sig := String(state.market_signals.get(pid, "normal"))
				if price > 0 and state.day < 31 and sig == "flood":
					var avail_cash := maxi(0, state.cash - reserve)
					var qty := mini(int(avail_cash / price), state.get_free_capacity())
					if qty > 0:
						state.buy_product(pid, qty)
			# Pass 2: Below 65% of normal price range
			for i in range(OmahaCatalog.PRODUCTS.size() - 1, -1, -1):
				var p_def: Dictionary = OmahaCatalog.PRODUCTS[i]
				var pid: String = p_def["id"]
				var price := int(state.market_prices.get(pid, 0))
				var min_p := int(tuning.get(p_def["min_prop"]))
				var max_p := int(tuning.get(p_def["max_prop"]))
				var good_buy_threshold := int(float(min_p + max_p) * 0.65)
				if price > 0 and state.day < 30 and price <= good_buy_threshold:
					var avail_cash := maxi(0, state.cash - reserve)
					var qty := mini(int(avail_cash / price), state.get_free_capacity())
					if qty > 0:
						state.buy_product(pid, qty)

			# 7. Choose next district (visit Florence if debt needs paying, Benson if wounded)
			var next_id := ""
			if need_to_pay_sal and state.current_district_id != "north_omaha":
				next_id = "north_omaha"
			elif state.health < 55 and state.current_district_id != "benson":
				next_id = "benson"
			else:
				var next_idx := (state.day + run_idx) % OmahaCatalog.DISTRICTS.size()
				next_id = String(OmahaCatalog.DISTRICTS[next_idx]["id"])
				if next_id == state.current_district_id:
					next_id = String(OmahaCatalog.DISTRICTS[(next_idx + 1) % OmahaCatalog.DISTRICTS.size()]["id"])
			state.drive_to_district(next_id)

			# Invariant checks
			if state.cash < 0 or state.bank < 0 or state.debt < 0:
				printerr("FAIL [Run %d Day %d]: negative financial state!" % [run_idx, state.day])
				_failures += 1
			if state.get_used_capacity() > state.get_max_capacity():
				printerr("FAIL [Run %d Day %d]: capacity overflow (%d > %d)!" % [run_idx, state.day, state.get_used_capacity(), state.get_max_capacity()])
				_failures += 1

		if state.run_completed and not state.game_over:
			wins += 1
			total_final_nw += state.final_net_worth

	if wins < 20:
		printerr("FAIL: Bot survival rate too low (%d / 40 wins)" % wins)
		_failures += 1

	if _failures == 0:
		print("ALL CHECKS PASSED (%d/40 bot wins, avg winning NW: %s)" % [wins, Money.format(int(total_final_nw / maxi(1, wins)))])
		quit(0)
	else:
		printerr("%d CHECK(S) FAILED" % _failures)
		quit(1)
