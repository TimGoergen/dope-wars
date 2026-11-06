class_name MarketEngine

# Pure headless market pricing, district affinity, and 4x/1/4 event engine (GDD v1.1 §4).


static func roll_daily_market(
	district_id: String,
	is_final_day: bool,
	guaranteed_event: Dictionary,
	tuning: TuningConfig,
	rng: RandomNumberGenerator
) -> Dictionary:
	var district := OmahaCatalog.get_district(district_id)
	var prices: Dictionary = {}
	var signals: Dictionary = {}
	var event_messages: Array[String] = []

	# 1. Determine which 4x Spike / 1/4 Flood events fire today.
	var active_events: Dictionary = {} # product_id -> "spike" | "flood"
	var forced_product: String = String(guaranteed_event.get("product_id", ""))
	var forced_type: String = String(guaranteed_event.get("event_type", ""))
	if forced_product != "" and (forced_type == "spike" or forced_type == "flood"):
		active_events[forced_product] = forced_type
		var p_def := OmahaCatalog.get_product(forced_product)
		event_messages.append(_event_message_for(p_def, forced_type))

	var max_slots := tuning.max_events_per_day
	for _slot in range(max_slots):
		if active_events.size() >= max_slots:
			break
		if rng.randf() <= tuning.event_slot_chance:
			var pick_idx := rng.randi_range(0, OmahaCatalog.PRODUCTS.size() - 1)
			var p_def: Dictionary = OmahaCatalog.PRODUCTS[pick_idx]
			var pid: String = p_def["id"]
			if active_events.has(pid):
				continue
			var primary: String = p_def["primary_event"]
			var secondary: String = "flood" if primary == "spike" else "spike"
			var ev_type: String = primary if rng.randf() <= tuning.primary_event_weight else secondary
			active_events[pid] = ev_type
			event_messages.append(_event_message_for(p_def, ev_type))

	# 2. Roll availability and price for all 12 products.
	var available_count := 0
	for p_def in OmahaCatalog.PRODUCTS:
		var pid: String = p_def["id"]
		var is_avail := is_final_day or active_events.has(pid) or (rng.randf() <= tuning.market_availability_chance)
		if not is_avail:
			prices[pid] = 0
			signals[pid] = "unlisted"
			continue

		available_count += 1
		var min_p := int(tuning.get(p_def["min_prop"]))
		var max_p := int(tuning.get(p_def["max_prop"]))
		var base_price := float(rng.randi_range(min_p, max_p))
		var affinity_mult := get_district_affinity_multiplier(district, pid, tuning)
		var signal_tag := "normal"
		if affinity_mult > 1.01:
			signal_tag = "high"
		elif affinity_mult < 0.99:
			signal_tag = "low"

		var ev_mult := 1.0
		if active_events.has(pid):
			var et: String = active_events[pid]
			if et == "spike":
				ev_mult = tuning.spike_multiplier
				signal_tag = "spike"
			else:
				ev_mult = 1.0 / maxf(tuning.flood_divisor, 1.0)
				signal_tag = "flood"

		var final_price := maxi(1, int(round(base_price * affinity_mult * ev_mult)))
		prices[pid] = final_price
		signals[pid] = signal_tag

	# Safety guarantee: at least 6 products are always listed on any normal day.
	if available_count < 6:
		for p_def in OmahaCatalog.PRODUCTS:
			var pid: String = p_def["id"]
			if prices[pid] == 0:
				var min_p := int(tuning.get(p_def["min_prop"]))
				var max_p := int(tuning.get(p_def["max_prop"]))
				var affinity_mult := get_district_affinity_multiplier(district, pid, tuning)
				prices[pid] = maxi(1, int(round(float(rng.randi_range(min_p, max_p)) * affinity_mult)))
				signals[pid] = "high" if affinity_mult > 1.01 else ("low" if affinity_mult < 0.99 else "normal")
				available_count += 1
				if available_count >= 6:
					break

	return {
		"prices": prices,
		"signals": signals,
		"events": active_events,
		"messages": event_messages
	}


static func get_district_affinity_multiplier(district: Dictionary, product_id: String, tuning: TuningConfig) -> float:
	var very_cheap: Array = district.get("very_cheap_products", [])
	if very_cheap.has(product_id):
		return tuning.affinity_very_cheap_mult
	var mild_cheap: Array = district.get("mild_cheap_products", [])
	if mild_cheap.has(product_id):
		return tuning.affinity_mild_cheap_mult
	var cheap: Array = district.get("cheap_products", [])
	if cheap.has(product_id):
		return tuning.affinity_cheap_mult
	var pricy: Array = district.get("pricy_products", [])
	if pricy.has(product_id):
		if bool(district.get("west_o_pricy", false)):
			return tuning.affinity_west_o_mult
		return tuning.affinity_pricy_mult
	return 1.0


static func roll_forecast_event(
	available_today_ids: Array,
	mode: String, # "spike_buy_now" | "flood_tomorrow" | "random"
	tuning: TuningConfig,
	rng: RandomNumberGenerator
) -> Dictionary:
	if mode == "spike_buy_now" and not available_today_ids.is_empty():
		var pid: String = String(available_today_ids[rng.randi_range(0, available_today_ids.size() - 1)])
		var p_def := OmahaCatalog.get_product(pid)
		return {
			"product_id": pid,
			"product_name": p_def["name"],
			"event_type": "spike"
		}
	if mode == "flood_tomorrow":
		var idx := rng.randi_range(0, OmahaCatalog.PRODUCTS.size() - 1)
		var p_def: Dictionary = OmahaCatalog.PRODUCTS[idx]
		return {
			"product_id": p_def["id"],
			"product_name": p_def["name"],
			"event_type": "flood"
		}
	var r_idx := rng.randi_range(0, OmahaCatalog.PRODUCTS.size() - 1)
	var rp: Dictionary = OmahaCatalog.PRODUCTS[r_idx]
	var primary: String = rp["primary_event"]
	var secondary: String = "flood" if primary == "spike" else "spike"
	var et := primary if rng.randf() <= tuning.primary_event_weight else secondary
	return {
		"product_id": rp["id"],
		"product_name": rp["name"],
		"event_type": et
	}


static func _event_message_for(p_def: Dictionary, event_type: String) -> String:
	if event_type == "spike":
		return "🔥 4x SPIKE: " + String(p_def.get("spike_msg", ""))
	return "❄️ 1/4 FLOOD: " + String(p_def.get("flood_msg", ""))
