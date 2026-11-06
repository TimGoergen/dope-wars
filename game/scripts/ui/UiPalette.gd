class_name UiPalette

# Sleek Dark OLED "Omaha Street Noir" color palette, typography scale, and StyleBoxFlat builders
# optimized for the Pixel 10 Pro XL (1080 x 2400 portrait viewport).

const SLATE_BG := Color("#0B0F15")
const PANEL_BG := Color("#121923")
const CARD_BG := Color("#182230")
const CARD_ALT_BG := Color("#141C28")
const ROW_HOVER_BG := Color("#1E2C3E")
const MODAL_BACKDROP := Color(0.02, 0.04, 0.07, 0.86)

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

# Font scale for 1080x2400 portrait viewport
const FONT_TITLE := 36
const FONT_HEADER := 30
const FONT_SUBHEAD := 26
const FONT_ROW_MAIN := 26
const FONT_ROW_SUB := 22
const FONT_BUTTON := 24
const FONT_SMALL := 21
const FONT_TINY := 19


static func make_box(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = 12,
	border_width: int = 2,
	pad_h: int = 14,
	pad_v: int = 10
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


static func style_button(btn: Button, bg: Color, border: Color = Color.TRANSPARENT, text_col: Color = TEXT_PRIMARY, font_sz: int = FONT_BUTTON, radius: int = 10) -> void:
	var normal := make_box(bg, border, radius, 2 if border.a > 0.01 else 0, 12, 8)
	var hover := make_box(bg.lightened(0.10), border.lightened(0.15), radius, 2 if border.a > 0.01 else 0, 12, 8)
	var pressed := make_box(bg.darkened(0.15), border, radius, 2 if border.a > 0.01 else 0, 12, 8)
	var disabled := make_box(BTN_DISABLED, Color("#222C3A"), radius, 1, 12, 8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)
	btn.add_theme_color_override("font_disabled_color", TEXT_MUTED)
	btn.add_theme_font_size_override("font_size", font_sz)


static func add_label(parent: Node, text: String, font_sz: int = FONT_ROW_MAIN, col: Color = TEXT_PRIMARY) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl
