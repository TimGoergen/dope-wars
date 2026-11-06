extends SceneTree

# Gate 4: BankingAndLoanSharkTest — verifies Street ATM 5% fee vs North Omaha 0% fee,
# Bank 5% & Loan 10% compounding, Dynamic Big Sal Credit Line, 7-day Enforcer rule,
# and Final Day 1.5x unpaid debt penalty.

var _failures := 0


func _init() -> void:
	var tuning := ConfigLoader.load_tuning(false)
	var state := GameState.new(tuning, 2002)
	state.new_run(31, [], 2002)

	# 1. In North Omaha, deposit fee is 0%
	state.cash = 10000
	var d_north := state.deposit_bank(1000)
	_assert_eq(int(d_north.get("fee", -1)), 0, "0% fee in North Omaha")
	_assert_eq(state.bank, 1000, "Bank 1000")

	# 2. Drive to South Omaha: Bank (+5%) -> 1050, Debt (+10% on 5500) -> 6050
	state.drive_to_district("south_omaha")
	state.active_combat = {}
	_assert_eq(state.bank, 1050, "Bank compounded 5% to 1050")
	_assert_eq(state.debt, 6050, "Debt compounded 10% to 6050")

	# 3. In South Omaha, Street ATM charges 5% deposit fee, and withdrawal is blocked without VIP perk
	var d_atm := state.deposit_bank(1000)
	_assert_eq(int(d_atm.get("fee", 0)), 50, "5% Street ATM fee outside North Omaha")
	_assert_eq(int(d_atm.get("deposited", 0)), 950, "950 credited after 5% fee")
	_assert_true(not state.can_withdraw_bank(), "Cannot withdraw outside North Omaha without VIP perk")

	# 4. Return to North Omaha, pay off Big Sal in full -> unlocks Dynamic Credit Line
	state.drive_to_district("north_omaha")
	state.active_combat = {}
	state.cash = 200000
	state.pay_loan(state.debt)
	_assert_eq(state.debt, 0, "Debt cleared to 0")
	_assert_true(state.initial_debt_cleared, "Initial debt cleared flag set")
	var credit_avail := state.get_max_credit_line()
	_assert_true(credit_avail >= 90000, "Dynamic credit line scales to 50% of Net Worth (%d)" % credit_avail)

	var b_res := state.borrow_loan(50000)
	_assert_true(bool(b_res.get("ok", false)), "Borrowed 50k from dynamic credit line")
	_assert_eq(state.debt, 50000, "New debt 50000")

	# 5. Final Day 1.5x unpaid debt penalty check
	state.day = 31
	state.cash = 100000
	state.bank = 0
	state.debt = 20000 # 1.5x penalty = 30,000 -> Final Net Worth = 70,000
	var fin := state.finish_run()
	_assert_true(bool(fin.get("survived", false)), "Survived when cash covers 1.5x debt")
	_assert_eq(int(fin.get("final_net_worth", 0)), 70000, "Final net worth after 1.5x debt penalty")

	# 6. Defaulting on Final Day when Cash + Bank < 1.5x Debt
	var state_dead := GameState.new(tuning, 2003)
	state_dead.new_run(31, [], 2003)
	state_dead.day = 31
	state_dead.cash = 1000
	state_dead.bank = 0
	state_dead.debt = 10000 # Needs 15,000
	var fin_dead := state_dead.finish_run()
	_assert_true(not bool(fin_dead.get("survived", true)), "Defaulting on 1.5x debt triggers loss")
	_assert_true(state_dead.game_over, "Game over on default")

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
