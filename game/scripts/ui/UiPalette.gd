class_name UiPalette

# Sleek Dark OLED "Omaha Street Noir" color palette, typography scale, and StyleBoxFlat builders
# optimized for the Pixel 10 Pro XL (1080 x 2400 portrait viewport).

const SLATE_BG := Color("#0B0F15")
const PANEL_BG := Color("#121923")
const CARD_BG := Color("#182230")
const CARD_ALT_BG := Color("#141C28")
const ROW_HOVER_BG := Color("#1E2C3E")
const MODAL_BACKDROP := Color(0.02, 0.04, 0.07, 0.88)

const BORDER_SLATE := Color("#26354A")
const BORDER_BRIGHT := Color("#3B5270")

const TEXT_PRIMARY := Color("#F1F5F9")
const TEXT_SECONDARY := Color("#94A3B8")
const TEXT_MUTED := Color("#58687E")

const CASH_EMERALD := Color("#22C55E")
const CASH_DARK := Color("#14532D")
const BANK_CYAN := Color("#38BDF8")
const DEBT_CRIMSON := Color("#F43F5E")
const GOLD_ACCENT := Color("#FACC15")
const PURPLE_VIP := Color("#C084FC")

const SPIKE_AMBER := Color("#F59E0B")
const SPIKE_BG := Color("#451A03")
const FLOOD_CYAN := Color("#06B6D4")
const FLOOD_BG := Color("#083344")

const POLICE_RED := Color("#EF4444")
const POLICE_BLUE := Color("#3B82F6")
const BTN_PRIMARY := Color("#1E3A5F")
const BTN_SUCCESS := Color("#15803D")
const BTN_DANGER := Color("#B91C1C")
const BTN_AMBER := Color("#B45309")
const BTN_DISABLED := Color("#1A222D")

# Chunky, readable font scale for 1080x2400 portrait viewport (Pixel 10 Pro XL)
const FONT_TITLE := 46
const FONT_HEADER := 38
const FONT_SUBHEAD := 32
const FONT_ROW_MAIN := 32
const FONT_ROW_SUB := 28
const FONT_BUTTON := 30
const FONT_SMALL := 26
const FONT_TINY := 24


static func make_box(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = 12,
	border_width: int = 2,
	pad_h: int = 16,
	pad_v: int = 12
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	if border.a > 0.01 and border_width > 0:
		sb.border_color = border
		sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func style_button(
	btn: Button,
	bg: Color,
	border: Color = Color.TRANSPARENT,
	text_col: Color = TEXT_PRIMARY,
	font_sz: int = FONT_BUTTON,
	radius: int = 12
) -> void:
	var normal := make_box(bg, border, radius, 2 if border.a > 0.01 else 0, 14, 10)
	var hover := make_box(bg.lightened(0.10), border.lightened(0.15), radius, 2 if border.a > 0.01 else 0, 14, 10)
	var pressed := make_box(bg.darkened(0.15), border, radius, 2 if border.a > 0.01 else 0, 14, 10)
	var disabled := make_box(BTN_DISABLED, Color("#222C3A"), radius, 1, 14, 10)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_focus_color", text_col)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.clip_text = true


static func add_label(parent: Node, text: String, font_sz: int = FONT_ROW_MAIN, col: Color = TEXT_PRIMARY, wrap: bool = true) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(lbl)
	return lbl


## Builds a strictly screen-bounded modal card inside `overlay` (never uses CenterContainer,
## so children can NEVER exceed the 1080px screen width).
static func build_modal_shell(
	overlay: ColorRect,
	title_text: String,
	border_col: Color,
	allow_close: bool = true,
	on_close: Callable = Callable()
) -> VBoxContainer:
	if allow_close:
		var bg_btn := Button.new()
		bg_btn.flat = true
		bg_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		overlay.add_child(bg_btn)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	overlay.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(outer_vbox)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", make_box(PANEL_BG, border_col, 20, 3, 24, 24))
	outer_vbox.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 18)
	card.add_child(card_vbox)

	# Header Row with wrapped title and unmissable Close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	card_vbox.add_child(header)

	var title_lbl := add_label(header, title_text, FONT_HEADER, GOLD_ACCENT, true)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if allow_close:
		var close_btn := Button.new()
		close_btn.text = "✕ CLOSE"
		close_btn.custom_minimum_size = Vector2(160, 68)
		style_button(close_btn, BTN_DANGER, DEBT_CRIMSON, TEXT_PRIMARY, FONT_SMALL)
		close_btn.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		header.add_child(close_btn)

	# Scrollable body so tall content never pushes buttons off the bottom of the screen
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 200)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(scroll)

	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 18)
	scroll.add_child(body_vbox)

	if allow_close:
		var bottom_close := Button.new()
		bottom_close.text = "⬅ BACK TO STREETS"
		bottom_close.custom_minimum_size = Vector2(0, 78)
		bottom_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		style_button(bottom_close, CARD_BG, BORDER_BRIGHT, TEXT_PRIMARY, FONT_BUTTON)
		bottom_close.pressed.connect(func() -> void:
			Audio.play(&"tap")
			if on_close.is_valid():
				on_close.call()
			else:
				overlay.visible = false
		)
		card_vbox.add_child(bottom_close)

	return body_vbox
