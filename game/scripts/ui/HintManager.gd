class_name HintManager
extends Node

# Interactive Element Onboarding & Tutorial Toasts.
# Shows small, stylized cel-shaded toast popups explaining interactive controls
# the first time a user views each screen in Dope Wars: Omaha.

const HINT_AUTOCLOSE_SEC: float = 6.0

const SCREEN_HINTS: Dictionary = {
	"start_screen": [
		{
			"title": "RUN DURATION",
			"icon": "calendar",
			"body": "Select 31, 60, 90 Days or Endless mode to launch your hustle across Omaha.",
			"color": Color(0.98, 0.80, 0.08) # Gold
		},
		{
			"title": "KINGPIN UTILITIES",
			"icon": "crown",
			"body": "View high scores in Hall of Fame, unlock persistent Street Cred perks, or configure Settings.",
			"color": Color(0.22, 0.74, 0.97) # Cyan
		}
	],
	"market_tab": [
		{
			"title": "STATUS HERO HEADER",
			"icon": "heart",
			"body": "Monitors your Cash, shark Debt, Coat capacity, Health, and District police danger.",
			"color": Color(0.13, 0.77, 0.37) # Emerald
		},
		{
			"title": "BUY & SELL CONTRABAND",
			"icon": "scales",
			"body": "Tap BUY to purchase drugs from locals. Tap SELL to cash in. Buy low, sell high across Omaha!",
			"color": Color(0.98, 0.80, 0.08) # Gold
		},
		{
			"title": "METRO TRAVEL",
			"icon": "car",
			"body": "Tap TRAVEL to ride the subway to a new district. Each trip advances 1 day and resets prices.",
			"color": Color(0.22, 0.74, 0.97) # Cyan
		}
	],
	"locals_tab": [
		{
			"title": "BANK & LOAN SHARK",
			"icon": "bank",
			"body": "Deposit cash to earn daily interest and protect it from muggers. Repay loan shark debt before interest piles up!",
			"color": Color(0.22, 0.74, 0.97) # Cyan
		},
		{
			"title": "HOSPITAL & STREET DEALERS",
			"icon": "hospital",
			"body": "Visit the Clinic to restore HP from gunfights. Find trunk vendors to buy weapons and expand your coat capacity.",
			"color": Color(0.75, 0.52, 0.99) # Purple
		}
	],
	"kingpin_tab": [
		{
			"title": "STREET CRED & PERKS",
			"icon": "trophy",
			"body": "Every finished run awards permanent Street Cred. Spend it here to unlock powerful starting advantages.",
			"color": Color(0.98, 0.80, 0.08) # Gold
		},
		{
			"title": "FACILITIES & EMPIRE",
			"icon": "bank",
			"body": "Purchase stash houses, safehouses, and grow labs across Omaha for daily passive revenue and storage.",
			"color": Color(0.13, 0.77, 0.37) # Emerald
		}
	],
	"trade_overlay": [
		{
			"title": "TRADE CONTROLS",
			"icon": "scales",
			"body": "Use the quantity slider or MIN / MAX buttons to set units, then tap CONFIRM to execute the trade.",
			"color": Color(0.98, 0.80, 0.08) # Gold
		}
	],
	"travel_overlay": [
		{
			"title": "DISTRICT TRANSIT",
			"icon": "car",
			"body": "Pick an Omaha neighborhood. Check police presence ratings — high heat raises the risk of DEA busts!",
			"color": Color(0.22, 0.74, 0.97) # Cyan
		}
	],
	"combat_overlay": [
		{
			"title": "POLICE INTERCEPTION",
			"icon": "siren",
			"body": "Cops caught you! Tap RUN to flee, FIGHT to shoot back if armed, or BRIBE with cash to walk away.",
			"color": Color(0.94, 0.27, 0.27) # Red
		}
	]
}


static func show_screen_hints(screen_id: String, parent_control: Control, meta: Dictionary) -> void:
	if parent_control == null or not is_instance_valid(parent_control):
		return

	var seen_hints: Array = meta.get("seen_screen_hints", [])
	if screen_id in seen_hints:
		return

	# Mark screen as seen and persist
	seen_hints.append(screen_id)
	meta["seen_screen_hints"] = seen_hints
	SaveManager.save_data(meta)

	var tips: Array = SCREEN_HINTS.get(screen_id, [])
	if tips.is_empty():
		return

	_start_toast_sequence(screen_id, parent_control, tips)


