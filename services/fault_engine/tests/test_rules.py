from fault_engine.models import FaultCode
from fault_engine.rules import (
    battery_hot,
    blower_current_spike,
    buffer_not_charging,
    cuff_tag_unreadable,
    heater_over_limit,
    inside_sensor_silent,
)
from tests.conftest import sample, series


def test_inside_sensor_silent_needs_three_null_samples_in_a_row(config):
    rule_config = config.rules.inside_sensor_silent
    broken = series(2, inside_c=None) + [sample(2)] + series(2, start_index=3, inside_c=None)
    assert inside_sensor_silent(broken, rule_config) is None

    detection = inside_sensor_silent(series(3, inside_c=None), rule_config)
    assert detection.code is FaultCode.INSIDE_SENSOR_SILENT
    assert detection.detected_at == sample(2).ts


def test_heater_over_limit_fires_on_one_sample_at_cutoff(config):
    window = series(3) + [sample(3, inside_c=42.0)]
    detection = heater_over_limit(window, config.rules.heater_over_limit)
    assert detection.code is FaultCode.HEATER_OVER_LIMIT
    assert detection.detected_at == sample(3).ts


def test_heater_over_limit_fires_when_heater_stays_on_above_warm_max(config):
    rule_config = config.rules.heater_over_limit
    hot = dict(heater_on=True, inside_c=31.0)
    assert heater_over_limit(series(12, **hot), rule_config) is None  # 55 s

    detection = heater_over_limit(series(13, **hot), rule_config)  # 60 s
    assert detection.detected_at == sample(12).ts


def test_heater_over_limit_ignores_warm_inside_with_heater_off(config):
    assert heater_over_limit(series(20, inside_c=35.0), config.rules.heater_over_limit) is None


def test_blower_current_spike_needs_two_samples_above_limit(config):
    rule_config = config.rules.blower_current_spike
    assert blower_current_spike([sample(0, blower_ma=950.0), sample(1, blower_ma=120.0)], rule_config) is None

    detection = blower_current_spike(series(2, blower_on=True, blower_ma=950.0), rule_config)
    assert detection.code is FaultCode.BLOWER_CURRENT_SPIKE
    assert "950 mA" in detection.evidence


def test_buffer_not_charging_while_walking_without_gain(config):
    rule_config = config.rules.buffer_not_charging
    assert buffer_not_charging(series(61, activity="standing"), rule_config) is None

    detection = buffer_not_charging(series(61, activity="walk"), rule_config)  # 300 s
    assert detection.code is FaultCode.BUFFER_NOT_CHARGING
    assert detection.detected_at == sample(60).ts


def test_buffer_not_charging_restarts_after_a_harvest_gain(config):
    window = series(30, activity="walk") + series(31, start_index=30, activity="walk", harvested_mj=1.5)
    assert buffer_not_charging(window, config.rules.buffer_not_charging) is None


def test_battery_hot_needs_two_samples_at_limit(config):
    rule_config = config.rules.battery_hot
    assert battery_hot(series(1, battery_temp_c=52.0) + [sample(1)], rule_config) is None

    detection = battery_hot(series(2, battery_temp_c=45.0), rule_config)
    assert detection.code is FaultCode.BATTERY_HOT


def test_cuff_tag_unreadable_needs_three_samples(config):
    rule_config = config.rules.cuff_tag_unreadable
    assert cuff_tag_unreadable(series(2, cuff_tag_ok=False), rule_config) is None
    assert cuff_tag_unreadable(series(3, cuff_tag_ok=False), rule_config).code is FaultCode.CUFF_TAG_UNREADABLE


def test_normal_window_triggers_no_rule(config):
    window = series(120)
    rules = config.rules
    assert inside_sensor_silent(window, rules.inside_sensor_silent) is None
    assert heater_over_limit(window, rules.heater_over_limit) is None
    assert blower_current_spike(window, rules.blower_current_spike) is None
    assert buffer_not_charging(window, rules.buffer_not_charging) is None
    assert battery_hot(window, rules.battery_hot) is None
    assert cuff_tag_unreadable(window, rules.cuff_tag_unreadable) is None
