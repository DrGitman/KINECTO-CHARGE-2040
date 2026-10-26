import math
from datetime import datetime
from typing import Any

from fault_engine.models import TelemetrySample


class TelemetryValidationError(ValueError):
    pass


_NUMBER_FIELDS = (
    "ambient_c",
    "blower_ma",
    "buffer_v",
    "harvested_mj",
    "battery_pct",
    "battery_temp_c",
)
_BOOL_FIELDS = ("heater_on", "blower_on", "cuff_tag_ok")
_TEXT_FIELDS = ("jacket_id", "mode", "activity")


def parse_telemetry(payload: dict[str, Any]) -> TelemetrySample:
    if not isinstance(payload, dict):
        raise TelemetryValidationError("payload must be a JSON object")

    numbers = {name: _number(payload, name) for name in _NUMBER_FIELDS}
    flags = {name: _bool(payload, name) for name in _BOOL_FIELDS}
    texts = {name: _text(payload, name) for name in _TEXT_FIELDS}

    return TelemetrySample(
        ts=_timestamp(payload),
        # The lab still calls the inside sensor body_c and sends null on a sensor fault.
        inside_c=_optional_number(payload, "body_c"),
        fault_flags=_fault_flags(payload),
        **numbers,
        **flags,
        **texts,
    )


def _require(payload: dict[str, Any], name: str) -> Any:
    if name not in payload:
        raise TelemetryValidationError(f"missing field '{name}'")
    return payload[name]


def _number(payload: dict[str, Any], name: str) -> float:
    value = _require(payload, name)
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise TelemetryValidationError(f"field '{name}' must be a finite number, got {value!r}")
    return float(value)


def _optional_number(payload: dict[str, Any], name: str) -> float | None:
    if _require(payload, name) is None:
        return None
    return _number(payload, name)


def _bool(payload: dict[str, Any], name: str) -> bool:
    value = _require(payload, name)
    if not isinstance(value, bool):
        raise TelemetryValidationError(f"field '{name}' must be a boolean, got {value!r}")
    return value


def _text(payload: dict[str, Any], name: str) -> str:
    value = _require(payload, name)
    if not isinstance(value, str) or not value.strip():
        raise TelemetryValidationError(f"field '{name}' must be a non-empty string, got {value!r}")
    return value


def _timestamp(payload: dict[str, Any]) -> datetime:
    raw = _text(payload, "ts")
    try:
        ts = datetime.fromisoformat(raw)
    except ValueError as error:
        raise TelemetryValidationError(f"field 'ts' is not ISO 8601: {raw!r}") from error
    if ts.tzinfo is None:
        raise TelemetryValidationError(f"field 'ts' must carry a timezone: {raw!r}")
    return ts


def _fault_flags(payload: dict[str, Any]) -> frozenset[str]:
    value = _require(payload, "fault_flags")
    if not isinstance(value, list) or not all(isinstance(flag, str) for flag in value):
        raise TelemetryValidationError(f"field 'fault_flags' must be a list of strings, got {value!r}")
    return frozenset(value)
