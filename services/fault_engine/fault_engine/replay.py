from fault_engine.adapters import InMemoryFaultRepository, JsonlTelemetrySource, ReplayClock
from fault_engine.config import EngineConfig
from fault_engine.engine import FaultEngine
from fault_engine.models import Fault
from fault_engine.rules import build_rules


def replay(source: JsonlTelemetrySource, config: EngineConfig) -> list[Fault]:
    samples = source.samples
    if not samples:
        return []

    clock = ReplayClock(samples[0].ts)
    engine = FaultEngine(source, InMemoryFaultRepository(), clock, build_rules(config.rules), config.window_s)
    opened: list[Fault] = []
    while True:
        opened.extend(engine.tick())
        if clock.now() >= samples[-1].ts:
            return opened
        clock.advance(config.tick_s)
