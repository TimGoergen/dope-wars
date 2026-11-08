class_name GameState
extends RefCounted

# Pure headless game state machine for Dope Wars: Omaha Metro Edition (GDD v1.1).
# Zero SceneTree or UI dependencies — deterministic and directly testable by sim gates.

var tuning: TuningConfig
var rng: RandomNumberGenerator

# Core progression & mode
var day: int = 1
var max_days: int = 31
var is_endless: bool = false
var current_district_id: String = "north_omaha"
var active_perks: Array[String] = []

# Player finances & vitals
var cash: int = 2000
var bank: int = 0
var debt: int = 5500
var initial_debt_cleared: bool = false
var days_since_loan_payment: int = 0
var health: int = 100
var max_health: int = 100
var armor: int = 0
var kidney_sold: bool = false
var heat: float = 0.0

# Capacity, Crew, Arsenal & Vehicle
var carhartt_upgrades: int = 0
var crew_count: int = 0
var vehicle_tier: int = 0
var weapons: Array[String] = [] # Sorted strongest-first, max size = 1 + crew_count

# Inventory: product_id -> { "qty": int, "avg_paid": int }
var inventory: Dictionary = {}

# Current day's local market:
# market_prices: product_id -> int (0 if unlisted today)
# market_signals: product_id -> "normal" | "high" | "low" | "spike" | "flood" | "unlisted"
var market_prices: Dictionary = {}
var market_signals: Dictionary = {}
var active_market_events: Dictionary = {}

# Tomorrow's guaranteed event (from Blackstone VIP Booth, Barfly Tip-off, or Police Scanner perk)
var pending_forecast_event: Dictionary = {}
var next_day_markets: Dictionary = {} # district_id -> cached MarketEngine roll for tomorrow
var vip_intel_bought_today: bool = false
var casino_bet_used_today: bool = false
var casino_launder_used_today: bool = false

# Active modals / encounters
var active_combat: Dictionary = {}     # Empty if no combat; otherwise CombatEngine dictionary
var pending_choice_event: Dictionary = {} # Empty or { "type": "carhartt"|"trunk_gun", "cost": int, ... }

# Scanner log & end-of-run state
var scanner_log: Array[String] = []
var game_over: bool = false
var run_completed: bool = false
var end_fate: String = ""
var final_net_worth: int = 0
var street_cred_earned: int = 0
var cops_killed_total: int = 0


func _init(tuning_cfg: TuningConfig = null, seed_val: int = 0) -> void:
	tuning = tuning_cfg if tuning_cfg != null else ConfigLoader.load_tuning()
	rng = RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.randomize()


func new_run(mode_days: int = 31, perks: Array = [], seed_val: int = 0) -> void:
	if seed_val != 0:
		rng.seed = seed_val
	day = 1
	max_days = mode_days
	is_endless = (mode_days <= 0)
	current_district_id = "north_omaha"
	active_perks.clear()
	for p in perks:
		active_perks.append(String(p))

	cash = tuning.starting_cash
	bank = tuning.starting_bank
	debt = tuning.starting_debt
	initial_debt_cleared = (debt <= 0)
	days_since_loan_payment = 0
	max_health = tuning.starting_health
	health = max_health
	armor = 0
	kidney_sold = false
	heat = 0.0

	carhartt_upgrades = 1 if has_perk("carhartt_xl") else 0
	crew_count = 0
	vehicle_tier = 1 if has_perk("civic_keys") else 0
	weapons.clear()
	if has_perk("glovebox_22"):
		weapons.append("ruger_22")

	inventory.clear()
	for p_def in OmahaCatalog.PRODUCTS:
		inventory[p_def["id"]] = {"qty": 0, "avg_paid": 0}

	pending_forecast_event = {}
	next_day_markets.clear()
	vip_intel_bought_today = false
	casino_bet_used_today = false
	casino_launder_used_today = false
	active_combat = {}
	pending_choice_event = {}
	scanner_log.clear()
	game_over = false
	run_completed = false
	end_fate = ""
	final_net_worth = 0
	street_cred_earned = 0
	cops_killed_total = 0

	log_scanner("📍 Day 1: Parked in North Omaha. Pay Big Sal before Day %d!" % (max_days if not is_endless else 99))
	_roll_market_for_current_district()
	_roll_scanner_perk_forecast_if_needed()


func has_perk(perk_id: String) -> bool:
	return active_perks.has(perk_id)


func log_scanner(msg: String) -> void:
	scanner_log.push_front(msg)
	if scanner_log.size() > 80:
		scanner_log.resize(80)


# --- Telemetry & Capacity Getters ---------------------------------------------------------------

func get_net_worth() -> int:
	return cash + bank - debt


func get_Inventory_value_at_market() -> int:
	var val := 0
	for pid in inventory.keys():
		var qty: int = int(inventory[pid]["qty"])
		var mkt: int = int(market_prices.get(pid, 0))
		if qty > 0 and mkt > 0:
			val += qty * mkt
	return val


func get_max_capacity() -> int:
	var base := tuning.starting_capacity
	var coat_bonus := carhartt_upgrades * tuning.carhartt_pocket_bonus
	var crew_bonus := crew_count * tuning.crew_capacity_bonus
	var v_def := OmahaCatalog.get_vehicle(vehicle_tier)
	var trunk_bonus := int(v_def.get("bonus_capacity", 0))
	return base + coat_bonus + crew_bonus + trunk_bonus


func get_used_capacity() -> int:
	var total := 0
	for pid in inventory.keys():
		total += int(inventory[pid]["qty"])
	return total


func get_free_capacity() -> int:
	return maxi(0, get_max_capacity() - get_used_capacity())


func get_max_weapon_slots() -> int:
	return 1 + crew_count


func get_loan_interest_rate() -> float:
	return tuning.loan_interest_perk_rate if has_perk("connected_cousin") else tuning.loan_interest_rate


func get_bank_interest_rate() -> float:
	return tuning.bank_interest_perk_rate if has_perk("first_national_vip") else tuning.bank_interest_rate


func is_final_day() -> bool:
	return (not is_endless) and (day >= max_days)


# --- Market & Trading Actions -------------------------------------------------------------------

func get_max_buyable(product_id: String) -> int:
	var price := int(market_prices.get(product_id, 0))
	if price <= 0 or cash <= 0:
		return 0
	var by_cash := int(cash / price)
	return mini(by_cash, get_free_capacity())


