import json
from dataclasses import replace
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

from fault_engine.config import EngineConfig, load_config
from fault_engine.models import TelemetrySample

SERVICE_DIR = Path(__file__).resolve().parent.parent
START = datetime(2026, 10, 15, 10, 0, tzinfo=timezone.utc)
SAMPLE_PERIOD_S = 5

NORMAL_SAMPLE = TelemetrySample(
    jacket_id="KC-SIM-0001",
    ts=START,
    inside_c=24.0,
    ambient_c=18.0,
    mode="Auto",
    heater_on=False,
    blower_on=False,
    blower_ma=0.0,
    buffer_v=3.4,
    harvested_mj=1.2,
    battery_pct=92.0,
    battery_temp_c=29.0,
    cuff_tag_ok=True,
    activity="standing",
    fault_flags=frozenset(),
)


def sample(index: int, **changes) -> TelemetrySample:
    return replace(NORMAL_SAMPLE, ts=START + timedelta(seconds=index * SAMPLE_PERIOD_S), **changes)


def series(count: int, start_index: int = 0, **changes) -> list[TelemetrySample]:
    return [sample(start_index + i, **changes) for i in range(count)]


@pytest.fixture
def config() -> EngineConfig:
    return load_config(SERVICE_DIR / "rules_config.json")


@pytest.fixture
def raw_config() -> dict:
    return json.loads((SERVICE_DIR / "rules_config.json").read_text(encoding="utf-8"))
