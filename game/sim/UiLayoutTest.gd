extends SceneTree

# Headless UI Layout & Bounds Verification Gate.
# Boots Main.tscn, exercises all 3 tabs across all 8 Omaha districts, and opens every modal overlay,
# asserting that no PanelContainer or Button ever exceeds the 1080px viewport width.

func _initialize() -> void:
	var frame := Control.new()
	frame.size = Vector2(1080, 2400)
	root.add_child(frame)
	var packed: PackedScene = load("res://Main.tscn")
	var main: Control = packed.instantiate()
	frame.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	await process_frame
	await process_frame
	print("main.size=", main.size, " main.min=", main.get_combined_minimum_size())

	# 1. Check Tab 0 (Market)
	_assert_tree_within_bounds(main, "Tab 0 (Market)")

	# 2. Check Travel Modal
	main._open_travel_modal()
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._travel_overlay, "Travel Modal")
	main._travel_overlay.visible = false

	# 3. Check Tab 1 (Spot & Bank) across all 8 Omaha districts + Facility Modal
	for d_def in OmahaCatalog.DISTRICTS:
		main.state.current_district_id = String(d_def["id"])
		main._show_tab(1)
		await process_frame
		await process_frame
		_assert_tree_within_bounds(main, "Tab 1 (%s)" % d_def["name"])

		main._facility_overlay.open_district_facility(main.state)
		await process_frame
		await process_frame
		_assert_tree_within_bounds(main._facility_overlay, "FacilityOverlay (%s)" % d_def["name"])
		main._facility_overlay.visible = false

	# 4. Check Tab 2 (Kingpin)
	main._show_tab(2)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main, "Tab 2 (Kingpin)")

	# 5. Check TradeOverlay, LegacyOverlay, RunSummaryOverlay, DevTuningOverlay
	for p_def in OmahaCatalog.PRODUCTS:
		var pid := String(p_def["id"])
		if int(main.state.market_prices.get(pid, 0)) > 0:
			main._trade_overlay.open_for_product(main.state, pid)
			await process_frame
			await process_frame
			_assert_tree_within_bounds(main._trade_overlay, "TradeOverlay (%s)" % pid)
			main._trade_overlay.visible = false
			break

	main._legacy_overlay.open_modal(main.meta)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._legacy_overlay, "LegacyOverlay")
	main._legacy_overlay.visible = false

	main._summary_overlay.open_summary(main.state, main.meta, true)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._summary_overlay, "RunSummaryOverlay")
	main._summary_overlay.visible = false

	main._dev_tuning_overlay.open_panel(main.tuning)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._dev_tuning_overlay, "DevTuningOverlay")
	main._dev_tuning_overlay.visible = false

	# 6. Check CombatOverlay & EncounterOverlay
	main.state.pending_choice_event = {
		"type": "coat",
		"title": "Carhartt Trenchcoat Vendor",
		"prompt": "A street vendor outside the pawn shop offers a heavy-duty Carhartt coat (+50 Carry Space) for $1,500.",
		"cost": 1500,
		"capacity_gain": 50
	}
	main._encounter_overlay.refresh(main.state)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._encounter_overlay, "EncounterOverlay")
	main.state.pending_choice_event = {}
	main._encounter_overlay.refresh(main.state)

	main.state.active_combat = CombatEngine.create_encounter(50.0, main.state.crew_count, main.tuning, main.state.rng)
	main._combat_overlay.refresh(main.state)
	await process_frame
	await process_frame
	_assert_tree_within_bounds(main._combat_overlay, "CombatOverlay")
	main.state.active_combat = {}
	main._combat_overlay.refresh(main.state)

	print("UiLayoutTest: PASS (all 3 tabs, 8 district spots, and all 8 modals strictly within 1080px width)")
	quit(0)


func _assert_tree_within_bounds(node: Node, context: String) -> void:
	if node is Control:
		var ctrl := node as Control
		if not ctrl.visible:
			return
		var rect := ctrl.get_global_rect()
		var min_sz := ctrl.get_combined_minimum_size()
		if min_sz.x > 1080.0:
			push_error("FAIL [%s]: %s has minimum width %.1f > 1080" % [context, ctrl.name, min_sz.x])
			quit(1)
			return
		if ctrl is PanelContainer or ctrl is Button:
			if rect.position.x < -1.0 or rect.end.x > 1081.0:
				push_error("FAIL [%s]: %s (%s) overflows horizontally: x=%.1f..%.1f (width=%.1f)" % [
					context, ctrl.name, ctrl.get("text") if ctrl is Button else "Panel", rect.position.x, rect.end.x, rect.size.x
				])
				quit(1)
				return
	for c in node.get_children():
		_assert_tree_within_bounds(c, context)
