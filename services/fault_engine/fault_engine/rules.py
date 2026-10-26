from collections.abc import Callable, Sequence
from functools import partial

from fault_engine.config import (
    BatteryHotConfig,
    BlowerCurrentSpikeConfig,
    BufferNotChargingConfig,
    CuffTagUnreadableConfig,
    HeaterOverLimitConfig,
    InsideSensorSilentConfig,
    RulesConfig,
)
from fault_engine.models import Detection, FaultCode, TelemetrySample

Rule = Callable[[Sequence[TelemetrySample]], Detection | None]
Run = list[TelemetrySample]


def build_rules(config: RulesConfig) -> list[Rule]:
    return [
        partial(inside_sensor_silent, config=config.inside_sensor_silent),
        partial(heater_over_limit, config=config.heater_over_limit),
        partial(blower_current_spike, config=config.blower_current_spike),
        partial(buffer_not_charging, config=config.buffer_not_charging),
        partial(battery_hot, config=config.battery_hot),
        partial(cuff_tag_unreadable, config=config.cuff_tag_unreadable),
    ]


def inside_sensor_silent(samples: Sequence[TelemetrySample], config: InsideSensorSilentConfig) -> Detection | None:
    run = _first_run(samples, lambda s: s.inside_c is None, _at_least(config.null_samples))
    if run is None:
        return None
    return Detection(FaultCode.INSIDE_SENSOR_SILENT, run[-1].ts, f"inside sensor silent for {len(run)} samples")


def heater_over_limit(samples: Sequence[TelemetrySample], config: HeaterOverLimitConfig) -> Detection | None:
    for sample in samples:
        if sample.inside_c is not None and sample.inside_c >= config.cutoff_c:
            return Detection(
                FaultCode.HEATER_OVER_LIMIT,
                sample.ts,
                f"inside {sample.inside_c:.1f} °C reached the {config.cutoff_c:.1f} °C cutoff",
            )

    run = _first_run(
        samples,
        lambda s: s.heater_on and s.inside_c is not None and s.inside_c > config.warm_max_c,
        _lasting(config.over_warm_max_s),
    )
    if run is None:
        return None
    return Detection(
        FaultCode.HEATER_OVER_LIMIT,
        run[-1].ts,
        f"heater on above {config.warm_max_c:.1f} °C for {_duration_s(run):.0f} s",
    )


def blower_current_spike(samples: Sequence[TelemetrySample], config: BlowerCurrentSpikeConfig) -> Detection | None:
    run = _first_run(samples, lambda s: s.blower_ma > config.max_ma, _at_least(config.samples))
    if run is None:
        return None
    peak_ma = max(s.blower_ma for s in run)
    return Detection(FaultCode.BLOWER_CURRENT_SPIKE, run[-1].ts, f"blower draw up to {peak_ma:.0f} mA")


def buffer_not_charging(samples: Sequence[TelemetrySample], config: BufferNotChargingConfig) -> Detection | None:
    run: Run = []
    for sample in samples:
        if sample.activity not in config.moving_activities:
            run = []
            continue
        # Any gain in harvested energy proves the buffer charges, so the count restarts there.
        if run and sample.harvested_mj > run[0].harvested_mj:
            run = []
        run.append(sample)
        if _duration_s(run) >= config.min_moving_s:
            return Detection(
                FaultCode.BUFFER_NOT_CHARGING,
                sample.ts,
                f"no harvest gain after {_duration_s(run):.0f} s of movement",
            )
    return None


def battery_hot(samples: Sequence[TelemetrySample], config: BatteryHotConfig) -> Detection | None:
    run = _first_run(samples, lambda s: s.battery_temp_c >= config.max_c, _at_least(config.samples))
    if run is None:
        return None
    peak_c = max(s.battery_temp_c for s in run)
    return Detection(FaultCode.BATTERY_HOT, run[-1].ts, f"thermal battery up to {peak_c:.1f} °C")


def cuff_tag_unreadable(samples: Sequence[TelemetrySample], config: CuffTagUnreadableConfig) -> Detection | None:
    run = _first_run(samples, lambda s: not s.cuff_tag_ok, _at_least(config.samples))
    if run is None:
        return None
    return Detection(FaultCode.CUFF_TAG_UNREADABLE, run[-1].ts, f"cuff tag unreadable for {len(run)} samples")


def _first_run(
    samples: Sequence[TelemetrySample],
    matches: Callable[[TelemetrySample], bool],
    is_complete: Callable[[Run], bool],
) -> Run | None:
    run: Run = []
    for sample in samples:
        if not matches(sample):
            run = []
            continue
        run.append(sample)
        if is_complete(run):
            return run
    return None


def _at_least(count: int) -> Callable[[Run], bool]:
    return lambda run: len(run) >= count


def _lasting(seconds: float) -> Callable[[Run], bool]:
    return lambda run: _duration_s(run) >= seconds


def _duration_s(run: Run) -> float:
    return (run[-1].ts - run[0].ts).total_seconds()
