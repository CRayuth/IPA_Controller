# TouchPad FC 27 v3 — iPhone touchscreen gamepad for Windows

This project contains an Xcode-ready SwiftUI source app and a Python Windows virtual gamepad receiver.
It is **not** a pre-signed IPA, not a native DualSense driver, and does not control an actual PS5 console.

## Updated FC 27 features

- More compact landscape layout with larger move stick, face buttons and shoulder controls.
- Attack and Defend **manual display modes** with matching gameplay labels.
- Manual combo keys: finesse, chip, power shot, driven pass, curved run, pass & follow, and defensive combinations.
- Optional Sprint Lock. It starts disabled and is reset when disconnecting or changing mode.
- Multi-touch holds tracked by source: releasing one shortcut cannot cancel another still-held input.
- Left/right sticks have a small center deadzone for accurate dribbling and skill moves.
- 60 input reports/second; Windows now acknowledges valid packets, so CONNECTED actually means the receiver replied.
- The receiver defaults to an Xbox 360 virtual controller for common PC gamepad compatibility. DS4 mode remains available.
- The inactivity safety timeout still releases stuck inputs after 350 ms.

## v3 — Editable controller layout (new)

1. Tap **EDIT LAYOUT** at the top of the iPhone screen. Editing releases held gamepad inputs.
2. Tap and drag any control to move it; drag the **Size** slider to resize the selected control (65–145%).
3. Choose **RESET ITEM** for one control, or **RESET ALL** to restore the original layout.
4. Tap **DONE**. Positions and sizes save locally on the iPhone, and persist on relaunch.

You can edit **offline** before pairing. The six attack/defend shortcut positions are shared, but their actions change with mode. See [docs/LAYOUT-EDITOR.md](docs/LAYOUT-EDITOR.md).

**Upgrade from v2:** Replace the complete `ControllerView.swift` file and add `ControllerLayout.swift` inside `ios/TouchPadFC`. No receiver files or `project.yml` changes are required. Re-run `xcodegen generate` so Xcode includes the added Swift file. This package also includes updated documentation.

## Folder structure

```text
TouchPadFC-FC27-v3/
├── project.yml
├── ios/TouchPadFC/
│   ├── TouchPadFCApp.swift
│   ├── ControllerModel.swift        # from v2: buttons, sprint, 60 Hz, ACK
│   ├── ControllerView.swift         # CHANGED: draggable, scalable layout
│   └── ControllerLayout.swift       # NEW: layout state + saved positions
├── receiver/
│   ├── server.py                    # from v2: ACK, xbox default
│   ├── gamepad.py                   # UNCHANGED: mapping
│   ├── protocol.py                  # UNCHANGED: validated input
│   ├── requirements.txt
│   └── tests/test_protocol.py
└── docs/
    ├── LAYOUT-EDITOR.md            # NEW: editing, resizing and reset
    ├── FC27-CONTROLS.md            # from v2
    └── REA.md
```

## 1. Windows receiver

Open PowerShell in the project folder:

```powershell
py -m pip install -r receiver/requirements.txt
py -m receiver.server --mode xbox
```

You need the **ViGEmBus** virtual controller driver supported by `vgamepad` on Windows.
If the driver is already installed, do not install another copy.
The receiver prints a 6-digit PIN. Run `ipconfig` to find your PC's local IPv4 address.
Allow Python on your **Private** firewall network only; keep UDP port `52777` off the public internet.
For a driver-free test: `py -m receiver.server --dry-run --pin 123456`.

## 2. Build and install on iPhone

Xcode and macOS are needed for normal iOS compilation and signing.

```bash
brew install xcodegen
cd TouchPadFC-FC27-v3
xcodegen generate
open TouchPadFC.xcodeproj
```

Choose your Apple Development Team and your unique iOS bundle identifier in Xcode.
Build to a connected iPhone, then use **Product > Archive** if you need a signed IPA distribution workflow.
The target requires iOS 16+.

## 3. Play EA SPORTS FC 27 on Windows

1. Connect your PC and iPhone to the same **private Wi-Fi**.
2. Start the receiver and record its PIN and the PC IPv4 address.
3. Open the iPhone app. Enter the host and PIN; tap Connect, and wait for **CONNECTED**.
4. On Windows press Win+R, enter `joy.cpl`, and verify the controls.
5. Launch FC 27 and configure **Settings > Customize Controls > Classic**.
6. Use ATTACK/DEFEND to change on-screen labels; select it manually when possession changes if helpful.
7. Read [docs/FC27-CONTROLS.md](docs/FC27-CONTROLS.md) for the detailed mapping.

If FC 27 does not detect Xbox mode, stop the receiver and try:

```powershell
py -m receiver.server --mode ds4
```

Note that selecting **Xbox labels** on the iPhone changes button *text* only, not the selected Windows virtual device type.

## Security and limitations

- The PIN travels over unencrypted UDP: use trusted private Wi-Fi only.
- A receiver ACK confirms packet reception, **not** successful driver installation or FC 27 acceptance.
- Basic touchscreen shortcuts merely combine standard manual gamepad buttons. This is not shot timing automation.
- Touch cannot replicate physical analog trigger pressure, force-feedback or adaptive triggers.
- iOS builds and actual EA FC 27 gameplay need testing on real hardware; passing source syntax/tests is not proof of compatibility.
- REA is optional for inspecting your own builds. Do not modify EA FC 27 or its anti-cheat.

## Validate Python protocol

```powershell
py -m unittest discover -s receiver/tests -v
```
