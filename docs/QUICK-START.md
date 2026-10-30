# Quick start — TouchPadFC v11

**Windows:** extract this project, install Python 3.10+, install ViGEmBus, then run `run-receiver.bat` or `py -m receiver.server --mode xbox`. Copy the pairing PIN. Obtain the PC's IPv4 address with `ipconfig`.

**Mac:** install Xcode and XcodeGen. From this folder run `xcodegen generate`, then open `TouchPadFC.xcodeproj`. Select your signing team, bundle ID and physical iPhone. Build/Run.

**iPhone:** grant Local Network permission, tap **PC**, type PC IPv4 address and PIN, tap Connect and Play. Keep both devices on a trusted private LAN. Test the virtual controller in `joy.cpl` on Windows before opening EA FC 27.

**Button sizing:** PC > Button Size adjusts everything. EDIT > select control > slider changes its individual size. Drag to move. DONE saves the layout. PC > Movement Joystick chooses Fixed or Floating.

**Troubleshooting:** IP address must be the PC's *LAN IPv4*, not `127.0.0.1` or a public address; with Hyper-V, VMware, Tailscale or a VPN installed, pick the address of the Wi-Fi/Ethernet adapter, not a virtual one. If the receiver reports `WinError 10013`, Windows reserved UDP 52777 — start it with `--port 53400` and set the same **UDP port** in the app. Also check private Wi-Fi, firewall UDP, receiver window and ViGEmBus installation. If menus work but FC doesn't respond, verify the game is using the emulated controller and its Classic layout.
