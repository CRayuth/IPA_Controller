# TouchPadFC 🎮

Turn your iPhone into a touchscreen controller for **EA SPORTS FC on Windows**. Built with SwiftUI and a Python virtual-gamepad receiver, with controls inspired by eFootball Mobile.

## Features

- **Four-button gameplay:** PASS, THROUGH, SHOOT and DASH, with tap, hold and swipe gestures.
- **Advanced controls:** skills, tactics, defending, goalkeeper and set-piece actions.
- **Custom layout:** drag and resize buttons, choose Fixed or Floating joystick, and set quick actions.
- **Wi-Fi connection:** pair your iPhone with your PC using a six-digit PIN.

## Quick Start

**1. Windows:** Download **TouchPadFC.exe** from the [latest release](https://github.com/CRayuth/IPA_Controller/releases/latest) and double-click it. No Python install and no command line are needed: on first run it installs the free ViGEmBus driver, opens the firewall port, picks a free UDP port and shows the IP address, port and PIN to type into the app.

Prefer running from source? Install Python 3.10+ and the ViGEmBus driver, then in the project folder run:

```powershell
py -m pip install -r receiver/requirements.txt
py -m receiver.server --mode xbox
```

If Windows refuses UDP 52777 (`WinError 10013`), Hyper-V, WinNAT or a VPN adapter reserved it — run the receiver with `--port 53400` and set the same **UDP port** in the app.

**2. iPhone:** On a Mac with Xcode and XcodeGen installed, run:

```bash
xcodegen generate
open TouchPadFC.xcodeproj
```

Select your signing team in Xcode and install the app on your iPhone.

**3. Connect:** Put both devices on the same private Wi-Fi network. In TouchPadFC, tap **PC**, enter your Windows IPv4 address (the Wi-Fi adapter's, not a Hyper-V/VMware/Tailscale one), the receiver's UDP port and the PIN, then tap **Connect → Play**. Check inputs with `joy.cpl` on Windows.