func buy_product(product_id: String, qty: int) -> Dictionary:
	if game_over or run_completed or is_in_combat():
		return {"ok": false, "reason": "Unavailable"}
	var price := int(market_prices.get(product_id, 0))
	if price <= 0:
		return {"ok": false, "reason": "Not sold here today"}
	var max_qty := get_max_buyable(product_id)
	var actual_qty := clampi(qty, 0, max_qty)
	if actual_qty <= 0:
		return {"ok": false, "reason": "Insufficient cash or space"}

	var total_cost := actual_qty * price
	var entry: Dictionary = inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var old_qty := int(entry["qty"])
	var old_avg := int(entry["avg_paid"])
	var new_qty := old_qty + actual_qty
	var new_avg := int(round(float(old_qty * old_avg + total_cost) / float(new_qty)))

	cash -= total_cost
	inventory[product_id] = {"qty": new_qty, "avg_paid": new_avg}

	if total_cost >= tuning.heat_big_trade_threshold:
		_add_heat(tuning.heat_big_trade_gain)

	var p_name: String = OmahaCatalog.get_product(product_id)["name"]
	log_scanner("🛒 Bought %d %s @ %s (%s)." % [actual_qty, p_name, Money.format(price), Money.format_short(total_cost)])
	return {"ok": true, "qty": actual_qty, "cost": total_cost}


func buy_max(product_id: String) -> Dictionary:
	return buy_product(product_id, get_max_buyable(product_id))


func sell_product(product_id: String, qty: int) -> Dictionary:
	if game_over or run_completed or is_in_combat():
		return {"ok": false, "reason": "Unavailable"}
	var price := int(market_prices.get(product_id, 0))
	if price <= 0:
		return {"ok": false, "reason": "No local buyers today"}
	var entry: Dictionary = inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var avg_paid := int(entry["avg_paid"])
	var actual_qty := clampi(qty, 0, held)
	if actual_qty <= 0:
		return {"ok": false, "reason": "None held"}

	var revenue := actual_qty * price
	var profit := actual_qty * (price - avg_paid)
	var remaining := held - actual_qty
	cash += revenue
	inventory[product_id] = {"qty": remaining, "avg_paid": avg_paid if remaining > 0 else 0}

	if revenue >= tuning.heat_big_trade_threshold:
		_add_heat(tuning.heat_big_trade_gain)

	var p_name: String = OmahaCatalog.get_product(product_id)["name"]
	log_scanner("💵 Sold %d %s @ %s (%s P/L)." % [actual_qty, p_name, Money.format(price), Money.format_pl(profit)])
	return {"ok": true, "qty": actual_qty, "revenue": revenue, "profit": profit}


func sell_all(product_id: String) -> Dictionary:
	var entry: Dictionary = inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	return sell_product(product_id, int(entry["qty"]))


func dump_product(product_id: String, qty: int) -> Dictionary:
	if game_over or run_completed or is_in_combat():
		return {"ok": false, "reason": "Unavailable"}
	var entry: Dictionary = inventory.get(product_id, {"qty": 0, "avg_paid": 0})
	var held := int(entry["qty"])
	var avg_paid := int(entry["avg_paid"])
	var actual_qty := clampi(qty, 0, held)
	if actual_qty <= 0:
		return {"ok": false, "reason": "None held"}
	var remaining := held - actual_qty
	inventory[product_id] = {"qty": remaining, "avg_paid": avg_paid if remaining > 0 else 0}
	var p_name: String = OmahaCatalog.get_product(product_id)["name"]
	log_scanner("🗑️ Dumped %d %s down a storm drain." % [actual_qty, p_name])
	return {"ok": true, "qty": actual_qty}


# --- Banking, Street ATM & Big Sal Loan Shark ---------------------------------------------------

func get_street_atm_fee_rate() -> float:
	if current_district_id == "north_omaha" or has_perk("first_national_vip"):
		return 0.0
	return tuning.street_atm_fee_rate


func deposit_bank(amount: int) -> Dictionary:
	var actual := clampi(amount, 0, cash)
	if actual <= 0:
		return {"ok": false, "reason": "No cash"}
	var fee_rate := get_street_atm_fee_rate()
	var fee := int(round(float(actual) * fee_rate))
	var credited := actual - fee
	cash -= actual
	bank += credited
	if fee > 0:
		log_scanner("🏧 Street ATM: Deposited %s (%s 5%% fee)." % [Money.format_short(credited), Money.format_short(fee)])
	else:
		log_scanner("🏦 First National: Deposited %s (0%% fee)." % Money.format_short(credited))
	return {"ok": true, "deposited": credited, "fee": fee}


func can_withdraw_bank() -> bool:
	return current_district_id == "north_omaha" or has_perk("first_national_vip")


func withdraw_bank(amount: int) -> Dictionary:
	if not can_withdraw_bank():
		return {"ok": false, "reason": "Must visit First National in North Omaha (or unlock VIP Perk)"}
	var actual := clampi(amount, 0, bank)
	if actual <= 0:
		return {"ok": false, "reason": "No bank funds"}
	bank -= actual
	cash += actual
	log_scanner("🏦 Withdrew %s from First National." % Money.format_short(actual))
	return {"ok": true, "withdrawn": actual}


func pay_loan(amount: int) -> Dictionary:
	if current_district_id != "north_omaha":
		return {"ok": false, "reason": "Big Sal is in North Omaha"}
	var actual := clampi(amount, 0, mini(cash, debt))
	if actual <= 0:
		return {"ok": false, "reason": "Nothing to pay"}
	var prior_debt := debt
	cash -= actual
	debt -= actual
	if debt <= 0:
		debt = 0
		initial_debt_cleared = true
		days_since_loan_payment = 0
		log_scanner("🦈 Paid off Big Sal in full! Dynamic Credit Line unlocked.")
	else:
		if float(actual) >= float(prior_debt) * tuning.enforcer_min_payment_pct:
			days_since_loan_payment = 0
		log_scanner("🦈 Paid Big Sal %s (Remaining Debt: %s)." % [Money.format_short(actual), Money.format_short(debt)])
	return {"ok": true, "paid": actual, "remaining_debt": debt}


func get_max_credit_line() -> int:
	if not initial_debt_cleared:
		return 0
	var nw_based := int(floor(float(maxi(0, get_net_worth())) * tuning.credit_line_net_worth_pct))
	var total_limit := clampi(maxi(tuning.credit_line_min, nw_based), tuning.credit_line_min, tuning.credit_line_cap)
	return maxi(0, total_limit - debt)


