
"""Windows controller receiver (manual or experimental screen detection)."""

import argparse
import json
import secrets
import socket
import time

from .protocol import parse_report

PORT = 52777
TIMEOUT_SECONDS = 0.35
ACK_INTERVAL = 0.5


def run(
    mode: str,
    pin: str,
    port: int = PORT,
    dry_run: bool = False,
    roi: tuple[int, int, int, int] | None = None,
) -> None:
    device = None

    if not dry_run:
        from .gamepad import VirtualGamepad
        device = VirtualGamepad(mode)

    detector = None
    if roi is not None:
        from .possession import PossessionDetector
        detector = PossessionDetector(roi)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(("0.0.0.0", port))
    sock.settimeout(0.05)

    peer = None
    last_seq = None
    last_seen = 0.0
    last_ack = 0.0
    last_report = None
    detected_mode, confidence = None, 0.0

    print(f"TouchPadFC | {mode} | UDP {port}", flush=True)
    print(f"PAIRING PIN: {pin}", flush=True)
    print(
        "Get PC IP with ipconfig. "
        "iPhone and PC must use the same private network.",
        flush=True,
    )

    if dry_run:
        print("DRY RUN: no virtual controller", flush=True)

    if detector:
        print(f"SCREEN AUTO: ROI {roi}", flush=True)
        print(
            "During the match, press F8 several times while "
            "ATTACKING and F9 several times while DEFENDING.",
            flush=True,
        )
        print(
            "Choose a HUD region that visibly changes with possession. "
            "If it does not, the app stays in manual mode.",
            flush=True,
        )
    else:
        print(
            "MANUAL MODE. For experimental detection, "
            "add --roi x,y,width,height",
            flush=True,
        )

    try:
        while True:
            now = time.monotonic()

            if detector:
                detected_mode, confidence = detector.poll()

            if peer is not None and now - last_seen > TIMEOUT_SECONDS:
                if device:
                    device.reset()

                print(
                    "Controller idle: all inputs released",
                    flush=True,
                )

                peer = None
                last_seq = None
                last_report = None
                last_ack = 0.0

            try:
                payload, address = sock.recvfrom(2049)
            except socket.timeout:
                continue

            report = parse_report(payload, pin)

            if report is None:
                continue

            if peer is not None and peer != address:
                continue

            if peer is None:
                peer = address
                last_seq = None

                print(
                    f"iPhone paired: {peer[0]}:{peer[1]}",
                    flush=True,
                )

            if last_seq is not None:
                delta = (report.seq - last_seq) & 0xFFFFFFFF

                if not 0 < delta < 0x80000000:
                    continue

            last_seq = report.seq
            last_seen = time.monotonic()

            if last_seen - last_ack >= ACK_INTERVAL:
                ack = json.dumps(
                    {
                        "v": 1,
                        "type": "ack",
                        "token": pin,
                        "mode": detected_mode,
                        "confidence": round(confidence, 3),
                    },
                    separators=(",", ":"),
                ).encode()

                try:
                    sock.sendto(ack, peer)
                except OSError:
                    pass

                last_ack = last_seen

            if report != last_report:
                if device:
                    device.apply(report)
                else:
                    print(
                        f"L=({report.lx:+.2f},{report.ly:+.2f}) "
                        f"R=({report.rx:+.2f},{report.ry:+.2f}) "
                        f"buttons={sorted(report.buttons)}",
                        flush=True,
                    )

                last_report = report

    except KeyboardInterrupt:
        print("Stopping receiver", flush=True)

    finally:
        if device:
            device.reset()

        if detector:
            detector.screen.close()

        sock.close()


def parse_roi(value: str) -> tuple[int, int, int, int]:
    try:
        values = tuple(
            int(part.strip())
            for part in value.split(",")
        )
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "Use x,y,width,height"
        ) from exc

    if len(values) != 4 or values[2] <= 0 or values[3] <= 0:
        raise argparse.ArgumentTypeError(
            "Use x,y,width,height with positive size"
        )

    return values


def main() -> None:
    parser = argparse.ArgumentParser(
        description="TouchPadFC Windows receiver"
    )

    parser.add_argument(
        "--mode",
        choices=["xbox", "ds4"],
        default="xbox",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=PORT,
    )
    parser.add_argument(
        "--pin",
        help="Optional six-digit pairing PIN",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
    )
    parser.add_argument(
        "--roi",
        type=parse_roi,
        help=(
            "Optional screen region x,y,width,height "
            "for experimental detection"
        ),
    )

    args = parser.parse_args()
    pin = args.pin or f"{secrets.randbelow(1_000_000):06d}"

    if len(pin) != 6 or not pin.isascii() or not pin.isdecimal():
        parser.error("--pin must be six ASCII digits")

    run(
        args.mode,
        pin,
        args.port,
        args.dry_run,
        args.roi,
    )


if __name__ == "__main__":
    main()
