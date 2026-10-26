import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class ConfigError(ValueError):
    pass


@dataclass(frozen=True)
class InsideSensorSilentConfig:
    null_samples: int


@dataclass(frozen=True)
class HeaterOverLimitConfig:
    cutoff_c: float
    warm_max_c: float
    over_warm_max_s: float


@dataclass(frozen=True)
class BlowerCurrentSpikeConfig:
    max_ma: float
    samples: int


@dataclass(frozen=True)
class BufferNotChargingConfig:
    moving_activities: frozenset[str]
    min_moving_s: float


@dataclass(frozen=True)
class BatteryHotConfig:
    max_c: float
    samples: int


@dataclass(frozen=True)
class CuffTagUnreadableConfig:
    samples: int


@dataclass(frozen=True)
class RulesConfig:
    inside_sensor_silent: InsideSensorSilentConfig
    heater_over_limit: HeaterOverLimitConfig
    blower_current_spike: BlowerCurrentSpikeConfig
    buffer_not_charging: BufferNotChargingConfig
    battery_hot: BatteryHotConfig
    cuff_tag_unreadable: CuffTagUnreadableConfig


@dataclass(frozen=True)
class EngineConfig:
    tick_s: float
    window_s: float
    rules: RulesConfig


def load_config(path: Path) -> EngineConfig:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ConfigError(f"cannot read config {path}: {error}") from error
    return parse_config(raw)


def parse_config(raw: Any) -> EngineConfig:
    root = _Section(raw, "config")
    rules = root.section("rules")
    silent = rules.section("inside_sensor_silent")
    heater = rules.section("heater_over_limit")
    blower = rules.section("blower_current_spike")
    buffer = rules.section("buffer_not_charging")
    battery = rules.section("battery_hot")
    cuff = rules.section("cuff_tag_unreadable")

    config = EngineConfig(
        tick_s=root.positive("tick_s"),
        window_s=root.positive("window_s"),
        rules=RulesConfig(
            inside_sensor_silent=InsideSensorSilentConfig(null_samples=silent.count("null_samples")),
            heater_over_limit=HeaterOverLimitConfig(
                cutoff_c=heater.positive("cutoff_c"),
                warm_max_c=heater.positive("warm_max_c"),
                over_warm_max_s=heater.positive("over_warm_max_s"),
            ),
            blower_current_spike=BlowerCurrentSpikeConfig(max_ma=blower.positive("max_ma"), samples=blower.count("samples")),
            buffer_not_charging=BufferNotChargingConfig(
                moving_activities=buffer.names("moving_activities"),
                min_moving_s=buffer.positive("min_moving_s"),
            ),
            battery_hot=BatteryHotConfig(max_c=battery.positive("max_c"), samples=battery.count("samples")),
            cuff_tag_unreadable=CuffTagUnreadableConfig(samples=cuff.count("samples")),
        ),
    )
    if config.rules.heater_over_limit.warm_max_c >= config.rules.heater_over_limit.cutoff_c:
        raise ConfigError("rules.heater_over_limit.warm_max_c must stay below cutoff_c")
    return config


class _Section:
    def __init__(self, raw: Any, path: str) -> None:
        if not isinstance(raw, dict):
            raise ConfigError(f"'{path}' must be an object")
        self._raw = raw
        self._path = path

    def section(self, name: str) -> "_Section":
        return _Section(self._raw.get(name), f"{self._path}.{name}")

    def positive(self, name: str) -> float:
        value = self._raw.get(name)
        if isinstance(value, bool) or not isinstance(value, (int, float)) or value <= 0:
            raise ConfigError(f"'{self._path}.{name}' must be a positive number, got {value!r}")
        return float(value)

    def count(self, name: str) -> int:
        value = self._raw.get(name)
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ConfigError(f"'{self._path}.{name}' must be an integer >= 1, got {value!r}")
        return value

    def names(self, name: str) -> frozenset[str]:
        value = self._raw.get(name)
        if not isinstance(value, list) or not value or not all(isinstance(item, str) and item for item in value):
            raise ConfigError(f"'{self._path}.{name}' must be a non-empty list of strings, got {value!r}")
        return frozenset(value)