func borrow_loan(amount: int) -> Dictionary:
	if current_district_id != "north_omaha":
		return {"ok": false, "reason": "Big Sal is in North Omaha"}
	if not initial_debt_cleared:
		return {"ok": false, "reason": "Pay off your initial $5,500 debt first"}
	var avail := get_max_credit_line()
	var actual := clampi(amount, 0, avail)
	if actual <= 0:
		return {"ok": false, "reason": "Credit limit reached"}
	cash += actual
	debt += actual
	log_scanner("🦈 Borrowed %s from Big Sal (Debt: %s)." % [Money.format_short(actual), Money.format_short(debt)])
	return {"ok": true, "borrowed": actual, "debt": debt}


# --- District Facilities (South O, Benson, West O, C.Bluffs, Old Market, Blackstone, Bellevue) --

func buy_weapon(weapon_id: String) -> Dictionary:
	var w_def := OmahaCatalog.get_weapon(weapon_id)
	var price := int(w_def["price"])
	var trade_in := 0
	var replaced_name := ""

	if weapons.size() >= get_max_weapon_slots():
		# Check if new weapon is strictly stronger than our weakest weapon
		var weakest_id: String = weapons.back()
		var weakest_def := OmahaCatalog.get_weapon(weakest_id)
		if int(w_def["damage"]) <= int(weakest_def["damage"]):
			return {"ok": false, "reason": "Weapon slots full with equal/better firepower"}
		trade_in = int(round(float(weakest_def["price"]) * tuning.weapon_trade_in_pct))
		replaced_name = String(weakest_def["short_name"])

	var net_cost := maxi(0, price - trade_in)
	if cash < net_cost:
		return {"ok": false, "reason": "Insufficient cash"}

	cash -= net_cost
	if trade_in > 0:
		weapons.pop_back()
	weapons.append(weapon_id)
	_sort_weapons_strongest_first()

	if trade_in > 0:
		log_scanner("🔫 Bought %s (Traded %s for %s; Net: %s)." % [w_def["short_name"], replaced_name, Money.format_short(trade_in), Money.format_short(net_cost)])
	else:
		log_scanner("🔫 Bought %s for %s." % [w_def["short_name"], Money.format_short(net_cost)])
	return {"ok": true, "net_cost": net_cost, "trade_in": trade_in}


func buy_armor(is_plate_carrier: bool) -> Dictionary:
	var target_armor := tuning.armor_plate_amount if is_plate_carrier else tuning.armor_vest_amount
	var price := tuning.armor_plate_price if is_plate_carrier else tuning.armor_vest_price
	if armor >= target_armor:
		return {"ok": false, "reason": "Armor already at or above this tier"}
	if cash < price:
		return {"ok": false, "reason": "Insufficient cash"}
	cash -= price
	armor = target_armor
	log_scanner("🛡️ Equipped %s (Armor: %d)." % ["Tactical Plate Carrier" if is_plate_carrier else "Street Kevlar Vest", armor])
	return {"ok": true, "armor": armor, "cost": price}


func get_heal_cost_per_hp() -> int:
	var scaled := int(floor(float(maxi(0, get_net_worth())) * tuning.clinic_net_worth_scale))
	return clampi(scaled, tuning.clinic_min_cost_per_hp, tuning.clinic_max_cost_per_hp)


func heal_player(hp_to_heal: int) -> Dictionary:
	var missing := maxi(0, max_health - health)
	if missing <= 0:
		return {"ok": false, "reason": "Already at full health"}
	var cost_per_hp := get_heal_cost_per_hp()
	var affordable_hp := int(cash / cost_per_hp)
	var actual_hp := clampi(hp_to_heal, 0, mini(missing, affordable_hp))
	if actual_hp <= 0:
		return {"ok": false, "reason": "Insufficient cash"}
	var total_cost := actual_hp * cost_per_hp
	cash -= total_cost
	health += actual_hp
	log_scanner("🏥 Benson Clinic: Patched +%d HP for %s." % [actual_hp, Money.format_short(total_cost)])
	return {"ok": true, "healed": actual_hp, "cost": total_cost}


func sell_kidney() -> Dictionary:
	if kidney_sold:
		return {"ok": false, "reason": "You only have one spare kidney!"}
	kidney_sold = true
	max_health = tuning.kidney_max_hp_cap
	health = mini(health, max_health)
	cash += tuning.kidney_sale_payout
	log_scanner("🏥 Sold a kidney in Benson for %s! Max HP is now %d." % [Money.format(tuning.kidney_sale_payout), max_health])
	return {"ok": true, "payout": tuning.kidney_sale_payout, "max_health": max_health}


func get_next_crew_cost() -> int:
	return tuning.crew_base_cost + (crew_count * tuning.crew_step_cost)


func hire_crew() -> Dictionary:
	if crew_count >= tuning.crew_max_count:
		return {"ok": false, "reason": "Crew is at max capacity (10 Runners)"}
	var cost := get_next_crew_cost()
	if cash < cost:
		return {"ok": false, "reason": "Insufficient cash"}
	cash -= cost
	crew_count += 1
	log_scanner("🍸 Hired Runner #%d at The Regency Lounge (+%d Space, +1 Gun Slot, 30 HP Shield)." % [crew_count, tuning.crew_capacity_bonus])
	return {"ok": true, "crew_count": crew_count, "cost": cost}


func casino_high_card_bet(wager: int) -> Dictionary:
	if casino_bet_used_today:
		return {"ok": false, "reason": "High-limit table already played today"}
	var actual := clampi(wager, tuning.casino_min_bet, mini(cash, tuning.casino_max_bet))
	if actual < tuning.casino_min_bet or cash < actual:
		return {"ok": false, "reason": "Minimum bet is %s" % Money.format(tuning.casino_min_bet)}
	casino_bet_used_today = true
	var won := (rng.randf() < 0.50)
	if won:
		cash += actual
		log_scanner("🎰 Riverboat High-Card: WON +%s!" % Money.format_short(actual))
	else:
		cash -= actual
		log_scanner("🎰 Riverboat High-Card: Lost %s to the house." % Money.format_short(actual))
	return {"ok": true, "won": won, "delta": actual if won else -actual}


