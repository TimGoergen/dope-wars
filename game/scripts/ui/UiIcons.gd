class_name UiIcons

# Runtime vector SVG icon factory and cache.
# Rasterizes crisp, high-contrast vector SVG icons via Godot's built-in ThorVG engine
# (Image.load_svg_from_string) so icons render 100% identically on Android (Pixel 10 Pro XL)
# and Windows PC without relying on OS emoji fonts or .import files.

static var _cache: Dictionary = {}

const EMOJI_TO_ICON := {
	"🏦🦈": "bank",
	"💵": "cash",
	"💰": "cash",
	"💳": "cash",
	"💲": "dollar",
	"🦈": "shark",
	"🏦": "bank",
	"🏧": "bank",
	"📅": "calendar",
	"🧥": "coat",
	"📦": "coat",
	"💼": "coat",
	"❤️": "heart",
	"❤": "heart",
	"💉": "heart",
	"🚨": "siren",
	"🚓": "siren",
	"📰": "newspaper",
	"🚗": "car",
	"💨": "car",
	"🏁": "flag",
	"🏳️": "flag",
	"🏳": "flag",
	"💊": "pill",
	"👑": "crown",
	"🎖️": "crown",
	"🎖": "crown",
	"🗑️": "trash",
	"🗑": "trash",
	"🔪": "trash",
	"🔫": "gun",
	"🛡️": "shield",
	"🛡": "shield",
	"👥": "shield",
	"🏥": "hospital",
	"🍸": "martini",
	"🥂": "martini",
	"🎰": "dice",
	"🃏": "dice",
	"🧼": "dice",
	"⚖️": "scales",
	"⚖": "scales",
	"📂": "scales",
	"💎": "gem",
	"⭐": "gem",
	"🏆": "trophy",
	"💀": "trophy",
	"⚙️": "gear",
	"⚙": "gear",
	"🔊": "speaker_on",
	"🔇": "speaker_off",
	"📍": "pin",
	"🔥": "fire",
	"📈": "fire",
	"❄️": "snowflake",
	"❄": "snowflake",
	"🏷️": "snowflake",
	"🏷": "snowflake",
	"✅": "check",
	"🟢": "check",
	"🔒": "lock",
	"⚪": "lock",
	"🛒": "cash",
	"🎒": "coat",
	"🤝": "cash",
	"🐕": "siren",
	"🕳️": "trash",
	"🕳": "trash",
	"🍺": "martini",
	"📻": "newspaper",
	"📡": "newspaper"
}


