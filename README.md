# TouchPadFC — complete v11 source project

Use an iPhone in landscape as a Wi-Fi touch controller for EA SPORTS FC on a Windows computer. The iPhone app is built with SwiftUI; the Python receiver uses `vgamepad` and the Windows ViGEmBus virtual gamepad driver. **This is source code, not an already-signed IPA.** Game behavior has not been validated on a real iPhone with FC 27.

## Project structure

```text
TouchPadFC-v11-complete/
├── ios/TouchPadFC/
│   ├── TouchPadFCApp.swift       SwiftUI entry point and game-mode selector
│   ├── ControllerModel.swift     UDP networking and timed input sequences
│   ├── ControllerView.swift      Landscape controller, settings and edit UI
│   ├── ControllerLayout.swift    Button positioning and scale persistence
│   ├── GesturePadButton.swift    PASS/THROUGH/SHOOT/DASH gesture recognition
│   ├── ActionLibrary.swift       Extended skills, tactics and action catalog
│   ├── SetPiecePad.swift         Penalty, free kick and corner layouts
│   └── Info.plist                iOS network privacy and landscape orientation
├── receiver/
│   ├── __init__.py
│   ├── gamepad.py                ViGEm virtual controller translation
│   ├── protocol.py               Packet validation
│   ├── possession.py             Optional experimental image detection
│   ├── server.py                 UDP receiver and pairing PIN
│   ├── requirements.txt
│   └── tests/test_protocol.py
├── docs/
│   ├── QUICK-START.md
│   ├── CONTROLS.md
│   ├── LAYOUT-EDITOR.md
│   └── REA.md
├── .github/workflows/ios.yml
├── project.yml                   XcodeGen configuration
├── run-receiver.bat              Windows convenience launcher
└── .gitignore
```

## Step 1 — Windows PC receiver

1. Install **Python 3.10+** for Windows, with the `py` launcher.
2. Install the **ViGEmBus driver** needed by `vgamepad`. Use a reputable official or project-maintained source. The ZIP does not bundle this driver.
3. Extract the ZIP, open PowerShell in the extracted folder, run:

   ```powershell
   py -m pip install -r receiver/requirements.txt
   py -m receiver.server --mode xbox
   ```

   Or double-click `run-receiver.bat`.
4. Note the **six-digit pairing PIN** printed in PowerShell. Keep the receiver running.
5. Run `ipconfig` and find your PC's actual IPv4 address (such as `192.168.1.20`).
6. Allow inbound **UDP port 52777 on your private LAN only** in Windows Firewall if asked.

The receiver has a test mode that does not require the virtual driver:

```powershell
py -m receiver.server --mode xbox --dry-run
```

A 6-digit PIN is only lightweight pairing, not encrypted authentication. Use a trusted private network; do **not** expose UDP 52777 to the public internet.

## Step 2 — iPhone app

You **need a Mac running Xcode** to compile and install this SwiftUI iOS source on an iPhone. XcodeGen generates the Xcode project; it is not included as a prebuilt `.xcodeproj` or IPA.

```bash
brew install xcodegen
cd /path/to/TouchPadFC-v11-complete
xcodegen generate
open TouchPadFC.xcodeproj
```

In Xcode:

1. Select the `TouchPadFC` target, then **Signing & Capabilities**.
2. Set your own **Team** and **Bundle Identifier** (the sample is `com.example.touchpadfc`).
3. Choose your connected iPhone and press **Run**. Trust the developer profile on device if prompted.
4. Allow **Local Network** access when iOS asks.
5. Open **PC** in TouchPadFC, enter Windows IPv4 address and the displayed PIN, tap **Connect**, then **Play**.
6. Run Windows `joy.cpl` to confirm the virtual Xbox controller responds before opening the game.

Choose the **Classic** control configuration in FC. Do not assume every advanced action works in all game modes; test in Practice Arena.

## Step 3 — play and customize

- Left movement: **Fixed / Floating** joystick, selectable from PC settings.
- Main actions: **THROUGH, SHOOT, PASS, DASH**. Tap, hold and swipe for variations.
- **Double-tap DASH** for the *proposed Curved Run mapping*, and **CANCEL ×2** for a Hard Super Cancel attempt.
- **SKILLS, TACTICS, ACTIONS** open the advanced catalog; Favorite actions with ★.
- **EDIT** to drag each on-screen match button and adjust its size, or **PC → Button Size** for global scaling.
- Customize the two **Quick Buttons** under PC settings.
- Top **GAME MODE** picker switches between match, penalties, free kicks and corners.

See `docs/CONTROLS.md` for the full control table and important limitations.

## Optional possession detection

The optional image-based `--roi x,y,width,height` system needs `mss`, `numpy` and a visible region of the game display that consistently changes with possession. It is experimental and does not automatically identify possession reliably.

```powershell
py -m pip install mss numpy
py -m receiver.server --mode xbox --roi 40,40,160,60
```

Calibrate attack with **F8** and defend with **F9** while the relevant game display is visible. Use manual mode when uncertain.

## Testing

```powershell
py -m unittest discover -s receiver/tests -v
```

Swift files were syntax-parsed on Linux and Python tests run, but that **is not** an iOS compilation. The GitHub Actions `ios.yml` runs `xcodebuild` on macOS when this project is committed to GitHub. Device pairing, ViGEm installation and EA FC gameplay still require real-world validation.

## Legal and safety

TouchPadFC is an independent experimental hobby controller and is **not affiliated with Electronic Arts, Apple, Microsoft or Konami**. Only connect to Windows PCs and networks you own or are authorized to use. EA FC settings and future updates may change how commands behave.
