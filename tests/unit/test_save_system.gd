extends GdUnitTestSuite

## A save is somebody's twenty hours. Never silently drop data; never hard-fail.

const SLOT: String = "test_slot"


func after_test() -> void:
	DirAccess.remove_absolute(SaveSystem.save_path(SLOT))


func test_round_trip() -> void:
	var state: Dictionary = {"day": 12, "currencies": {"money": 480.5}}
	assert_bool(SaveSystem.write(SLOT, state, {"base": "0.1.0"})).is_true()
	var result: SaveSystem.LoadResult = SaveSystem.read(SLOT, {"base": "0.1.0"})
	assert_bool(result.ok).is_true()
	assert_int(int((result.state["currencies"] as Dictionary)["money"])).is_equal(480)
	assert_bool(result.degraded).is_false()


func test_a_version_1_save_is_migrated_rather_than_refused() -> void:
	var path: String = "user://v1_save.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	(
		file
		. store_string(
			(
				JSON
				. stringify(
					{
						"version": 1,
						"mods": {"base": "0.1.0"},
						"state": {"cash": 120.0, "reputation": 3.0, "day": 4},
					}
				)
			)
		)
	)
	file.close()

	var result: SaveSystem.LoadResult = SaveSystem.read_from(path, {"base": "0.1.0"})
	assert_bool(result.ok).is_true()
	assert_int(result.from_version).is_equal(1)
	assert_array(result.migrations_applied).contains(["001_to_002"])
	var currencies: Dictionary = result.state["currencies"]
	assert_float(float(currencies["money"])).is_equal_approx(120.0, 0.001)
	assert_float(float(currencies["reputation"])).is_equal_approx(3.0, 0.001)
	assert_bool(result.state.has("cash")).is_false()
	assert_int(int(result.state["day"])).is_equal(4)
	DirAccess.remove_absolute(path)


func test_a_missing_mod_degrades_rather_than_fails() -> void:
	SaveSystem.write(SLOT, {"day": 1}, {"base": "0.1.0", "someones_mod": "2.1.0"})
	var result: SaveSystem.LoadResult = SaveSystem.read(SLOT, {"base": "0.1.0"})
	assert_bool(result.ok).is_true()
	assert_bool(result.degraded).is_true()
	assert_bool(result.missing_mods.has("someones_mod")).is_true()
	assert_str(result.describe()).contains("someones_mod")


func test_a_save_from_the_future_is_refused_with_a_reason() -> void:
	var path: String = "user://future_save.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 999, "mods": {}, "state": {}}))
	file.close()
	var result: SaveSystem.LoadResult = SaveSystem.read_from(path, {})
	assert_bool(result.ok).is_false()
	assert_str(result.error).contains("999")
	DirAccess.remove_absolute(path)


func test_stripping_mod_content_removes_only_that_mods_ids() -> void:
	var state: Dictionary = {
		"shelf": ["base:cold_brew_16oz", "gone_mod:ghost_item"],
		"case": {"slot_1": "gone_mod:ghost_card", "slot_2": "base:graded_single_meridian"},
	}
	var stripped: Dictionary = SaveSystem.strip_mod_content(state, PackedStringArray(["gone_mod"]))
	assert_array(stripped["shelf"]).is_equal(["base:cold_brew_16oz"])
	assert_bool((stripped["case"] as Dictionary).has("slot_1")).is_false()
	assert_bool((stripped["case"] as Dictionary).has("slot_2")).is_true()


func test_a_corrupt_save_reports_the_line_rather_than_crashing() -> void:
	var path: String = "user://corrupt_save.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()
	var result: SaveSystem.LoadResult = SaveSystem.read_from(path, {})
	assert_bool(result.ok).is_false()
	assert_str(result.error).contains("line")
	DirAccess.remove_absolute(path)