func casino_launder_chips(amount: int) -> Dictionary:
	if casino_launder_used_today:
		return {"ok": false, "reason": "Cage chip wash already used today"}
	var actual := clampi(amount, 2000, cash)
	if actual < 2000 or cash < 2000:
		return {"ok": false, "reason": "Minimum chip wash is $2,000"}
	casino_launder_used_today = true
	var house_cut := int(round(float(actual) * tuning.casino_launder_cut_pct))
	var wired_to_bank := actual - house_cut
	cash -= actual
	bank += wired_to_bank
	_reduce_heat(tuning.casino_launder_heat_drop)
	log_scanner("🎰 Washed %s at Cage -> %s wired to Bank (-%.0f%% Heat)!" % [Money.format_short(actual), Money.format_short(wired_to_bank), tuning.casino_launder_heat_drop])
	return {"ok": true, "wired": wired_to_bank, "cut": house_cut, "heat": heat}


func get_lawyer_cost(clear_all: bool) -> int:
	var nw_factor := int(floor(float(maxi(0, get_net_worth())) * 0.015))
	var base := tuning.lawyer_base_cost + int(heat * 60.0) + nw_factor
	return base * 2 if clear_all else base


func hire_lawyer(clear_all: bool) -> Dictionary:
	if heat <= 0.1:
		return {"ok": false, "reason": "Heat is already 0%"}
	var cost := get_lawyer_cost(clear_all)
	if cash < cost:
		return {"ok": false, "reason": "Insufficient cash"}
	cash -= cost
	if clear_all:
		heat = 0.0
		log_scanner("⚖️ Farnam St. Attorney cleared all warrants! Heat is now 0%%.")
	else:
		_reduce_heat(tuning.lawyer_partial_heat_drop)
		log_scanner("⚖️ Farnam St. Attorney quashed patrol sightings (Heat: %.0f%%)." % heat)
	return {"ok": true, "cost": cost, "heat": heat}


func get_vip_intel_cost() -> int:
	return tuning.vip_intel_base_cost + (day * tuning.vip_intel_day_step_cost)


func buy_vip_intel(mode: String) -> Dictionary:
	if vip_intel_bought_today:
		return {"ok": false, "reason": "Already bought VIP intel today"}
	var cost := get_vip_intel_cost()
	if cash < cost:
		return {"ok": false, "reason": "Insufficient cash"}

	var avail_today: Array = []
	for p_def in OmahaCatalog.PRODUCTS:
		var pid: String = p_def["id"]
		if int(market_prices.get(pid, 0)) > 0:
			avail_today.append(pid)

	cash -= cost
	vip_intel_bought_today = true
	pending_forecast_event = MarketEngine.roll_forecast_event(avail_today, mode, tuning, rng)
	next_day_markets.clear()
	var p_name := String(pending_forecast_event.get("product_name", ""))
	var ev_type := String(pending_forecast_event.get("event_type", "spike"))
	if ev_type == "spike":
		log_scanner("🥂 VIP Intel: %s is guaranteed to SPIKE (4x) tomorrow! Stock up now!" % p_name)
	else:
		log_scanner("🥂 VIP Intel: %s will FLOOD (1/4 price) tomorrow! Clear space!" % p_name)
	return {"ok": true, "cost": cost, "forecast": pending_forecast_event}


func buy_vehicle(target_tier: int) -> Dictionary:
	if target_tier <= vehicle_tier or target_tier >= OmahaCatalog.VEHICLES.size():
		return {"ok": false, "reason": "Already own equal or better vehicle"}
	var v_def := OmahaCatalog.get_vehicle(target_tier)
	var price := int(v_def["price"])
	if cash < price:
		return {"ok": false, "reason": "Insufficient cash"}
	cash -= price
	vehicle_tier = target_tier
	log_scanner("🚗 Purchased %s (+%d Trunk Space, +%.0f%% Escape)!" % [
		v_def["name"],
		int(v_def["bonus_capacity"]),
		float(v_def["escape_bonus"]) * 100.0
	])
	return {"ok": true, "vehicle_tier": vehicle_tier, "cost": price}


# --- Travel & Daily Turn Progression ------------------------------------------------------------

func drive_to_district(target_district_id: String) -> Dictionary:
	if game_over or run_completed or is_in_combat():
		return {"ok": false, "reason": "Cannot travel right now"}
	if target_district_id == current_district_id:
		return {"ok": false, "reason": "Already parked in this neighborhood"}
	if is_final_day():
		return {"ok": false, "reason": "Final Day reached — tap Finish Run when done trading"}

	current_district_id = target_district_id
	day += 1
	vip_intel_bought_today = false
	casino_bet_used_today = false
	casino_launder_used_today = false
	pending_choice_event = {}

	# 1. Compound daily Bank & Debt interest
	if bank > 0:
		bank = int(floor(float(bank) * (1.0 + get_bank_interest_rate())))
	if debt > 0:
		debt = int(floor(float(debt) * (1.0 + get_loan_interest_rate())))
		days_since_loan_payment += 1

	# 2. Passive Heat decay (Bellevue sheds -18%/day; other districts -3%/day)
	var d_def := OmahaCatalog.get_district(current_district_id)
	if bool(d_def.get("bellevue_chill", false)):
		_reduce_heat(tuning.heat_bellevue_decay)
	else:
		_reduce_heat(tuning.heat_passive_decay)

	log_scanner("🚗 Day %d: Pulled into %s." % [day, d_def["name"]])

	# 3. Check Big Sal's 7-day unpaid loan enforcers
	if debt > 0 and days_since_loan_payment >= tuning.enforcer_unpaid_days:
		_trigger_big_sal_enforcers()
		if game_over:
			return {"ok": true, "game_over": true}

	# 4. Roll today's market (consuming any pending forecast tip-off)
	var forecast_to_apply := pending_forecast_event.duplicate()
	pending_forecast_event = {}
	_roll_market_for_current_district(forecast_to_apply)

	# 5. Roll non-market street encounters
	_roll_street_encounter()

	# 6. Roll Police Ambush (unless on Day 1)
	var ambushed := false
	var ambush_chance := CombatEngine.get_ambush_chance_pct(
		current_district_id,
		heat,
		has_perk("police_scanner"),
		tuning
	)
	if rng.randf() * 100.0 < ambush_chance:
		active_combat = CombatEngine.create_encounter(heat, crew_count, tuning, rng)
		log_scanner(String(active_combat["last_log"]))
		ambushed = true

	# 7. Roll tomorrow's Police Scanner perk forecast if unlocked and no VIP tip set
	_roll_scanner_perk_forecast_if_needed()

	return {"ok": true, "day": day, "ambushed": ambushed}


