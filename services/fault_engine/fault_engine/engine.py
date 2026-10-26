import logging
from collections import defaultdict
from collections.abc import Sequence
from datetime import timedelta

from fault_engine.models import Detection, Fault, TelemetrySample
from fault_engine.ports import Clock, FaultRepository, TelemetrySource
from fault_engine.rules import Rule

logger = logging.getLogger("fault_engine.engine")


class FaultEngine:
    def __init__(
        self,
        source: TelemetrySource,
        repository: FaultRepository,
        clock: Clock,
        rules: Sequence[Rule],
        window_s: float,
    ) -> None:
        if window_s <= 0:
            raise ValueError(f"window_s must be positive, got {window_s}")
        self._source = source
        self._repository = repository
        self._clock = clock
        self._rules = list(rules)
        self._window = timedelta(seconds=window_s)

    def tick(self) -> list[Fault]:
        now = self._clock.now()
        samples = self._source.fetch(since=now - self._window, until=now)
        opened: list[Fault] = []
        for jacket_id, window in _by_jacket(samples).items():
            opened.extend(self._check_jacket(jacket_id, window))
        return opened

    def _check_jacket(self, jacket_id: str, window: list[TelemetrySample]) -> list[Fault]:
        device_flags = frozenset().union(*(s.fault_flags for s in window))
        opened: list[Fault] = []
        for rule in self._rules:
            detection = rule(window)
            if detection is None or not self._should_open(jacket_id, detection, device_flags):
                continue
            fault = Fault(
                jacket_id=jacket_id,
                code=detection.code,
                detected_at=detection.detected_at,
                opened_at=self._clock.now(),
                evidence=detection.evidence,
            )
            self._repository.open(fault)
            logger.warning("opened fault jacket=%s code=%s evidence=%s", jacket_id, fault.code, fault.evidence)
            opened.append(fault)
        return opened

    def _should_open(self, jacket_id: str, detection: Detection, device_flags: frozenset[str]) -> bool:
        if detection.code in device_flags:
            logger.debug("skip jacket=%s code=%s reason=flagged_by_device", jacket_id, detection.code)
            return False
        if self._repository.is_open(jacket_id, detection.code):
            logger.debug("skip jacket=%s code=%s reason=already_open", jacket_id, detection.code)
            return False
        return True


def _by_jacket(samples: Sequence[TelemetrySample]) -> dict[str, list[TelemetrySample]]:
    grouped: dict[str, list[TelemetrySample]] = defaultdict(list)
    for sample in sorted(samples, key=lambda s: s.ts):
        grouped[sample.jacket_id].append(sample)
    return grouped
