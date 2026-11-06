class_name Money

# Currency & profit/loss string formatting helpers for Dope Wars: Omaha Metro Edition.


static func format(amount: int) -> String:
	var sign_prefix := "-" if amount < 0 else ""
	var abs_val: int = absi(amount)
	if abs_val >= 1000000000:
		return "%s$%.2fB" % [sign_prefix, float(abs_val) / 1000000000.0]
	if abs_val >= 1000000:
		return "%s$%.2fM" % [sign_prefix, float(abs_val) / 1000000.0]
	return "%s$%s" % [sign_prefix, _add_commas(abs_val)]


static func format_short(amount: int) -> String:
	var sign_prefix := "-" if amount < 0 else ""
	var abs_val: int = absi(amount)
	if abs_val >= 1000000000:
		return "%s$%.1fB" % [sign_prefix, float(abs_val) / 1000000000.0]
	if abs_val >= 1000000:
		return "%s$%.2fM" % [sign_prefix, float(abs_val) / 1000000.0]
	if abs_val >= 10000:
		return "%s$%.1fK" % [sign_prefix, float(abs_val) / 1000.0]
	return "%s$%s" % [sign_prefix, _add_commas(abs_val)]


static func format_pl(amount: int) -> String:
	if amount > 0:
		return "+" + format_short(amount)
	if amount < 0:
		return format_short(amount)
	return "$0"


static func _add_commas(val: int) -> String:
	var s := str(absi(val))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return out
