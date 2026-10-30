"""Translate normalized reports into vgamepad controller reports."""

from .protocol import InputReport


class VirtualGamepad:
    def __init__(self, mode: str = "ds4") -> None:
        import vgamepad as vg
        self.vg = vg
        self.mode = mode
        self.pad = vg.VDS4Gamepad() if mode == "ds4" else vg.VX360Gamepad()
        self.reset()

    def apply(self, report: InputReport) -> None:
        vg, pad, pressed = self.vg, self.pad, report.buttons
        pad.reset()
        if self.mode == "ds4":
            buttons = {
                "cross": vg.DS4_BUTTONS.DS4_BUTTON_CROSS,
                "circle": vg.DS4_BUTTONS.DS4_BUTTON_CIRCLE,
                "square": vg.DS4_BUTTONS.DS4_BUTTON_SQUARE,
                "triangle": vg.DS4_BUTTONS.DS4_BUTTON_TRIANGLE,
                "l1": vg.DS4_BUTTONS.DS4_BUTTON_SHOULDER_LEFT,
                "r1": vg.DS4_BUTTONS.DS4_BUTTON_SHOULDER_RIGHT,
                "l2": vg.DS4_BUTTONS.DS4_BUTTON_TRIGGER_LEFT,
                "r2": vg.DS4_BUTTONS.DS4_BUTTON_TRIGGER_RIGHT,
                "l3": vg.DS4_BUTTONS.DS4_BUTTON_THUMB_LEFT,
                "r3": vg.DS4_BUTTONS.DS4_BUTTON_THUMB_RIGHT,
                "share": vg.DS4_BUTTONS.DS4_BUTTON_SHARE,
                "options": vg.DS4_BUTTONS.DS4_BUTTON_OPTIONS,
            }
            for key, button in buttons.items():
                if key in pressed:
                    pad.press_button(button=button)
            if "ps" in pressed:
                pad.press_special_button(special_button=vg.DS4_SPECIAL_BUTTONS.DS4_SPECIAL_BUTTON_PS)
            if "touchpad" in pressed:
                pad.press_special_button(special_button=vg.DS4_SPECIAL_BUTTONS.DS4_SPECIAL_BUTTON_TOUCHPAD)
            north, south = "d_up" in pressed, "d_down" in pressed
            west, east = "d_left" in pressed, "d_right" in pressed
            y = int(north) - int(south)
            x = int(east) - int(west)
            directions = {
                (0, 0): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NONE,
                (0, 1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTH,
                (1, 1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTHEAST,
                (1, 0): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_EAST,
                (1, -1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTHEAST,
                (0, -1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTH,
                (-1, -1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_SOUTHWEST,
                (-1, 0): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_WEST,
                (-1, 1): vg.DS4_DPAD_DIRECTIONS.DS4_BUTTON_DPAD_NORTHWEST,
            }
            pad.directional_pad(direction=directions[(x, y)])
            # DS4 Y-axis convention is opposite the X360 convention in vgamepad.
            pad.left_joystick_float(x_value_float=report.lx, y_value_float=-report.ly)
            pad.right_joystick_float(x_value_float=report.rx, y_value_float=-report.ry)
        else:
            buttons = {
                "cross": vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
                "circle": vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
                "square": vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
                "triangle": vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
                "l1": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
                "r1": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
                "l3": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
                "r3": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,
                "share": vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
                "options": vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
                "ps": vg.XUSB_BUTTON.XUSB_GAMEPAD_GUIDE,
                "d_up": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
                "d_down": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
                "d_left": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
                "d_right": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,
            }
            for key, button in buttons.items():
                if key in pressed:
                    pad.press_button(button=button)
            pad.left_joystick_float(x_value_float=report.lx, y_value_float=report.ly)
            pad.right_joystick_float(x_value_float=report.rx, y_value_float=report.ry)
        pad.left_trigger_float(value_float=1.0 if "l2" in pressed else 0.0)
        pad.right_trigger_float(value_float=1.0 if "r2" in pressed else 0.0)
        pad.update()

    def reset(self) -> None:
        self.pad.reset()
        self.pad.update()