func _trigger_big_sal_enforcers() -> void:
	days_since_loan_payment = 0
	var dmg := tuning.enforcer_damage
	var seized := int(round(float(cash) * tuning.enforcer_cash_seize_pct))
	if seized > 0:
		cash -= seized
		debt = maxi(0, debt - seized)
	health -= dmg
	log_scanner("🦈 Big Sal's thugs ambushed you on 30th St! (-%d HP, seized %s toward debt)." % [dmg, Money.format_short(seized)])
	if health <= 0:
		health = 0
		game_over = true
		end_fate = "Beaten to death by Big Sal's enforcers on Day %d" % day


func get_next_day_market_preview(district_id: String) -> Dictionary:
	if district_id == current_district_id:
		return {
			"prices": market_prices,
			"signals": market_signals,
			"events": active_market_events,
			"messages": []
		}
	if not next_day_markets.has(district_id):
		var next_is_final := (not is_endless) and ((day + 1) >= max_days)
		next_day_markets[district_id] = MarketEngine.roll_daily_market(
			district_id,
			next_is_final,
			pending_forecast_event,
			tuning,
			rng
		)
	return next_day_markets[district_id]


func _roll_market_for_current_district(forced_event: Dictionary = {}) -> void:
	var result: Dictionary
	if next_day_markets.has(current_district_id):
		result = next_day_markets[current_district_id]
		next_day_markets.clear()
	else:
		next_day_markets.clear()
		result = MarketEngine.roll_daily_market(
			current_district_id,
			is_final_day(),
			forced_event,
			tuning,
			rng
		)
	market_prices = result["prices"]
	market_signals = result["signals"]
	active_market_events = result["events"]
	var msgs: Array = result["messages"]
	for m in msgs:
		log_scanner(String(m))


func _roll_scanner_perk_forecast_if_needed() -> void:
	if has_perk("police_scanner") and pending_forecast_event.is_empty() and not is_final_day():
		if rng.randf() < 0.65:
			pending_forecast_event = MarketEngine.roll_forecast_event([], "random", tuning, rng)
			next_day_markets.clear()
			var p_name := String(pending_forecast_event.get("product_name", ""))
			var et := String(pending_forecast_event.get("event_type", "spike"))
			log_scanner("📡 Scanner 24h Forecast: %s %s brewing for tomorrow." % [
				p_name,
				"4x SPIKE" if et == "spike" else "1/4 FLOOD"
			])


func _roll_street_encounter() -> void:
	if rng.randf() > tuning.street_event_chance:
		return
	var roll := rng.randi_range(1, 9)
	match roll:
		1:
			# Found Stash
			if get_free_capacity() > 0:
				var idx := rng.randi_range(0, 7) # Low-to-mid tier drug
				var p_def: Dictionary = OmahaCatalog.PRODUCTS[idx]
				var pid: String = p_def["id"]
				var qty := mini(rng.randi_range(2, 8), get_free_capacity())
				if qty > 0:
					var entry: Dictionary = inventory[pid]
					var old_qty := int(entry["qty"])
					var old_avg := int(entry["avg_paid"])
					var new_qty := old_qty + qty
					var new_avg := int(round(float(old_qty * old_avg) / float(new_qty)))
					inventory[pid] = {"qty": new_qty, "avg_paid": new_avg}
					log_scanner("🎒 Found %d %s in an abandoned backpack near Gene Leahy Mall!" % [qty, p_def["name"]])
		2:
			# Kum & Go Buddy Hookup
			if get_free_capacity() > 0:
				var idx := rng.randi_range(0, 3)
				var p_def: Dictionary = OmahaCatalog.PRODUCTS[idx]
				var pid: String = p_def["id"]
				var qty := mini(rng.randi_range(3, 6), get_free_capacity())
				if qty > 0:
					var entry: Dictionary = inventory[pid]
					var old_qty := int(entry["qty"])
					var old_avg := int(entry["avg_paid"])
					var new_qty := old_qty + qty
					var new_avg := int(round(float(old_qty * old_avg) / float(new_qty)))
					inventory[pid] = {"qty": new_qty, "avg_paid": new_avg}
					log_scanner("🤝 An old buddy outside Kum & Go tossed you %d free %s!" % [qty, p_def["name"]])
		3:
			# Casino Lot Mugging
			if cash >= 200:
				var lost := maxi(50, int(round(float(cash) * rng.randf_range(0.10, 0.20))))
				cash -= lost
				log_scanner("🔪 Mugged in a dark lot! Lost %s pocket cash (Bank untouched)." % Money.format_short(lost))
		4:
			# OPD K-9 Chase
			var held_pids := _get_held_product_ids()
			if not held_pids.is_empty():
				var pid: String = held_pids[rng.randi_range(0, held_pids.size() - 1)]
				var entry: Dictionary = inventory[pid]
				var lost := maxi(1, int(round(float(int(entry["qty"])) * 0.15)))
				entry["qty"] = maxi(0, int(entry["qty"]) - lost)
				if int(entry["qty"]) == 0:
					entry["avg_paid"] = 0
				inventory[pid] = entry
				var p_name: String = OmahaCatalog.get_product(pid)["name"]
				log_scanner("🐕 OPD K-9 unit chased you across Saddle Creek! Dropped %d %s!" % [lost, p_name])
		5:
			# Dodge St. Pothole
			var held_pids := _get_held_product_ids()
			if not held_pids.is_empty():
				var pid: String = held_pids[rng.randi_range(0, held_pids.size() - 1)]
				var entry: Dictionary = inventory[pid]
				var lost := mini(int(entry["qty"]), rng.randi_range(1, 4))
				entry["qty"] = maxi(0, int(entry["qty"]) - lost)
				if int(entry["qty"]) == 0:
					entry["avg_paid"] = 0
				inventory[pid] = entry
				var p_name: String = OmahaCatalog.get_product(pid)["name"]
				log_scanner("🕳️ Hit a crater-sized pothole on Dodge St and ruined %d %s!" % [lost, p_name])
		6:
			# Carhartt Jacket Vendor (Choice Prompt)
			var cost := tuning.carhartt_base_cost * int(pow(3, carhartt_upgrades))
			if cash >= cost and carhartt_upgrades < 6:
				pending_choice_event = {
					"type": "carhartt",
					"title": "Mega Saver Parking Lot Deal",
					"prompt": "A guy outside Mega Saver offers you a bigger Carhartt jacket (+%d Pockets) for %s." % [tuning.carhartt_pocket_bonus, Money.format(cost)],
					"cost": cost,
					"bonus": tuning.carhartt_pocket_bonus
				}
		7:
			# Camaro Trunk Gun Dealer (Choice Prompt)
			if weapons.size() < get_max_weapon_slots():
				var w_def: Dictionary = OmahaCatalog.WEAPONS[rng.randi_range(1, 2)]
				var discount_cost := int(round(float(w_def["price"]) * 0.70))
				if cash >= discount_cost:
					pending_choice_event = {
						"type": "trunk_gun",
						"title": "IROC-Z Trunk Special",
						"prompt": "A sketchy guy in a Camaro offers to sell you a %s out of his trunk for %s (30%% off)." % [w_def["name"], Money.format(discount_cost)],
						"cost": discount_cost,
						"weapon_id": w_def["id"]
					}
		8:
			# Benson Barfly Tip-Off
			if pending_forecast_event.is_empty() and not is_final_day():
				pending_forecast_event = MarketEngine.roll_forecast_event([], "random", tuning, rng)
				next_day_markets.clear()
				var p_name := String(pending_forecast_event.get("product_name", ""))
				var et := String(pending_forecast_event.get("event_type", "spike"))
				log_scanner("🍺 Dive Bar Tip-Off: '%s is about to %s tomorrow!'" % [
					p_name,
					"SPIKE 4x" if et == "spike" else "FLOOD 1/4"
				])
		9:
			# Local Omaha Flavor
			var flavors := [
				"📻 Traffic is backed up on I-480 near the Missouri River bridge.",
				"📻 The smell of fresh Runza drifts across the parking lot.",
				"📻 Union Pacific freight horn echoes across the valley."
			]
			log_scanner(flavors[rng.randi_range(0, flavors.size() - 1)])


