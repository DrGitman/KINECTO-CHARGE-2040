from dataclasses import replace
from datetime import datetime, timedelta

import pytest

from fault_engine.adapters import InMemoryFaultRepository, ReplayClock
from fault_engine.engine import FaultEngine
from fault_engine.models import FaultCode, FaultSource, TelemetrySample
from fault_engine.rules import build_rules
from tests.conftest import sample, series


class ListSource:
    def __init__(self, samples: list[TelemetrySample]) -> None:
        self.samples = samples

    def fetch(self, since: datetime, until: datetime) -> list[TelemetrySample]:
        return [s for s in self.samples if since < s.ts <= until]


def make_engine(config, samples, now):
    repository = InMemoryFaultRepository()
    clock = ReplayClock(now)
    engine = FaultEngine(ListSource(samples), repository, clock, build_rules(config.rules), config.window_s)
    return engine, repository, clock


def test_opens_fault_the_device_did_not_flag(config):
    samples = series(3, inside_c=None)
    engine, repository, _ = make_engine(config, samples, samples[-1].ts)

    opened = engine.tick()

    assert [f.code for f in opened] == [FaultCode.INSIDE_SENSOR_SILENT]
    assert opened[0].source is FaultSource.ENGINE
    assert repository.is_open("KC-SIM-0001", FaultCode.INSIDE_SENSOR_SILENT)


def test_skips_fault_already_flagged_by_device(config):
    samples = series(3, inside_c=None, fault_flags=frozenset({FaultCode.INSIDE_SENSOR_SILENT.value}))
    engine, repository, _ = make_engine(config, samples, samples[-1].ts)

    assert engine.tick() == []
    assert repository.open_faults == []


def test_does_not_reopen_an_open_fault(config):
    samples = series(6, inside_c=None)
    engine, repository, clock = make_engine(config, samples, samples[2].ts)

    assert len(engine.tick()) == 1
    clock.advance(config.tick_s)
    assert engine.tick() == []
    assert len(repository.open_faults) == 1


def test_ignores_samples_older_than_the_window(config):
    samples = series(3, inside_c=None)
    later = samples[-1].ts + timedelta(seconds=config.window_s + config.tick_s)
    engine, _, _ = make_engine(config, samples, later)

    assert engine.tick() == []


def test_checks_each_jacket_separately(config):
    silent = series(3, inside_c=None)
    other = [replace(s, jacket_id="KC-SIM-0002", inside_c=24.0) for s in silent]
    engine, repository, _ = make_engine(config, silent + other, silent[-1].ts)

    engine.tick()

    assert repository.is_open("KC-SIM-0001", FaultCode.INSIDE_SENSOR_SILENT)
    assert not repository.is_open("KC-SIM-0002", FaultCode.INSIDE_SENSOR_SILENT)


def test_rejects_non_positive_window(config):
    with pytest.raises(ValueError):
        FaultEngine(ListSource([]), InMemoryFaultRepository(), ReplayClock(sample(0).ts), [], window_s=0)
