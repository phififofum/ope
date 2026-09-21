# Proves the test harness itself runs before anything depends on it.
extends GdUnitTestSuite


func test_harness_runs() -> void:
	assert_int(2 + 2).is_equal(4)


func test_project_is_poggywoggy() -> void:
	var name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	assert_str(name).is_equal("PoggyWoggy")