func accept_choice_event() -> Dictionary:
	if pending_choice_event.is_empty():
		return {"ok": false}
	var ev := pending_choice_event.duplicate()
	pending_choice_event = {}
	var cost := int(ev.get("cost", 0))
	if cash < cost:
		return {"ok": false, "reason": "Insufficient cash"}

	if ev["type"] == "carhartt":
		cash -= cost
		carhartt_upgrades += 1
		log_scanner("🧥 Bought upgraded Carhartt jacket (+%d Pockets) for %s!" % [tuning.carhartt_pocket_bonus, Money.format(cost)])
		return {"ok": true, "type": "carhartt"}
	elif ev["type"] == "trunk_gun":
		var wid := String(ev["weapon_id"])
		cash -= cost
		weapons.append(wid)
		_sort_weapons_strongest_first()
		var w_def := OmahaCatalog.get_weapon(wid)
		log_scanner("🔫 Bought trunk %s for %s!" % [w_def["short_name"], Money.format(cost)])
		return {"ok": true, "type": "trunk_gun"}
	return {"ok": false}


func decline_choice_event() -> void:
	pending_choice_event = {}


# --- Combat Resolution (Fight / Run / Surrender) ------------------------------------------------

func is_in_combat() -> bool:
	return bool(active_combat.get("active", false))


func combat_fight() -> Dictionary:
	if not is_in_combat():
		return {"ok": false, "reason": "No active combat"}
	if weapons.is_empty():
		return {"ok": false, "reason": "Unarmed — you must Run or Surrender!"}

	var cops: Array = active_combat["cop_hp_list"]
	var player_dmg_dealt := 0
	var cops_downed_this_round := 0

	# 1. Player & armed Crew fire at the front officer in `cops`
	var shooters := mini(weapons.size(), 1 + crew_count)
	for i in range(shooters):
		if cops.is_empty():
			break
		var w_def := OmahaCatalog.get_weapon(weapons[i])
		if rng.randf() <= float(w_def["hit_chance"]):
			var dmg := int(w_def["damage"])
			player_dmg_dealt += dmg
			cops[0] = int(cops[0]) - dmg
			if int(cops[0]) <= 0:
				cops.pop_front()
				cops_downed_this_round += 1
				cops_killed_total += 1
				_add_heat(tuning.heat_per_cop_kill)

	# Check if all officers are defeated
	if cops.is_empty():
		var bounty := rng.randi_range(int(active_combat["min_bounty"]), int(active_combat["max_bounty"]))
		cash += bounty
		var leader_name := String(active_combat["leader_name"])
		active_combat = {}
		log_scanner("💥 Gunned down %s's unit! Looted %s!" % [leader_name, Money.format_short(bounty)])
		return {"ok": true, "victory": true, "bounty": bounty}

	# 2. Surviving officers return fire (Shared 50/50 Target Pool with Crew)
	var cop_dmg_Result := _resolve_cop_return_fire(cops.size())
	if not game_over and not active_combat.is_empty():
		active_combat["round"] = int(active_combat.get("round", 1)) + 1
		active_combat["last_action"] = "fight"
		active_combat["last_player_dmg"] = player_dmg_dealt
		active_combat["last_cops_downed"] = cops_downed_this_round
		active_combat["last_cop_fire"] = cop_dmg_Result
		var player_part := "💥 You dealt %d DMG!" % player_dmg_dealt if player_dmg_dealt > 0 else "❌ Your shots missed!"
		if cops_downed_this_round > 0:
			player_part += " (☠️ Officer Down!)"
		active_combat["last_log"] = "%s Cop Return Fire: %s" % [player_part, cop_dmg_Result.get("summary", "No damage")]
	return {
		"ok": true,
		"victory": false,
		"player_dmg_dealt": player_dmg_dealt,
		"cops_downed": cops_downed_this_round,
		"cop_fire": cop_dmg_Result,
		"game_over": game_over
	}


