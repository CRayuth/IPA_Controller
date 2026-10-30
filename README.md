# TouchPadFC 🎮

Turn your iPhone into a touchscreen controller for **EA SPORTS FC on Windows**. Built with SwiftUI and a Python virtual-gamepad receiver, with controls inspired by eFootball Mobile.

## Features

- **Four-button gameplay:** PASS, THROUGH, SHOOT and DASH, with tap, hold and swipe gestures.
- **Advanced controls:** skills, tactics, defending, goalkeeper and set-piece actions.
- **Custom layout:** drag and resize buttons, choose Fixed or Floating joystick, and set quick actions.
- **Wi-Fi connection:** pair your iPhone with your PC using a six-digit PIN.

## Quick Start

**1. Windows:** Install Python 3.10+ and the ViGEmBus driver. In the project folder, run:

```powershell
py -m pip install -r receiver/requirements.txt
py -m receiver.server --mode xbox
```

**2. iPhone:** On a Mac with Xcode and XcodeGen installed, run:

```bash
xcodegen generate
open TouchPadFC.xcodeproj
```

Select your signing team in Xcode and install the app on your iPhone.

**3. Connect:** Put both devices on the same private Wi-Fi network. In TouchPadFC, tap **PC**, enter your Windows IPv4 address and the receiver PIN, then tap **Connect → Play**. Check inputs with `joy.cpl` on Windows.
