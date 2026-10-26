import pytest

from fault_engine.telemetry_dto import TelemetryValidationError, parse_telemetry

UNITY_PAYLOAD = {
    "jacket_id": "KC-SIM-0001",
    "ts": "2026-10-15T10:00:00.1234567Z",
    "is_virtual": True,
    "body_c": None,
    "ambient_c": 18.0,
    "mode": "Warm",
    "heater_on": False,
    "blower_on": False,
    "blower_ma": 0,
    "buffer_v": 3.4,
    "harvested_mj": 1.2,
    "battery_pct": 92.0,
    "battery_temp_c": 33.0,
    "cuff_tag_ok": True,
    "activity": "standing",
    "fault_flags": ["heater_over_limit"],
}


def test_parses_unity_payload_with_silent_inside_sensor():
    sample = parse_telemetry(UNITY_PAYLOAD)
    assert sample.inside_c is None
    assert sample.ts.tzinfo is not None
    assert sample.fault_flags == frozenset({"heater_over_limit"})


@pytest.mark.parametrize(
    "changes",
    [
        {"battery_temp_c": float("nan")},
        {"heater_on": "yes"},
        {"ts": "2026-10-15T10:00:00"},
        {"fault_flags": "heater_over_limit"},
        {"jacket_id": " "},
    ],
)
def test_rejects_invalid_fields(changes):
    with pytest.raises(TelemetryValidationError):
        parse_telemetry({**UNITY_PAYLOAD, **changes})


def test_rejects_missing_field():
    payload = dict(UNITY_PAYLOAD)
    del payload["blower_ma"]
    with pytest.raises(TelemetryValidationError, match="blower_ma"):
        parse_telemetry(payload)