func combat_run() -> Dictionary:
	if not is_in_combat():
		return {"ok": false, "reason": "No active combat"}
	_add_heat(tuning.heat_per_run_attempt)
	var escape_chance := CombatEngine.get_escape_chance(active_combat, vehicle_tier, tuning)
	if rng.randf() <= escape_chance:
		var leader_name := String(active_combat["leader_name"])
		active_combat = {}
		log_scanner("💨 Cut through an alley off Leavenworth and lost %s!" % leader_name)
		return {"ok": true, "escaped": true}

	# Failed escape: cops get a free volley of shots
	var cops: Array = active_combat["cop_hp_list"]
	var cop_fire := _resolve_cop_return_fire(cops.size())
	if not game_over and not active_combat.is_empty():
		active_combat["round"] = int(active_combat.get("round", 1)) + 1
		active_combat["last_action"] = "run"
		active_combat["last_cop_fire"] = cop_fire
		active_combat["last_log"] = "🚫 Escape Failed (Blocked in Traffic)! Cop Return Fire: %s" % cop_fire.get("summary", "No damage")
	return {"ok": true, "escaped": false, "cop_fire": cop_fire, "game_over": game_over}


func combat_surrender() -> Dictionary:
	if not is_in_combat():
		return {"ok": false, "reason": "No active combat"}
	# Confiscate 100% of carried drugs and 25% of pocket cash; reset Heat to 10%
	for pid in inventory.keys():
		inventory[pid] = {"qty": 0, "avg_paid": 0}
	var cash_lost := int(round(float(cash) * tuning.surrender_cash_loss_pct))
	cash -= cash_lost
	heat = tuning.surrender_heat_reset
	active_combat = {}
	log_scanner("🚓 Surrendered! Cops seized your stash & %s cash (Heat reset to %.0f%%)." % [Money.format_short(cash_lost), heat])
	return {"ok": true, "surrendered": true, "cash_lost": cash_lost}


func _resolve_cop_return_fire(num_cops: int) -> Dictionary:
	var v_def := OmahaCatalog.get_vehicle(vehicle_tier)
	var dmg_mult := 1.0 - float(v_def.get("cop_dmg_reduction", 0.0))
	var min_d := int(active_combat["min_dmg"])
	var max_d := int(active_combat["max_dmg"])

	var dmg_to_player := 0
	var dmg_to_armor := 0
	var dmg_to_health := 0
	var dmg_to_crew := 0
	var crew_killed := 0

	for _i in range(num_cops):
		if rng.randf() <= 0.60: # 60% cop accuracy
			var raw_dmg := maxi(1, int(round(float(rng.randi_range(min_d, max_d)) * dmg_mult)))
			if crew_count > 0 and rng.randf() < tuning.crew_target_chance:
				# Hits front Crew member (30 HP per encounter)
				dmg_to_crew += raw_dmg
				var front_hp := int(active_combat.get("front_crew_hp", tuning.crew_encounter_hp)) - raw_dmg
				if front_hp <= 0:
					crew_killed += 1
					_handle_crew_member_death()
					active_combat["front_crew_hp"] = tuning.crew_encounter_hp if crew_count > 0 else 0
				else:
					active_combat["front_crew_hp"] = front_hp
			else:
				# Hits player: Armor absorbs first, then Health
				var absorbed := mini(armor, raw_dmg)
				armor -= absorbed
				var hp_loss := raw_dmg - absorbed
				health -= hp_loss
				dmg_to_player += raw_dmg
				dmg_to_armor += absorbed
				dmg_to_health += hp_loss

	if health <= 0:
		health = 0
		game_over = true
		end_fate = "Gunned down by %s in %s on Day %d" % [
			active_combat["leader_name"],
			OmahaCatalog.get_district(current_district_id)["name"],
			day
		]
		active_combat = {}

	var summary := "-%d HP/Armor" % dmg_to_player
	if crew_killed > 0:
		summary += ", %d Runner killed!" % crew_killed
	elif dmg_to_crew > 0:
		summary += ", Runner took %d dmg" % dmg_to_crew
	return {
		"dmg_to_player": dmg_to_player,
		"dmg_to_armor": dmg_to_armor,
		"dmg_to_health": dmg_to_health,
		"dmg_to_crew": dmg_to_crew,
		"crew_killed": crew_killed,
		"summary": summary
	}


func _handle_crew_member_death() -> void:
	if crew_count <= 0:
		return
	crew_count -= 1
	# If weapon slots now exceed max slots (1 + crew_count), drop the weakest gun
	while weapons.size() > get_max_weapon_slots():
		var lost_w: String = weapons.pop_back()
		var w_name: String = OmahaCatalog.get_weapon(lost_w)["short_name"]
		log_scanner("⚠️ Fallen Runner dropped their %s!" % w_name)

	# If carried drugs exceed new MaxCapacity, spill lowest-value carried products first
	var overflow := get_used_capacity() - get_max_capacity()
	if overflow > 0:
		var spilled_total := 0
		# OmahaCatalog.PRODUCTS is ordered from cheapest (Row 1 Adderall) to priciest (Row 12 Cocaine)
		for p_def in OmahaCatalog.PRODUCTS:
			if overflow <= 0:
				break
			var pid: String = p_def["id"]
			var entry: Dictionary = inventory[pid]
			var held := int(entry["qty"])
			if held > 0:
				var drop := mini(held, overflow)
				entry["qty"] = held - drop
				if int(entry["qty"]) == 0:
					entry["avg_paid"] = 0
				inventory[pid] = entry
				overflow -= drop
				spilled_total += drop
		if spilled_total > 0:
			log_scanner("⚠️ Lost Runner capacity! %d units of low-tier product spilled onto the pavement!" % spilled_total)


# --- Final Day Settlement & Legacy Cred Calculation ---------------------------------------------

func finish_run() -> Dictionary:
	if game_over or run_completed:
		return {"ok": false, "reason": "Run already ended"}

	var penalty := 0
	if debt > 0:
		penalty = int(round(float(debt) * tuning.final_day_debt_penalty_mult))
		var total_liquid := cash + bank
		if total_liquid < penalty:
			game_over = true
			final_net_worth = total_liquid - penalty
			end_fate = "Defaulted on Big Sal's %s collection on 30th St." % Money.format_short(penalty)
			log_scanner("💀 GAME OVER: %s" % end_fate)
			return {
				"ok": true,
				"survived": false,
				"final_net_worth": final_net_worth,
				"fate": end_fate,
				"street_cred_earned": 0
			}
		# Deduct 1.5x debt penalty from cash first, then bank
		var from_cash := mini(cash, penalty)
		cash -= from_cash
		var rem_penalty := penalty - from_cash
		bank = maxi(0, bank - rem_penalty)
		debt = 0

	run_completed = true
	final_net_worth = cash + bank
	street_cred_earned = calculate_street_cred_for_net_worth(final_net_worth)
	end_fate = _compute_victory_fate(final_net_worth)
	log_scanner("🏆 RUN COMPLETE! Final Net Worth: %s (+%d Street Cred)." % [Money.format(final_net_worth), street_cred_earned])
	return {
		"ok": true,
		"survived": true,
		"penalty_paid": penalty,
		"final_net_worth": final_net_worth,
		"fate": end_fate,
		"street_cred_earned": street_cred_earned
	}


