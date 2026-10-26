from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class FaultCode(StrEnum):
    # Same IDs as the Virtual Lab fault_flags, so device and engine faults match.
    INSIDE_SENSOR_SILENT = "body_sensor_offline"
    HEATER_OVER_LIMIT = "heater_over_limit"
    BLOWER_CURRENT_SPIKE = "blower_current_spike"
    BUFFER_NOT_CHARGING = "buffer_not_charging"
    BATTERY_HOT = "battery_hot"
    CUFF_TAG_UNREADABLE = "cuff_tag_unreadable"


class FaultSource(StrEnum):
    ENGINE = "engine"


@dataclass(frozen=True)
class TelemetrySample:
    jacket_id: str
    ts: datetime
    inside_c: float | None
    ambient_c: float
    mode: str
    heater_on: bool
    blower_on: bool
    blower_ma: float
    buffer_v: float
    harvested_mj: float
    battery_pct: float
    battery_temp_c: float
    cuff_tag_ok: bool
    activity: str
    fault_flags: frozenset[str]


@dataclass(frozen=True)
class Detection:
    code: FaultCode
    detected_at: datetime
    evidence: str


@dataclass(frozen=True)
class Fault:
    jacket_id: str
    code: FaultCode
    detected_at: datetime
    opened_at: datetime
    evidence: str
    source: FaultSource = FaultSource.ENGINE