static func reset_all_hints(meta: Dictionary) -> void:
	meta["seen_screen_hints"] = []
	SaveManager.save_data(meta)


static func _start_toast_sequence(screen_id: String, parent_control: Control, tips: Array) -> void:
	# Clean up any existing toast overlay on this parent
	var existing := parent_control.get_node_or_null("HintToastOverlay")
	if existing != null:
		existing.queue_free()

	var overlay := MarginContainer.new()
	overlay.name = "HintToastOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Anchor toast in upper third below headers
	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var top_offset := 310
	if screen_id == "start_screen":
		top_offset = 240
	elif screen_id in ["trade_overlay", "travel_overlay", "combat_overlay"]:
		top_offset = 170

	overlay.add_theme_constant_override("margin_top", top_offset)
	overlay.add_theme_constant_override("margin_left", 32)
	overlay.add_theme_constant_override("margin_right", 32)
	parent_control.add_child(overlay)

	_show_tip_step(overlay, tips, 0)


static func _show_tip_step(overlay: MarginContainer, tips: Array, index: int) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	if index >= tips.size():
		overlay.queue_free()
		return

	# Clear previous card
	for c in overlay.get_children():
		c.queue_free()

	var tip_data: Dictionary = tips[index]
	var title_str := String(tip_data.get("title", "HINT"))
	var icon_name := String(tip_data.get("icon", "gem"))
	var body_str := String(tip_data.get("body", ""))
	var border_col: Color = tip_data.get("color", UiPalette.BANK_CYAN)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		UiPalette.make_box(Color(0.07, 0.10, 0.16, 0.96), border_col, 16, 3, 20, 16)
	)
	overlay.add_child(card)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Icon
	var icon_rect := TextureRect.new()
	icon_rect.texture = UiIcons.get_icon(icon_name, 52)
	icon_rect.custom_minimum_size = Vector2(52, 52)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	# Content column
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	# Header row with title & step counter
	var hdr_row := HBoxContainer.new()
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr_row)

	var title_lbl := Label.new()
	title_lbl.text = "💡  " + title_str
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", border_col)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(title_lbl)

	var step_lbl := Label.new()
	step_lbl.text = "%d / %d" % [index + 1, tips.size()]
	step_lbl.add_theme_font_size_override("font_size", 22)
	step_lbl.add_theme_color_override("font_color", UiPalette.TEXT_MUTED)
	step_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(step_lbl)

	# Body text
	var body_lbl := Label.new()
	body_lbl.text = body_str
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_lbl.add_theme_font_size_override("font_size", 24)
	body_lbl.add_theme_color_override("font_color", UiPalette.TEXT_PRIMARY)
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body_lbl)

	# Bottom action hint
	var is_last := (index + 1 >= tips.size())
	var action_lbl := Label.new()
	action_lbl.text = "[ Tap anywhere to dismiss ✕ ]" if is_last else "[ Tap anywhere for next tip ▶ ]"
	action_lbl.add_theme_font_size_override("font_size", 18)
	action_lbl.add_theme_color_override("font_color", border_col.lightened(0.2))
	action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(action_lbl)

	# Full-card tap button
	var tap_btn := Button.new()
	tap_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap_btn.flat = true
	tap_btn.focus_mode = Control.FOCUS_NONE
	card.add_child(tap_btn)

	# State flag to prevent multiple advances
	var advanced := [false]
	var advance_callable = func(is_tap: bool) -> void:
		if advanced[0]:
			return
		advanced[0] = true
		if is_tap:
			Audio.play(&"tap")
		if is_instance_valid(card):
			var tw := card.create_tween()
			tw.tween_property(card, "modulate:a", 0.0, 0.18)
			tw.tween_callback(func() -> void:
				_show_tip_step(overlay, tips, index + 1)
			)
		else:
			_show_tip_step(overlay, tips, index + 1)

	tap_btn.pressed.connect(func() -> void: advance_callable.call(true))

	# Auto-close timer
	var tree := overlay.get_tree()
	if tree != null:
		var timer := tree.create_timer(HINT_AUTOCLOSE_SEC)
		timer.timeout.connect(func() -> void: advance_callable.call(false))

	# Entry fade animation
	card.modulate.a = 0.0
	var enter_tw := card.create_tween()
	enter_tw.tween_property(card, "modulate:a", 1.0, 0.22)
