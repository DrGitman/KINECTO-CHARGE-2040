import pytest

from fault_engine.config import ConfigError, parse_config


def test_repo_config_loads(config):
    assert config.tick_s == 10
    assert config.window_s == 600
    assert config.rules.heater_over_limit.cutoff_c == 42.0


def test_rejects_warm_max_at_or_above_cutoff(raw_config):
    raw_config["rules"]["heater_over_limit"]["warm_max_c"] = 42.0
    with pytest.raises(ConfigError, match="warm_max_c"):
        parse_config(raw_config)


def test_rejects_invalid_sample_count(raw_config):
    raw_config["rules"]["battery_hot"]["samples"] = 0
    with pytest.raises(ConfigError, match="rules.battery_hot.samples"):
        parse_config(raw_config)
