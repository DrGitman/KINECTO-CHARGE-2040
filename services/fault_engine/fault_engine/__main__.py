import argparse
import logging
import sys
from pathlib import Path

from fault_engine.adapters import JsonlTelemetrySource
from fault_engine.config import ConfigError, load_config
from fault_engine.replay import replay

DEFAULT_CONFIG = Path(__file__).resolve().parent.parent / "rules_config.json"
EXIT_USAGE_ERROR = 2


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s %(message)s",
    )
    try:
        config = load_config(args.config)
        source = JsonlTelemetrySource(args.telemetry)
    except (ConfigError, OSError) as error:
        logging.getLogger("fault_engine").error("cannot start replay: %s", error)
        return EXIT_USAGE_ERROR

    opened = replay(source, config)
    print(f"SIMULATED replay of {args.telemetry.name}: {len(opened)} fault(s) opened by the engine")
    for fault in opened:
        print(f"  {fault.detected_at.isoformat()}  {fault.jacket_id}  {fault.code}  ({fault.evidence})")
    return 0


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="fault_engine", description="Kinecto Care fault engine")
    commands = parser.add_subparsers(dest="command", required=True)
    replay_cmd = commands.add_parser("replay", help="run the engine over a recorded telemetry file (JSONL)")
    replay_cmd.add_argument("telemetry", type=Path)
    replay_cmd.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    replay_cmd.add_argument("--verbose", action="store_true", help="also log skipped detections")
    return parser.parse_args(argv)


if __name__ == "__main__":
    sys.exit(main())
