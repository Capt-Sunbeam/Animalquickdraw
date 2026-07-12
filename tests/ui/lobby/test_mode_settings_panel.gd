class_name TestModeSettingsPanel
extends GdUnitTestSuite
## Slice 6 lobby panel smoke tests: preset modes render the read-only
## summary, Custom renders the full surface, and (in this non-host test
## env) every Custom control is disabled.

const PANEL: PackedScene = preload("res://ui/lobby/mode_settings_panel.tscn")


func _panel() -> ModeSettingsPanel:
	var panel: ModeSettingsPanel = auto_free(PANEL.instantiate())
	add_child(panel)
	return panel


func test_preset_mode_renders_summary_chips() -> void:
	var panel: ModeSettingsPanel = _panel()
	var s := GameSettings.new()
	s.apply_preset(SettingsDefaults.Mode.STREAMLINED)
	panel.render(s)
	assert_bool(panel._summary.visible).is_true()
	assert_bool(panel._custom_grid.visible).is_false()
	assert_str(panel._summary.text.to_lower()).contains("grid")
	assert_str(panel._summary.text.to_lower()).contains("replay: off")


func test_custom_mode_renders_full_surface() -> void:
	var panel: ModeSettingsPanel = _panel()
	var s := GameSettings.new()
	s.apply_preset(SettingsDefaults.Mode.CUSTOM)
	panel.render(s)
	assert_bool(panel._summary.visible).is_false()
	assert_bool(panel._custom_grid.visible).is_true()
	assert_float(panel._judging_spin.value).is_equal(25.0)
	assert_str(panel._kudos_hint.text).contains("Auto = 2 for 6 rounds")


func test_non_host_sees_disabled_controls() -> void:
	var panel: ModeSettingsPanel = _panel()   # Session.is_host() false here
	var s := GameSettings.new()
	s.apply_preset(SettingsDefaults.Mode.CUSTOM)
	panel.render(s)
	assert_bool(panel._reveal_option.disabled).is_true()
	assert_bool(panel._title_points_check.disabled).is_true()
	assert_bool(panel._judging_spin.editable).is_false()


func test_auto_kudos_summary_resolves_live() -> void:
	var panel: ModeSettingsPanel = _panel()
	var s := GameSettings.new()   # DEFAULT preset, AUTO kudos
	s.round_count = 10
	panel.render(s)
	assert_str(panel._summary.text).contains("auto (3)")
