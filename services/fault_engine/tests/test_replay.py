from fault_engine.adapters import JsonlTelemetrySource
from fault_engine.models import FaultCode
from fault_engine.replay import replay
from tests.conftest import SERVICE_DIR


def test_heater_over_limit_replay_opens_only_the_unflagged_fault(config):
    source = JsonlTelemetrySource(SERVICE_DIR / "samples" / "heater_over_limit.jsonl")

    opened = replay(source, config)

    # The lab flags heater_over_limit itself but never flags the sensor it cuts at 40 °C.
    assert [f.code for f in opened] == [FaultCode.INSIDE_SENSOR_SILENT]


def test_skips_invalid_lines(tmp_path, config):
    telemetry = tmp_path / "broken.jsonl"
    telemetry.write_text('not json\n{"jacket_id": "KC-SIM-0001"}\n', encoding="utf-8")

    source = JsonlTelemetrySource(telemetry)

    assert source.samples == []
    assert replay(source, config) == []