static func calculate_street_cred_for_net_worth(net_worth: int) -> int:
	if net_worth >= 50000000:
		return 7
	if net_worth >= 10000000:
		return 4
	if net_worth >= 1000000:
		return 2
	if net_worth >= 100000:
		return 1
	return 0


func _compute_victory_fate(nw: int) -> String:
	if nw >= 50000000:
		return "Bought out Regency & Crowned Kingpin of Omaha"
	if nw >= 10000000:
		return "Penthouse Suite in the Old Market"
	if nw >= 1000000:
		return "Retired a West Omaha Millionaire"
	if nw >= 100000:
		return "Paid Off Big Sal & Stacked Solid Paper"
	return "Survived the Streets of Omaha"


# --- Internal Helpers & Serialization -----------------------------------------------------------

func _add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 100.0)


func _reduce_heat(amount: float) -> void:
	heat = clampf(heat - amount, 0.0, 100.0)


func _sort_weapons_strongest_first() -> void:
	weapons.sort_custom(func(a: String, b: String) -> bool:
		var da := int(OmahaCatalog.get_weapon(a)["damage"])
		var db := int(OmahaCatalog.get_weapon(b)["damage"])
		return da > db
	)


func _get_held_product_ids() -> Array[String]:
	var out: Array[String] = []
	for pid in inventory.keys():
		if int(inventory[pid]["qty"]) > 0:
			out.append(String(pid))
	return out


func to_dict() -> Dictionary:
	return {
		"day": day,
		"max_days": max_days,
		"is_endless": is_endless,
		"current_district_id": current_district_id,
		"active_perks": active_perks.duplicate(),
		"cash": cash,
		"bank": bank,
		"debt": debt,
		"initial_debt_cleared": initial_debt_cleared,
		"days_since_loan_payment": days_since_loan_payment,
		"health": health,
		"max_health": max_health,
		"armor": armor,
		"kidney_sold": kidney_sold,
		"heat": heat,
		"carhartt_upgrades": carhartt_upgrades,
		"crew_count": crew_count,
		"vehicle_tier": vehicle_tier,
		"weapons": weapons.duplicate(),
		"inventory": inventory.duplicate(true),
		"market_prices": market_prices.duplicate(),
		"market_signals": market_signals.duplicate(),
		"active_market_events": active_market_events.duplicate(),
		"pending_forecast_event": pending_forecast_event.duplicate(),
		"next_day_markets": next_day_markets.duplicate(true),
		"vip_intel_bought_today": vip_intel_bought_today,
		"casino_bet_used_today": casino_bet_used_today,
		"casino_launder_used_today": casino_launder_used_today,
		"active_combat": active_combat.duplicate(true),
		"pending_choice_event": pending_choice_event.duplicate(true),
		"scanner_log": scanner_log.duplicate(),
		"game_over": game_over,
		"run_completed": run_completed,
		"end_fate": end_fate,
		"final_net_worth": final_net_worth,
		"street_cred_earned": street_cred_earned,
		"cops_killed_total": cops_killed_total
	}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	max_days = int(data.get("max_days", 31))
	is_endless = bool(data.get("is_endless", false))
	current_district_id = String(data.get("current_district_id", "north_omaha"))

	active_perks.clear()
	for p in data.get("active_perks", []):
		active_perks.append(String(p))

	cash = int(data.get("cash", 2000))
	bank = int(data.get("bank", 0))
	debt = int(data.get("debt", 5500))
	initial_debt_cleared = bool(data.get("initial_debt_cleared", debt <= 0))
	days_since_loan_payment = int(data.get("days_since_loan_payment", 0))
	health = int(data.get("health", 100))
	max_health = int(data.get("max_health", 100))
	armor = int(data.get("armor", 0))
	kidney_sold = bool(data.get("kidney_sold", false))
	heat = float(data.get("heat", 0.0))

	carhartt_upgrades = int(data.get("carhartt_upgrades", 0))
	crew_count = int(data.get("crew_count", 0))
	vehicle_tier = int(data.get("vehicle_tier", 0))

	weapons.clear()
	for w in data.get("weapons", []):
		weapons.append(String(w))
	_sort_weapons_strongest_first()

	inventory.clear()
	var saved_inv: Dictionary = data.get("inventory", {})
	for p_def in OmahaCatalog.PRODUCTS:
		var pid: String = p_def["id"]
		if saved_inv.has(pid):
			inventory[pid] = {
				"qty": int(saved_inv[pid].get("qty", 0)),
				"avg_paid": int(saved_inv[pid].get("avg_paid", 0))
			}
		else:
			inventory[pid] = {"qty": 0, "avg_paid": 0}

	market_prices = {}
	var sp: Dictionary = data.get("market_prices", {})
	for k in sp.keys():
		market_prices[String(k)] = int(sp[k])

	market_signals = {}
	var ss: Dictionary = data.get("market_signals", {})
	for k in ss.keys():
		market_signals[String(k)] = String(ss[k])

	active_market_events = data.get("active_market_events", {}).duplicate()
	pending_forecast_event = data.get("pending_forecast_event", {}).duplicate()
	next_day_markets = data.get("next_day_markets", {}).duplicate(true)
	vip_intel_bought_today = bool(data.get("vip_intel_bought_today", false))
	casino_bet_used_today = bool(data.get("casino_bet_used_today", false))
	casino_launder_used_today = bool(data.get("casino_launder_used_today", false))
	active_combat = data.get("active_combat", {}).duplicate(true)
	pending_choice_event = data.get("pending_choice_event", {}).duplicate(true)

	scanner_log.clear()
	for line in data.get("scanner_log", []):
		scanner_log.append(String(line))

	game_over = bool(data.get("game_over", false))
	run_completed = bool(data.get("run_completed", false))
	end_fate = String(data.get("end_fate", ""))
	final_net_worth = int(data.get("final_net_worth", 0))
	street_cred_earned = int(data.get("street_cred_earned", 0))
	cops_killed_total = int(data.get("cops_killed_total", 0))
