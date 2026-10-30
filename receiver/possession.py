
"""Optional screen-only attack/defend detector. Never reads game memory."""

import sys
import time


class PossessionDetector:
    """Classify a user-selected, visibly changing HUD region.

    F8 captures an attacking sample.
    F9 captures a defending sample.
    Unknown is returned when frames are ambiguous.
    """

    def __init__(self, roi: tuple[int, int, int, int]):
        if sys.platform != "win32":
            raise RuntimeError(
                "Auto screen detection requires Windows"
            )

        try:
            import mss
            import numpy as np
        except ImportError as exc:
            raise RuntimeError(
                "Install optional dependencies: "
                "py -m pip install mss numpy"
            ) from exc

        import ctypes

        self.np = np
        self.screen = mss.mss()

        x, y, w, h = roi
        if w < 24 or h < 16 or w > 1000 or h > 700:
            raise ValueError(
                "ROI size must be between 24x16 and 1000x700"
            )

        self.rect = {
            "left": x,
            "top": y,
            "width": w,
            "height": h,
        }

        self.win32 = ctypes.windll.user32
        self.samples: dict[str, list] = {
            "attack": [],
            "defend": [],
        }
        self.mode: str | None = None
        self.confidence = 0.0
        self.candidate: str | None = None
        self.streak = 0

        self.prev_keys = {
            0x77: False,
            0x78: False,
        }

        self.last_scan = 0.0

    def _capture(self):
        np = self.np

        frame = (
            np.asarray(self.screen.grab(self.rect))[:, :, :3]
            .astype(np.float32)
            / 255.0
        )

        features = np.zeros(
            (8, 16, 3),
            dtype=np.float32,
        )

        for y, strip in enumerate(
            np.array_split(frame, 8, axis=0)
        ):
            for x, cell in enumerate(
                np.array_split(strip, 16, axis=1)
            ):
                features[y, x] = cell.mean(
                    axis=(0, 1)
                )

        return features

    def _pressed(self, vk: int) -> bool:
        is_down = bool(
            self.win32.GetAsyncKeyState(vk) & 0x8000
        )

        just_pressed = (
            is_down and not self.prev_keys[vk]
        )

        self.prev_keys[vk] = is_down
        return just_pressed

    def poll(self) -> tuple[str | None, float]:
        now = time.monotonic()

        if now - self.last_scan < 0.20:
            return self.mode, self.confidence

        self.last_scan = now

        attack_sample = self._pressed(0x77)
        defend_sample = self._pressed(0x78)

        try:
            frame = self._capture()
        except Exception as exc:
            if self.mode is not None:
                print(
                    f"Screen capture unavailable: {exc}",
                    flush=True,
                )

            self.mode = None
            self.confidence = 0.0
            return None, 0.0

        for selected, hotkey in (
            ("attack", attack_sample),
            ("defend", defend_sample),
        ):
            if hotkey:
                bucket = self.samples[selected]
                bucket.append(frame.copy())

                if len(bucket) > 5:
                    bucket.pop(0)

                print(
                    f"{selected.upper()} sample saved "
                    f"({len(bucket)}/5). "
                    "Collect several during normal gameplay.",
                    flush=True,
                )

                self.mode = None
                self.confidence = 0.0
                self.candidate = None
                self.streak = 0

        if (
            not self.samples["attack"]
            or not self.samples["defend"]
        ):
            return None, 0.0

        np = self.np

        attack_ref = np.mean(
            self.samples["attack"],
            axis=0,
        )
        defend_ref = np.mean(
            self.samples["defend"],
            axis=0,
        )

        separation = float(
            np.abs(attack_ref - defend_ref).mean()
        )

        if separation < 0.045:
            self.mode = None
            self.confidence = 0.0
            return None, 0.0

        da = float(
            np.abs(frame - attack_ref).mean()
        )
        dd = float(
            np.abs(frame - defend_ref).mean()
        )

        candidate = (
            "attack" if da < dd else "defend"
        )

        closest, farthest = sorted((da, dd))

        margin = (
            (farthest - closest)
            / max(farthest, 0.001)
        )

        if (
            margin < 0.70
            or closest > min(
                0.16,
                separation * 0.78
            )
        ):
            self.candidate = None
            self.streak = 0
            self.mode = None
            self.confidence = 0.0
            return None, 0.0

        if candidate == self.candidate:
            self.streak += 1
        else:
            self.candidate = candidate
            self.streak = 1

        if self.streak >= 3:
            self.mode = candidate
            self.confidence = min(
                1.0,
                max(0.0, margin)
            )

        return self.mode, self.confidence
