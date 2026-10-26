from datetime import datetime
from typing import Protocol

from fault_engine.models import Fault, FaultCode, TelemetrySample


class TelemetrySource(Protocol):
    def fetch(self, since: datetime, until: datetime) -> list[TelemetrySample]: ...


class FaultRepository(Protocol):
    def is_open(self, jacket_id: str, code: FaultCode) -> bool: ...

    def open(self, fault: Fault) -> None: ...


class Clock(Protocol):
    def now(self) -> datetime: ...
