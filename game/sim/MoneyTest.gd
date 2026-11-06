extends SceneTree

# Gate 1: MoneyTest — verifies currency and profit/loss formatting.

var _failures := 0


func _init() -> void:
	_assert_eq(Money.format(0), "$0", "format zero")
	_assert_eq(Money.format(2000), "$2,000", "format thousands")
	_assert_eq(Money.format(-3500), "-$3,500", "format negative thousands")
	_assert_eq(Money.format(1750000), "$1.75M", "format millions")
	_assert_eq(Money.format_short(88400), "$88.4K", "format_short tens of thousands")
	_assert_eq(Money.format_pl(128000), "+$128.0K", "format_pl positive")
	_assert_eq(Money.format_pl(-450), "-$450", "format_pl negative")
	_assert_eq(Money.format_pl(0), "$0", "format_pl zero")

	if _failures == 0:
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		printerr("%d CHECK(S) FAILED" % _failures)
		quit(1)


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAIL [%s]: expected '%s', got '%s'" % [label, str(expected), str(actual)])
		_failures += 1