static func get_icon(name: String, size_px: int = 64) -> Texture2D:
	var key := "%s_%d" % [name, size_px]
	if _cache.has(key):
		return _cache[key]

	var svg := _get_svg_markup(name)
	var scale := float(size_px) / 64.0
	var img := Image.new()
	var err := img.load_svg_from_string(svg, scale)
	if err != OK or img.is_empty():
		img = Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
		img.fill(Color("#FACC15"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func create_icon_rect(name: String, size_px: int = 52) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = get_icon(name, size_px)
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func icon_for_district(district_id: String) -> String:
	match district_id:
		"north_omaha":
			return "bank"
		"south_omaha":
			return "gun"
		"benson":
			return "hospital"
		"west_omaha":
			return "martini"
		"council_bluffs":
			return "dice"
		"old_market":
			return "scales"
		"blackstone":
			return "martini"
		"bellevue":
			return "car"
		_:
			return "bank"


static func extract_leading_icon(raw_text: String) -> Dictionary:
	var trimmed := raw_text.strip_edges()
	for emoji_key in EMOJI_TO_ICON.keys():
		var k := String(emoji_key)
		if trimmed.begins_with(k):
			var rest := trimmed.substr(k.length()).strip_edges()
			return {
				"icon": String(EMOJI_TO_ICON[k]),
				"text": strip_emojis(rest)
			}
	return {
		"icon": "",
		"text": strip_emojis(raw_text)
	}


static func strip_emojis(raw_text: String) -> String:
	var s := raw_text
	for emoji_key in EMOJI_TO_ICON.keys():
		s = s.replace(String(emoji_key), "")
	# Also strip variation selectors (U+FE0F) and double spaces left behind
	s = s.replace("\uFE0F", "")
	while s.contains("   "):
		s = s.replace("   ", "  ")
	return s.strip_edges()


static func _get_svg_markup(name: String) -> String:
	match name:
		"cash":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="4" y="14" width="56" height="36" rx="6" fill="#16A34A" stroke="#052E16" stroke-width="3"/>
				<rect x="9" y="19" width="46" height="26" rx="3" fill="#22C55E" stroke="#86EFAC" stroke-width="2"/>
				<circle cx="32" cy="32" r="10" fill="#15803D"/>
				<path d="M32 23 v18 M28 27 c0-2 8-2 8 1 c0 3-8 3-8 6 c0 3 8 3 8 1" stroke="#F0FDF4" stroke-width="3.2" stroke-linecap="round" fill="none"/>
				<circle cx="15" cy="32" r="3" fill="#BBF7D0"/>
				<circle cx="49" cy="32" r="3" fill="#BBF7D0"/>
			</svg>"""
		"dollar":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect width="64" height="64" rx="12" fill="#0A0D12"/>
				<rect x="4.75" y="4.75" width="54.5" height="54.5" rx="10" fill="#121721" stroke="#22C55E" stroke-width="4"/>
				<rect x="28.5" y="8" width="7" height="48" rx="3.5" fill="#F59E0B"/>
				<path d="M 41.5 22.25 C 41.5 15.5, 22 15.5, 22 24 C 22 31.75, 42.25 31.75, 42.25 40.25 C 42.25 48.5, 22.25 48.5, 22.25 41.75"
					fill="none" stroke="#22C55E" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
			</svg>"""
		"shark":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<circle cx="32" cy="32" r="27" fill="#4C0519" stroke="#FB7185" stroke-width="3"/>
				<path d="M16 44 C22 28, 30 15, 44 12 C39 24, 39 34, 48 44 Z" fill="#F43F5E" stroke="#FFE4E6" stroke-width="2.5" stroke-linejoin="round"/>
				<path d="M10 46 Q21 41 32 46 T54 46" stroke="#38BDF8" stroke-width="4" stroke-linecap="round" fill="none"/>
				<path d="M14 53 Q25 48 36 53 T52 53" stroke="#7DD3FC" stroke-width="3" stroke-linecap="round" fill="none"/>
			</svg>"""
		"bank":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="32,6 6,22 58,22" fill="#38BDF8" stroke="#082F49" stroke-width="3" stroke-linejoin="round"/>
				<circle cx="32" cy="16" r="3.5" fill="#FACC15"/>
				<rect x="8" y="22" width="48" height="5" rx="1.5" fill="#7DD3FC" stroke="#082F49" stroke-width="2"/>
				<rect x="13" y="27" width="6" height="21" fill="#E0F2FE" stroke="#082F49" stroke-width="2"/>
				<rect x="29" y="27" width="6" height="21" fill="#E0F2FE" stroke="#082F49" stroke-width="2"/>
				<rect x="45" y="27" width="6" height="21" fill="#E0F2FE" stroke="#082F49" stroke-width="2"/>
				<rect x="8" y="48" width="48" height="5" rx="1.5" fill="#38BDF8" stroke="#082F49" stroke-width="2"/>
				<rect x="4" y="53" width="56" height="6" rx="2" fill="#0284C7" stroke="#082F49" stroke-width="2"/>
			</svg>"""
		"calendar":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="8" y="12" width="48" height="46" rx="7" fill="#F8FAFC" stroke="#0F172A" stroke-width="3"/>
				<path d="M8 19 a7 7 0 0 1 7 -7 h34 a7 7 0 0 1 7 7 v7 h-48 z" fill="#EF4444" stroke="#0F172A" stroke-width="3"/>
				<rect x="18" y="6" width="6" height="12" rx="3" fill="#FACC15" stroke="#0F172A" stroke-width="2"/>
				<rect x="40" y="6" width="6" height="12" rx="3" fill="#FACC15" stroke="#0F172A" stroke-width="2"/>
				<rect x="16" y="33" width="8" height="7" rx="1.5" fill="#334155"/>
				<rect x="28" y="33" width="8" height="7" rx="1.5" fill="#334155"/>
				<rect x="40" y="33" width="8" height="7" rx="1.5" fill="#EF4444"/>
				<rect x="16" y="45" width="8" height="7" rx="1.5" fill="#334155"/>
				<rect x="28" y="45" width="8" height="7" rx="1.5" fill="#334155"/>
				<rect x="40" y="45" width="8" height="7" rx="1.5" fill="#334155"/>
			</svg>"""
		"coat", "inventory":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="4" y="9" width="56" height="24" rx="7" fill="#0F172A"/>
				<path d="M 6 29 H 58 V 47 A 8 8 0 0 1 50 55 H 14 A 8 8 0 0 1 6 47 Z" fill="#0F172A"/>
				<path d="M 9 35 H 55 V 47 A 5 5 0 0 1 50 52 H 14 A 5 5 0 0 1 9 47 Z" fill="#D97706"/>
				<path d="M 12 12 H 15 V 30 H 12 A 5 5 0 0 1 7 25 V 17 A 5 5 0 0 1 12 12 Z" fill="#F59E0B"/>
				<rect x="19" y="12" width="26" height="18" fill="#F59E0B"/>
				<path d="M 49 12 H 52 A 5 5 0 0 1 57 17 V 25 A 5 5 0 0 1 52 30 H 49 Z" fill="#F59E0B"/>
				<rect x="15" y="12" width="4" height="23" fill="#F8FAFC"/>
				<rect x="45" y="12" width="4" height="23" fill="#F8FAFC"/>
				<rect x="9" y="30" width="46" height="5" fill="#F8FAFC"/>
				<rect x="24" y="24" width="16" height="16" rx="5" fill="#F8FAFC"/>
				<rect x="29.5" y="37" width="5" height="8" rx="2.5" fill="#F8FAFC"/>
			</svg>"""
		"heart":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M32 56 C32 56 7 40 7 21 C7 11 16 6 24 6 C28 6 31 9 32 12 C33 9 36 6 40 6 C48 6 57 11 57 21 C57 40 32 56 32 56 Z" fill="#EF4444" stroke="#450A0A" stroke-width="3.5" stroke-linejoin="round"/>
				<path d="M16 16 C19 12 23 12 25 14" stroke="#FECACA" stroke-width="3.5" stroke-linecap="round" fill="none"/>
			</svg>"""
		"siren":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<line x1="32" y1="4" x2="32" y2="11" stroke="#FACC15" stroke-width="4" stroke-linecap="round"/>
				<line x1="11" y1="12" x2="17" y2="17" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/>
				<line x1="53" y1="12" x2="47" y2="17" stroke="#EF4444" stroke-width="4" stroke-linecap="round"/>
				<line x1="5" y1="29" x2="12" y2="29" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/>
				<line x1="59" y1="29" x2="52" y2="29" stroke="#EF4444" stroke-width="4" stroke-linecap="round"/>
				<path d="M18 46 L20 24 C20 15 44 15 44 24 L46 46 Z" fill="#EF4444" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<path d="M25 24 L24 42" stroke="#FCA5A5" stroke-width="4" stroke-linecap="round"/>
				<rect x="12" y="46" width="40" height="11" rx="4" fill="#334155" stroke="#0F172A" stroke-width="3"/>
			</svg>"""
		"newspaper":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="12" y="10" width="46" height="48" rx="5" fill="#94A3B8" stroke="#0F172A" stroke-width="3.5"/>
				<rect x="6" y="6" width="46" height="48" rx="5" fill="#F8FAFC" stroke="#0F172A" stroke-width="3.5"/>
				<rect x="11" y="11" width="36" height="10" rx="2" fill="#FACC15" stroke="#0F172A" stroke-width="2"/>
				<rect x="11" y="25" width="16" height="15" rx="2" fill="#38BDF8" stroke="#0F172A" stroke-width="2"/>
				<line x1="31" y1="27" x2="46" y2="27" stroke="#0F172A" stroke-width="3.5" stroke-linecap="round"/>
				<line x1="31" y1="33" x2="46" y2="33" stroke="#334155" stroke-width="3" stroke-linecap="round"/>
				<line x1="31" y1="39" x2="43" y2="39" stroke="#334155" stroke-width="3" stroke-linecap="round"/>
				<line x1="12" y1="46" x2="46" y2="46" stroke="#334155" stroke-width="3" stroke-linecap="round"/>
			</svg>"""
		"newspaper_spike":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="12" y="10" width="46" height="48" rx="5" fill="#92400E" stroke="#0F172A" stroke-width="3.5"/>
				<rect x="6" y="6" width="46" height="48" rx="5" fill="#FEF3C7" stroke="#F59E0B" stroke-width="3.5"/>
				<rect x="11" y="11" width="36" height="10" rx="2" fill="#EF4444" stroke="#0F172A" stroke-width="2"/>
				<rect x="11" y="25" width="16" height="15" rx="2" fill="#F59E0B" stroke="#0F172A" stroke-width="2"/>
				<line x1="31" y1="27" x2="46" y2="27" stroke="#78350F" stroke-width="3.5" stroke-linecap="round"/>
				<line x1="31" y1="33" x2="46" y2="33" stroke="#92400E" stroke-width="3" stroke-linecap="round"/>
				<line x1="31" y1="39" x2="43" y2="39" stroke="#92400E" stroke-width="3" stroke-linecap="round"/>
				<line x1="12" y1="46" x2="46" y2="46" stroke="#92400E" stroke-width="3" stroke-linecap="round"/>
			</svg>"""
		"newspaper_flood":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="12" y="10" width="46" height="48" rx="5" fill="#155E75" stroke="#0F172A" stroke-width="3.5"/>
				<rect x="6" y="6" width="46" height="48" rx="5" fill="#E0F2FE" stroke="#22D3EE" stroke-width="3.5"/>
				<rect x="11" y="11" width="36" height="10" rx="2" fill="#0284C7" stroke="#0F172A" stroke-width="2"/>
				<rect x="11" y="25" width="16" height="15" rx="2" fill="#22D3EE" stroke="#0F172A" stroke-width="2"/>
				<line x1="31" y1="27" x2="46" y2="27" stroke="#082F49" stroke-width="3.5" stroke-linecap="round"/>
				<line x1="31" y1="33" x2="46" y2="33" stroke="#0C4A6E" stroke-width="3" stroke-linecap="round"/>
				<line x1="31" y1="39" x2="43" y2="39" stroke="#0C4A6E" stroke-width="3" stroke-linecap="round"/>
				<line x1="12" y1="46" x2="46" y2="46" stroke="#0C4A6E" stroke-width="3" stroke-linecap="round"/>
			</svg>"""
		"car":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M14 28 L22 15 L44 15 L52 28 L59 31 L59 44 L5 44 L5 31 Z" fill="#FACC15" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<polygon points="18,27 24,18 33,18 33,27" fill="#38BDF8" stroke="#0F172A" stroke-width="2"/>
				<polygon points="36,27 36,18 42,18 48,27" fill="#38BDF8" stroke="#0F172A" stroke-width="2"/>
				<rect x="5" y="33" width="5" height="5" rx="1.5" fill="#EF4444"/>
				<rect x="54" y="33" width="5" height="5" rx="1.5" fill="#FEF08A"/>
				<circle cx="18" cy="45" r="8" fill="#1E293B" stroke="#0F172A" stroke-width="3"/>
				<circle cx="18" cy="45" r="3.5" fill="#CBD5E1"/>
				<circle cx="46" cy="45" r="8" fill="#1E293B" stroke="#0F172A" stroke-width="3"/>
				<circle cx="46" cy="45" r="3.5" fill="#CBD5E1"/>
			</svg>"""
		"flag":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<line x1="14" y1="8" x2="14" y2="56" stroke="#FACC15" stroke-width="4" stroke-linecap="round"/>
				<rect x="16" y="10" width="38" height="26" rx="2" fill="#F8FAFC" stroke="#0F172A" stroke-width="3"/>
				<rect x="16" y="10" width="9.5" height="13" fill="#0F172A"/>
				<rect x="35" y="10" width="9.5" height="13" fill="#0F172A"/>
				<rect x="25.5" y="23" width="9.5" height="13" fill="#0F172A"/>
				<rect x="44.5" y="23" width="9.5" height="13" fill="#0F172A"/>
			</svg>"""
		"pill":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<g transform="rotate(-45 32 32)">
					<rect x="10" y="20" width="44" height="24" rx="12" fill="#F8FAFC" stroke="#0F172A" stroke-width="3"/>
					<path d="M32 20 H22 A12 12 0 0 0 22 44 H32 Z" fill="#EF4444" stroke="#0F172A" stroke-width="3"/>
					<line x1="18" y1="26" x2="28" y2="26" stroke="#FCA5A5" stroke-width="3" stroke-linecap="round"/>
				</g>
			</svg>"""
		"crown":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="8,48 12,18 25,31 32,12 39,31 52,18 56,48" fill="#FACC15" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<rect x="8" y="48" width="48" height="7" rx="2" fill="#EAB308" stroke="#0F172A" stroke-width="3"/>
				<circle cx="32" cy="38" r="4" fill="#EF4444"/>
				<circle cx="19" cy="40" r="3" fill="#38BDF8"/>
				<circle cx="45" cy="40" r="3" fill="#38BDF8"/>
			</svg>"""
		"trash":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="22" y="6" width="20" height="6" rx="2" fill="#CBD5E1" stroke="#0F172A" stroke-width="2.5"/>
				<rect x="10" y="12" width="44" height="7" rx="3" fill="#FB7185" stroke="#0F172A" stroke-width="3"/>
				<path d="M15 19 L18 56 H46 L49 19 Z" fill="#E2E8F0" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<line x1="25" y1="26" x2="26" y2="49" stroke="#475569" stroke-width="3.5" stroke-linecap="round"/>
				<line x1="32" y1="26" x2="32" y2="49" stroke="#475569" stroke-width="3.5" stroke-linecap="round"/>
				<line x1="39" y1="26" x2="38" y2="49" stroke="#475569" stroke-width="3.5" stroke-linecap="round"/>
			</svg>"""
		"gun":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M8 18 H52 V29 H30 L24 49 H12 L17 29 H8 Z" fill="#94A3B8" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<rect x="10" y="20" width="38" height="5" fill="#E2E8F0"/>
				<path d="M29 29 Q29 37 22 37" stroke="#FACC15" stroke-width="3" fill="none"/>
			</svg>"""
		"shield":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M32 6 L54 14 V30 C54 45 43 54 32 58 C21 54 10 45 10 30 V14 Z" fill="#38BDF8" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<path d="M32 12 V52 C40 48 48 41 48 30 V18 Z" fill="#0284C7"/>
			</svg>"""
		"hospital":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="8" y="8" width="48" height="48" rx="10" fill="#F8FAFC" stroke="#0F172A" stroke-width="3"/>
				<rect x="26" y="16" width="12" height="32" rx="2" fill="#EF4444"/>
				<rect x="16" y="26" width="32" height="12" rx="2" fill="#EF4444"/>
			</svg>"""
		"martini":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="10,12 54,12 32,36" fill="#C084FC" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<line x1="32" y1="36" x2="32" y2="54" stroke="#F8FAFC" stroke-width="4" stroke-linecap="round"/>
				<line x1="20" y1="54" x2="44" y2="54" stroke="#FACC15" stroke-width="4" stroke-linecap="round"/>
				<circle cx="36" cy="22" r="4" fill="#4ADE80"/>
			</svg>"""
		"dice":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<rect x="8" y="8" width="48" height="48" rx="10" fill="#EF4444" stroke="#0F172A" stroke-width="3"/>
				<circle cx="20" cy="20" r="4.5" fill="#F8FAFC"/>
				<circle cx="44" cy="20" r="4.5" fill="#F8FAFC"/>
				<circle cx="32" cy="32" r="4.5" fill="#FACC15"/>
				<circle cx="20" cy="44" r="4.5" fill="#F8FAFC"/>
				<circle cx="44" cy="44" r="4.5" fill="#F8FAFC"/>
			</svg>"""
		"scales":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<line x1="32" y1="8" x2="32" y2="54" stroke="#FACC15" stroke-width="4" stroke-linecap="round"/>
				<line x1="12" y1="18" x2="52" y2="18" stroke="#FACC15" stroke-width="4" stroke-linecap="round"/>
				<polygon points="14,20 6,38 22,38" fill="#38BDF8" stroke="#0F172A" stroke-width="2.5"/>
				<polygon points="50,20 42,38 58,38" fill="#38BDF8" stroke="#0F172A" stroke-width="2.5"/>
				<rect x="20" y="52" width="24" height="6" rx="2" fill="#FACC15" stroke="#0F172A" stroke-width="2"/>
			</svg>"""
		"gem":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="18,10 46,10 58,24 32,56 6,24" fill="#38BDF8" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<polygon points="24,10 40,10 46,24 32,54 18,24" fill="#7DD3FC"/>
			</svg>"""
		"trophy":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M18 10 H46 V28 C46 38 38 43 32 43 C26 43 18 38 18 28 Z" fill="#FACC15" stroke="#0F172A" stroke-width="3"/>
				<rect x="28" y="43" width="8" height="9" fill="#EAB308" stroke="#0F172A" stroke-width="2"/>
				<rect x="18" y="51" width="28" height="7" rx="2" fill="#FACC15" stroke="#0F172A" stroke-width="2.5"/>
			</svg>"""
		"gear":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<circle cx="32" cy="32" r="20" fill="#38BDF8" stroke="#0F172A" stroke-width="4"/>
				<circle cx="32" cy="32" r="9" fill="#0F172A"/>
			</svg>"""
		"speaker_on":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="10,24 22,24 36,12 36,52 22,40 10,40" fill="#4ADE80" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<path d="M44 22 C49 27 49 37 44 42" stroke="#FACC15" stroke-width="4" stroke-linecap="round" fill="none"/>
				<path d="M51 15 C59 24 59 40 51 49" stroke="#FACC15" stroke-width="4" stroke-linecap="round" fill="none"/>
			</svg>"""
		"speaker_off":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<polygon points="10,24 22,24 36,12 36,52 22,40 10,40" fill="#94A3B8" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<line x1="43" y1="23" x2="55" y2="39" stroke="#EF4444" stroke-width="4" stroke-linecap="round"/>
				<line x1="55" y1="23" x2="43" y2="39" stroke="#EF4444" stroke-width="4" stroke-linecap="round"/>
			</svg>"""
		"pin":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M32 58 C24 52 7 39 7 26 C7 13.5 18 6 32 6 C46 6 57 13.5 57 26 C57 39 40 52 32 58 Z" fill="#EF4444" stroke="#0F172A" stroke-width="3.5" stroke-linejoin="round"/>
				<path d="M15 21 C18 14 24 11 31 11" stroke="#FCA5A5" stroke-width="3.5" stroke-linecap="round" fill="none"/>
				<circle cx="32" cy="26" r="10.5" fill="#F8FAFC" stroke="#0F172A" stroke-width="3"/>
			</svg>"""
		"close_x":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<line x1="14" y1="14" x2="50" y2="50" stroke="#F8FAFC" stroke-width="7" stroke-linecap="round"/>
				<line x1="50" y1="14" x2="14" y2="50" stroke="#F8FAFC" stroke-width="7" stroke-linecap="round"/>
			</svg>"""
		"fire":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M32 6 C42 18 52 26 52 40 C52 51 43 58 32 58 C21 58 12 51 12 40 C12 29 20 20 32 6 Z" fill="#F97316" stroke="#0F172A" stroke-width="3" stroke-linejoin="round"/>
				<path d="M32 24 C37 32 42 36 42 44 C42 50 37 54 32 54 C27 54 22 50 22 44 C22 37 26 32 32 24 Z" fill="#FACC15"/>
			</svg>"""
		"snowflake":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<line x1="32" y1="8" x2="32" y2="56" stroke="#22D3EE" stroke-width="5" stroke-linecap="round"/>
				<line x1="11" y1="20" x2="53" y2="44" stroke="#22D3EE" stroke-width="5" stroke-linecap="round"/>
				<line x1="53" y1="20" x2="11" y2="44" stroke="#22D3EE" stroke-width="5" stroke-linecap="round"/>
				<circle cx="32" cy="32" r="6" fill="#E0F2FE"/>
			</svg>"""
		"check":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<circle cx="32" cy="32" r="25" fill="#16A34A" stroke="#0F172A" stroke-width="3"/>
				<polyline points="19,33 28,42 46,22" stroke="#F8FAFC" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
			</svg>"""
		"lock":
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<path d="M20 28 V18 A12 12 0 0 1 44 18 V28" stroke="#CBD5E1" stroke-width="4.5" fill="none"/>
				<rect x="14" y="28" width="36" height="28" rx="6" fill="#FACC15" stroke="#0F172A" stroke-width="3"/>
				<circle cx="32" cy="42" r="4" fill="#0F172A"/>
			</svg>"""
		_:
			return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
				<circle cx="32" cy="32" r="24" fill="#FACC15" stroke="#0F172A" stroke-width="3"/>
			</svg>"""
