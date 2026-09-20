extends GdUnitTestSuite


func test_parses_and_compares() -> void:
	assert_bool(Semver.parse("1.2.3").valid).is_true()
	assert_bool(Semver.parse("not.a.version").valid).is_false()
	assert_int(Semver.parse("1.2.3").compare(Semver.parse("1.10.0"))).is_equal(-1)
	assert_int(Semver.parse("2.0.0").compare(Semver.parse("2.0.0"))).is_equal(0)


func test_prerelease_sorts_below_its_release() -> void:
	assert_int(Semver.parse("1.0.0-beta").compare(Semver.parse("1.0.0"))).is_equal(-1)


func test_ranges() -> void:
	assert_bool(Semver.satisfies("1.5.0", ">=1.0.0 <2.0.0")).is_true()
	assert_bool(Semver.satisfies("2.0.0", ">=1.0.0 <2.0.0")).is_false()
	assert_bool(Semver.satisfies("1.2.9", "~1.2.0")).is_true()
	assert_bool(Semver.satisfies("1.3.0", "~1.2.0")).is_false()
	assert_bool(Semver.satisfies("1.9.0", "^1.2.0")).is_true()
	assert_bool(Semver.satisfies("2.0.0", "^1.2.0")).is_false()
	assert_bool(Semver.satisfies("9.9.9", "*")).is_true()


func test_zero_major_treats_minor_as_breaking() -> void:
	# The usual convention: before 1.0 anything may break, so ^0.4.0 does not accept 0.5.
	assert_bool(Semver.satisfies("0.4.7", "^0.4.0")).is_true()
	assert_bool(Semver.satisfies("0.5.0", "^0.4.0")).is_false()


func test_an_unparseable_range_is_unsatisfied_not_permissive() -> void:
	# A typo must not silently widen a bound into "anything goes".
	assert_bool(Semver.satisfies("1.0.0", ">=oops")).is_false()
