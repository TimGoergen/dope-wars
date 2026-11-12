class_name HintManager
extends Node

# Interactive Element Onboarding & Tutorial Toasts.
# Shows clean, off-white speech-bubble toasts with a small triangular arrow
# pointing directly to the interactive elements being explained.

const HINT_AUTOCLOSE_SEC: float = 6.0

const BG_COLOR := Color(0.97, 0.98, 0.99, 0.98) # Crisp off-white (#F8FAFC)
const BORDER_COLOR := Color(0.60, 0.65, 0.72, 1.0) # Slate border (#94A3B8)
const TEXT_TITLE := Color(0.06, 0.09, 0.16, 1.0) # Deep slate black (#0F172A)
const TEXT_BODY := Color(0.12, 0.16, 0.24, 1.0) # Readable dark slate (#1E293B)
const TEXT_MUTED := Color(0.40, 0.46, 0.54, 1.0) # Slate-500 (#64748B)
const TEXT_LINK := Color(0.10, 0.38, 0.85, 1.0) # Vibrant tutorial blue (#1D4ED8)

const SCREEN_HINTS: Dictionary = {
	"start_screen": [
		{
			"title": "RUN DURATION",
			"icon": "calendar",
			"body": "Select 31, 60, 90 Days or Endless mode to launch your hustle across Omaha.",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 740
		},
		{
			"title": "KINGPIN UTILITIES",
			"icon": "crown",
			"body": "View high scores in Hall of Fame, unlock persistent Street Cred perks, or configure Settings.",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 1940
		}
	],
	"market_tab": [
		{
			"title": "STATUS HERO HEADER",
			"icon": "heart",
			"body": "Monitors your Cash, shark Debt, Coat capacity, Health, and District police danger.",
			"arrow_dir": "up",
			"arrow_x": 0.5,
			"top_y": 310
		},
		{
			"title": "BUY & SELL DRUGS",
			"icon": "scales",
			"body": "Tap BUY to purchase drugs from locals. Tap SELL to cash in. Buy low, sell high across Omaha!",
			"arrow_dir": "up",
			"arrow_x": 0.82,
			"top_y": 660
		},
		{
			"title": "METRO TRAVEL",
			"icon": "car",
			"body": "Tap TRAVEL to ride the subway to a new district. Each trip advances 1 day and resets prices.",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 1840
		}
	],
	"locals_tab": [
		{
			"title": "BANK & LOAN SHARK",
			"icon": "bank",
			"body": "Deposit cash to earn daily interest and protect it from muggers. Repay loan shark debt before interest piles up!",
			"arrow_dir": "up",
			"arrow_x": 0.5,
			"top_y": 300
		},
		{
			"title": "HOSPITAL & STREET DEALERS",
			"icon": "hospital",
			"body": "Visit the Clinic to restore HP from gunfights. Find trunk vendors to buy weapons and expand your coat capacity.",
			"arrow_dir": "up",
			"arrow_x": 0.5,
			"top_y": 1150
		}
	],
	"kingpin_tab": [
		{
			"title": "STREET CRED & PERKS",
			"icon": "trophy",
			"body": "Every finished run awards permanent Street Cred. Spend it here to unlock powerful starting advantages.",
			"arrow_dir": "up",
			"arrow_x": 0.5,
			"top_y": 300
		},
		{
			"title": "FACILITIES & EMPIRE",
			"icon": "bank",
			"body": "Purchase stash houses, safehouses, and grow labs across Omaha for daily passive revenue and storage.",
			"arrow_dir": "up",
			"arrow_x": 0.5,
			"top_y": 920
		}
	],
	"trade_overlay": [
		{
			"title": "TRADE CONTROLS",
			"icon": "scales",
			"body": "Use the quantity slider or MIN / MAX buttons to set units, then tap CONFIRM to execute the trade.",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 800
		}
	],
	"travel_overlay": [
		{
			"title": "DISTRICT TRANSIT",
			"icon": "car",
			"body": "Pick an Omaha neighborhood. Check police presence ratings — high heat raises the risk of DEA busts!",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 240
		}
	],
	"combat_overlay": [
		{
			"title": "POLICE INTERCEPTION",
			"icon": "siren",
			"body": "Cops caught you! Tap RUN to flee, FIGHT to shoot back if armed, or BRIBE with cash to walk away.",
			"arrow_dir": "down",
			"arrow_x": 0.5,
			"top_y": 1640
		}
	]
}


