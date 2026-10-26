import json
import logging
from datetime import datetime, timedelta
from pathlib import Path

from fault_engine.models import Fault, FaultCode, TelemetrySample
from fault_engine.telemetry_dto import TelemetryValidationError, parse_telemetry

logger = logging.getLogger("fault_engine.adapters")


class JsonlTelemetrySource:
    def __init__(self, path: Path) -> None:
        self._samples = _read_jsonl(path)

    @property
    def samples(self) -> list[TelemetrySample]:
        return list(self._samples)

    def fetch(self, since: datetime, until: datetime) -> list[TelemetrySample]:
        return [s for s in self._samples if since < s.ts <= until]


class InMemoryFaultRepository:
    def __init__(self) -> None:
        self._open: dict[tuple[str, FaultCode], Fault] = {}

    @property
    def open_faults(self) -> list[Fault]:
        return list(self._open.values())

    def is_open(self, jacket_id: str, code: FaultCode) -> bool:
        return (jacket_id, code) in self._open

    def open(self, fault: Fault) -> None:
        self._open[(fault.jacket_id, fault.code)] = fault


class ReplayClock:
    def __init__(self, start: datetime) -> None:
        self._now = start

    def now(self) -> datetime:
        return self._now

    def advance(self, seconds: float) -> None:
        self._now += timedelta(seconds=seconds)


def _read_jsonl(path: Path) -> list[TelemetrySample]:
    samples: list[TelemetrySample] = []
    with path.open(encoding="utf-8") as lines:
        for number, line in enumerate(lines, start=1):
            if not line.strip():
                continue
            try:
                samples.append(parse_telemetry(json.loads(line)))
            except (json.JSONDecodeError, TelemetryValidationError) as error:
                logger.warning("skip line file=%s line=%d error=%s", path.name, number, error)
    return sorted(samples, key=lambda s: s.ts)
