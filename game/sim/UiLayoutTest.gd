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

	# 1. Check Tab 0 (Market) + Hero Header geometry & camera-cutout clearance
	_assert_tree_within_bounds(main, "Tab 0 (Market)")
	var hero_rect: Rect2 = (main._hero_card as Control).get_global_rect()
	if hero_rect.position.y < 44.0 or hero_rect.size.y < 260.0:
		push_error("FAIL [Hero Header]: rect=%s (expected y >= 44 and height >= 260)" % str(hero_rect))
		quit(1)
		return
	var cash_rect: Rect2 = (main._cash_lbl.get_parent() as Control).get_global_rect()
	var debt_rect: Rect2 = (main._debt_lbl.get_parent() as Control).get_global_rect()
	if cash_rect.end.x > 470.0 or debt_rect.position.x < 610.0:
		push_error("FAIL [Camera Cutout Clearance]: cash_rect=%s debt_rect=%s overlap center cutout (470..610)" % [str(cash_rect), str(debt_rect)])
		quit(1)
		return
	var loc_lbl: Label = main._loc_lbl
	var day_lbl: Label = main._day_lbl
	var travel_btn: Button = main._travel_btn
	var scanner_card: PanelContainer = main._scanner_card
	var news_icon_rect: TextureRect = main._news_icon_rect
	var expected_loc := String(OmahaCatalog.get_district(main.state.current_district_id)["name"])
	if loc_lbl.text != expected_loc or loc_lbl.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or loc_lbl.get_global_rect().position.y < hero_rect.end.y or travel_btn.icon != UiIcons.get_icon("pin", 112) or news_icon_rect == null or news_icon_rect.size != Vector2(112, 112) or day_lbl.text.contains("Day"):
		push_error("FAIL [Split Strip & SVG Icons]: loc='%s' travel_icon=%s news_size=%s day='%s'" % [loc_lbl.text, str(travel_btn.icon), str(news_icon_rect.size if news_icon_rect else Vector2.ZERO), day_lbl.text])
		quit(1)
		return
	for icon_key in ["cash", "dollar", "shark", "bank", "calendar", "coat", "inventory", "heart", "siren", "newspaper", "newspaper_spike", "newspaper_flood", "car", "flag", "market", "pill", "crown", "trash", "gun", "shield", "hospital", "martini", "dice", "scales", "gem", "trophy", "gear", "speaker_on", "speaker_off", "pin", "close_x", "fire", "snowflake", "check", "lock"]:
		var tex := UiIcons.get_icon(icon_key, 64)
		if tex == null or tex.get_width() != 64 or tex.get_height() != 64:
			push_error("FAIL [UiIcons SVG Rasterizer]: icon '%s' failed to rasterize (tex=%s)" % [icon_key, str(tex)])
			quit(1)
			return
	if scanner_card.get_global_rect().size.x > 400.0 or loc_lbl.get_global_rect().position.x <= scanner_card.get_global_rect().end.x:
		push_error("FAIL [1/3 vs 2/3 Split]: scanner_rect=%s loc_rect=%s" % [str(scanner_card.get_global_rect()), str(loc_lbl.get_global_rect())])
		quit(1)
		return
	main.state.log_scanner("🚗 Day 2: Pulled into Council Bluffs.")
	main.state.log_scanner("🛒 Bought 5 Weed @ $150 ($750).")
	main._set_news_expanded(true)
	var exp_panel: PanelContainer = main._news_expand_panel
	var news_title: Label = main._news_title_lbl
	var news_close: Button = main._news_close_btn
	var expected_h := roundf((1440.0 - scanner_card.get_global_rect().position.y) * 1.25)
	var first_log_lbl: Label = main._news_expand_vbox.get_child(0) as Label
	var second_log_lbl: Label = main._news_expand_vbox.get_child(1) as Label
	if not exp_panel.visible or not main._news_overlay.visible or not is_equal_approx(exp_panel.position.x, 108.0) or not is_equal_approx(exp_panel.size.x, 810.0) or not is_equal_approx(exp_panel.size.y, expected_h) or news_title.get_theme_font_size("font_size") != 50 or news_close.icon != UiIcons.get_icon("close_x", 44) or first_log_lbl.get_theme_font_size("font_size") != 32 or first_log_lbl.has_theme_font_override("font") or not second_log_lbl.has_theme_font_override("font") or not first_log_lbl.text.begins_with("• ") or second_log_lbl.text.begins_with("•"):
		push_error("FAIL [News Popup Layout]: visible=%s pos=%s size=%s expected_h=%.1f title_sz=%d log_sz=%d" % [str(exp_panel.visible), str(exp_panel.position), str(exp_panel.size), expected_h, news_title.get_theme_font_size("font_size"), first_log_lbl.get_theme_font_size("font_size")])
		quit(1)
		return
	main._set_news_expanded(false)
	var tab0_btn: Button = main._tab_buttons[0]
	var tab2_btn: Button = main._tab_buttons[2]
	var tab0_rect: Rect2 = tab0_btn.get_global_rect()
	var tab0_sb: StyleBoxFlat = tab0_btn.get_theme_stylebox("normal") as StyleBoxFlat
	var tab2_sb: StyleBoxFlat = tab2_btn.get_theme_stylebox("normal") as StyleBoxFlat
	if tab0_rect.size.y < 196.0 or tab0_rect.end.y > 2353.0 or tab0_sb.corner_radius_bottom_left != 64 or tab2_sb.corner_radius_bottom_right != 64 or tab0_btn.icon != UiIcons.get_icon("market", 104) or main._tab_buttons[1].text != "COMMERCE":
		push_error("FAIL [Bottom Tab Bar]: rect=%s bl=%d br=%d" % [str(tab0_rect), tab0_sb.corner_radius_bottom_left, tab2_sb.corner_radius_bottom_right])
		quit(1)
		return

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

	# 5. Check TradeOverlay (both unowned and owned with 3rd DROP tab), LegacyOverlay, RunSummaryOverlay, DevTuningOverlay
	for p_def in OmahaCatalog.PRODUCTS:
		var pid := String(p_def["id"])
		if int(main.state.market_prices.get(pid, 0)) > 0:
			main.state.inventory[pid] = {"qty": 10, "avg_paid": 100}
			main._trade_overlay.open_for_product(main.state, pid)
			await process_frame
			await process_frame
			_assert_tree_within_bounds(main._trade_overlay, "TradeOverlay (%s with DROP tab)" % pid)
			main._trade_overlay.visible = false
			main.state.inventory[pid] = {"qty": 0, "avg_paid": 0}
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
