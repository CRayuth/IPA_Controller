"""Validate input reports received from the iPhone."""

import json
import math
from dataclasses import dataclass

ALLOWED_BUTTONS = frozenset({
    "cross", "circle", "square", "triangle", "l1", "r1", "l2", "r2",
    "l3", "r3", "share", "options", "ps", "touchpad",
    "d_up", "d_down", "d_left", "d_right",
})


@dataclass(frozen=True)
class InputReport:
    seq: int
    lx: float
    ly: float
    rx: float
    ry: float
    buttons: frozenset[str]


def parse_report(raw: bytes, expected_pin: str) -> InputReport | None:
    """Return None for malformed, unauthenticated or out-of-range reports."""
    if len(raw) > 2048:
        return None
    try:
        obj = json.loads(raw.decode("utf-8"))
        if not isinstance(obj, dict) or obj.get("v") != 1:
            return None
        import hmac
        token = obj.get("token")
        if not isinstance(token, str) or not hmac.compare_digest(token, expected_pin):
            return None
        seq = obj.get("seq")
        if type(seq) is not int or not 0 <= seq < 2**32:
            return None
        buttons = obj.get("buttons")
        if (not isinstance(buttons, list)
                or not all(isinstance(v, str) for v in buttons)
                or len(buttons) > len(ALLOWED_BUTTONS)
                or not set(buttons) <= ALLOWED_BUTTONS):
            return None
        axes = []
        for field in ("lx", "ly", "rx", "ry"):
            value = obj.get(field)
            if type(value) not in (int, float) or not math.isfinite(value) or not -1 <= value <= 1:
                return None
            axes.append(float(value))
        return InputReport(seq, *axes, frozenset(buttons))
    except (ValueError, UnicodeError, TypeError, OverflowError):
        return None