# Custom lightweight control to draw the triangular callout pointer arrow
class ArrowPointer extends Control:
	var points_up: bool = false
	var arrow_x_pct: float = 0.5
	var arrow_width: float = 30.0
	var arrow_height: float = 16.0

	func _init(up: bool, x_pct: float) -> void:
		points_up = up
		arrow_x_pct = x_pct
		custom_minimum_size = Vector2(0, arrow_height)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var center_x := size.x * arrow_x_pct
		var half_w := arrow_width / 2.0
		var x_left := clampf(center_x - half_w, 24.0, size.x - 24.0 - arrow_width)
		var x_right := x_left + arrow_width
		var x_tip := x_left + half_w

		var pts: PackedVector2Array
		if points_up:
			# Triangle pointing upwards: apex at top (y=0), base at bottom (y=arrow_height)
			pts = PackedVector2Array([
				Vector2(x_left, arrow_height),
				Vector2(x_tip, 0.0),
				Vector2(x_right, arrow_height)
			])
		else:
			# Triangle pointing downwards: base at top (y=0), apex at bottom (y=arrow_height)
			pts = PackedVector2Array([
				Vector2(x_left, 0.0),
				Vector2(x_tip, arrow_height),
				Vector2(x_right, 0.0)
			])

		# Fill triangle with matching off-white
		draw_colored_polygon(pts, BG_COLOR)
		# Draw clean outer borders on angled sides
		draw_line(pts[0], pts[1], BORDER_COLOR, 2.5, true)
		draw_line(pts[1], pts[2], BORDER_COLOR, 2.5, true)


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

	overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
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

	# Clear previous contents
	for c in overlay.get_children():
		c.queue_free()

	var tip_data: Dictionary = tips[index]
	var title_str := String(tip_data.get("title", "TUTORIAL"))
	var icon_name := String(tip_data.get("icon", "gem"))
	var body_str := String(tip_data.get("body", ""))
	var arrow_dir := String(tip_data.get("arrow_dir", "down"))
	var arrow_x := float(tip_data.get("arrow_x", 0.5))
	var top_y := int(tip_data.get("top_y", 320))

	# Update overlay margin_top to place the toast near the target item
	overlay.add_theme_constant_override("margin_top", top_y)

	# Main vertical stack containing the speech bubble card + arrow
	var bubble_stack := VBoxContainer.new()
	bubble_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_stack.add_theme_constant_override("separation", -1) # Overlap by 1px so arrow seamlessly connects to border
	bubble_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(bubble_stack)

	# If arrow points up, arrow sits on TOP of the card
	if arrow_dir == "up":
		var arrow_top := ArrowPointer.new(true, arrow_x)
		bubble_stack.add_child(arrow_top)

	# The off-white speech bubble card
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_COLOR
	sb.border_color = BORDER_COLOR
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 16
	# Subtle shadow to pop out distinctly against any game background
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", sb)
	bubble_stack.add_child(card)

	# If arrow points down, arrow sits at the BOTTOM of the card
	if arrow_dir == "down":
		var arrow_bottom := ArrowPointer.new(false, arrow_x)
		bubble_stack.add_child(arrow_bottom)

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 18)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# Left Icon
	var icon_rect := TextureRect.new()
	icon_rect.texture = UiIcons.get_icon(icon_name, 56)
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_rect)

	# Center text column
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	# Header row (Title + Step Counter)
	var hdr_row := HBoxContainer.new()
	hdr_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hdr_row)

	var title_lbl := Label.new()
	title_lbl.text = "💡  " + title_str
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", TEXT_TITLE)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(title_lbl)

	var step_lbl := Label.new()
	step_lbl.text = "%d of %d" % [index + 1, tips.size()]
	step_lbl.add_theme_font_size_override("font_size", 22)
	step_lbl.add_theme_color_override("font_color", TEXT_MUTED)
	step_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_row.add_child(step_lbl)

	# Body explanation
	var body_lbl := Label.new()
	body_lbl.text = body_str
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_lbl.add_theme_font_size_override("font_size", 24)
	body_lbl.add_theme_color_override("font_color", TEXT_BODY)
	body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body_lbl)

	# Action prompt footer
	var is_last := (index + 1 >= tips.size())
	var action_lbl := Label.new()
	action_lbl.text = "[ Tap anywhere to dismiss ✕ ]" if is_last else "[ Tap anywhere for next tip ▶ ]"
	action_lbl.add_theme_font_override("font", UiPalette.make_bold_font())
	action_lbl.add_theme_font_size_override("font_size", 19)
	action_lbl.add_theme_color_override("font_color", TEXT_LINK)
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
		if is_instance_valid(bubble_stack):
			var tw := bubble_stack.create_tween()
			tw.tween_property(bubble_stack, "modulate:a", 0.0, 0.16)
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

	# Entry fade & slide-in animation
	bubble_stack.modulate.a = 0.0
	var enter_tw := bubble_stack.create_tween()
	enter_tw.tween_property(bubble_stack, "modulate:a", 1.0, 0.20)
