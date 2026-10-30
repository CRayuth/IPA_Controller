"""TouchPadFC - Windows receiver with a click-to-run window.

Double-click TouchPadFC.exe and it:

* checks the ViGEmBus virtual-gamepad driver and installs it when missing,
* adds the Windows Firewall rule for the UDP port it uses,
* picks a free UDP port automatically (Hyper-V reserves whole port ranges),
* shows the exact IP address, port and pairing PIN to type into the iPhone app,
* runs the receiver until STOP is pressed.

No Python installation and no command line are needed.
"""

import ctypes
import json
import os
import queue
import re
import secrets
import socket
import subprocess
import sys
import tempfile
import threading
import time
import tkinter as tk
import urllib.request
from pathlib import Path
from tkinter import messagebox, ttk

APP_NAME = "TouchPadFC"
SERVICE_NAME = "ViGEmBus"
RULE_NAME = "TouchPadFC receiver"
VIGEM_VERSION = "1.22.0"
VIGEM_FILE = f"ViGEmBus_{VIGEM_VERSION}_x64_x86_arm64.exe"
VIGEM_URL = (
    "https://github.com/nefarius/ViGEmBus/releases/download/"
    f"v{VIGEM_VERSION}/{VIGEM_FILE}"
)
PREFERRED_PORT = 52777
HIDDEN_WINDOW = 0x08000000

ROOT = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(ROOT))

from receiver.server import run as run_receiver  # noqa: E402
from receiver.server import suggest_free_port  # noqa: E402

SETTINGS_PATH = (
    Path(os.environ.get("LOCALAPPDATA", tempfile.gettempdir()))
    / APP_NAME
    / "settings.json"
)

BG = "#0a1020"
PANEL = "#121a2b"
TEXT = "#e8eef7"
MUTED = "#8fa3bf"
ACCENT = "#37d67a"
WARN = "#f0a020"
ERROR = "#ef5f5f"


def load_settings() -> dict:
    try:
        return json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_settings(values: dict) -> None:
    try:
        SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
        SETTINGS_PATH.write_text(json.dumps(values, indent=2), encoding="utf-8")
    except OSError:
        pass


def service_running() -> bool:
    """True when the ViGEmBus kernel driver is installed and started."""

    try:
        completed = subprocess.run(
            ["sc", "query", SERVICE_NAME],
            capture_output=True,
            text=True,
            creationflags=HIDDEN_WINDOW,
        )
    except OSError:
        return False

    return completed.returncode == 0 and "RUNNING" in completed.stdout.upper()


def run_elevated(executable: str, parameters: str) -> bool:
    """Start a program through the Windows UAC prompt."""

    try:
        result = ctypes.windll.shell32.ShellExecuteW(
            None, "runas", executable, parameters, None, 1
        )
    except Exception:
        return False

    return result > 32


def install_driver(log) -> bool:
    if service_running():
        log("ViGEmBus is already installed.")
        return True

    installer = Path(tempfile.gettempdir()) / VIGEM_FILE

    if not installer.exists():
        log(f"Downloading the ViGEmBus {VIGEM_VERSION} driver...")

        try:
            with urllib.request.urlopen(VIGEM_URL, timeout=120) as response:
                installer.write_bytes(response.read())
        except Exception as exc:
            log(f"Download failed: {exc}")
            return False

        log(f"Saved installer to {installer}")

    log("Starting the ViGEmBus installer - accept the Windows prompt.")

    if not run_elevated(str(installer), "/S"):
        log("Installer was cancelled or blocked by Windows.")
        return False

    log("Waiting for the driver to start...")

    for _ in range(60):
        if service_running():
            log("ViGEmBus installed and running.")
            return True
        time.sleep(2)

    log("ViGEmBus did not start. Reboot Windows and open TouchPadFC again.")
    return False


def rule_exists() -> bool:
    try:
        completed = subprocess.run(
            ["netsh", "advfirewall", "firewall", "show", "rule", f"name={RULE_NAME}"],
            capture_output=True,
            text=True,
            creationflags=HIDDEN_WINDOW,
        )
    except OSError:
        return False

    return completed.returncode == 0


def add_firewall_rule(port: int) -> bool:
    parameters = (
        f'/c netsh advfirewall firewall delete rule name="{RULE_NAME}" '
        f'& netsh advfirewall firewall add rule name="{RULE_NAME}" '
        f"dir=in action=allow protocol=UDP localport={port} profile=any"
    )

    return run_elevated("cmd.exe", parameters)


def local_addresses() -> list:
    """IPv4 candidates, real network cards first and virtual adapters last.

    Virtual adapters (VMware, Hyper-V, VPN, Tailscale) cannot be reached from a
    phone, so they are pushed to the bottom of the list.
    """

    virtual_names = (
        "vmware",
        "virtualbox",
        "hyper-v",
        "vethernet",
        "tailscale",
        "loopback",
        "wintun",
        "tap-",
        "vpn",
        "bluetooth",
        "docker",
        "default switch",
    )
    physical = []
    virtual = []

    try:
        listing = subprocess.run(
            ["ipconfig"],
            capture_output=True,
            text=True,
            errors="ignore",
            creationflags=HIDDEN_WINDOW,
        ).stdout
    except OSError:
        listing = ""

    header = ""

    for raw_line in listing.splitlines():
        line = raw_line.strip()

        if not line:
            continue

        if not raw_line[:1].isspace() and line.endswith(":"):
            header = line[:-1]
            continue

        match = re.search(r"(\d{1,3}(?:\.\d{1,3}){3})", line)

        if not match:
            continue

        address = match.group(1)
        lowered = header.lower()

        if address.startswith(("127.", "169.254.", "255.")):
            continue

        if any(name in lowered for name in virtual_names):
            virtual.append(address)
        else:
            physical.append(address)

        header = ""

    found = []

    for address in physical + virtual:
        if address not in found:
            found.append(address)

    if not found:
        try:
            for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
                address = info[4][0]

                if address.startswith(("127.", "169.254.")) or address in found:
                    continue

                found.append(address)
        except OSError:
            pass

    preferred = ""

    try:
        probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        probe.connect(("8.8.8.8", 80))
        preferred = probe.getsockname()[0]
        probe.close()
    except OSError:
        preferred = ""

    if preferred in found:
        found.remove(preferred)
        found.insert(0, preferred)

    return found or ["127.0.0.1"]


def dpi_scale() -> float:
    """Make the window crisp on scaled displays and return the scale factor."""

    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(1)
    except Exception:
        pass

    try:
        return ctypes.windll.user32.GetDpiForSystem() / 96.0
    except Exception:
        return 1.0


class LogWriter:
    """Redirects receiver prints (and tracebacks) into the window."""

    def __init__(self, sink):
        self.sink = sink

    def write(self, text):
        for line in str(text).splitlines():
            line = line.strip()

            if line:
                self.sink(line)

    def flush(self):
        pass


class ReceiverApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_NAME} - Windows receiver")
        self.configure(bg=BG)

        scale = dpi_scale()
        self.tk.call("tk", "scaling", 1.3333 * scale)
        self.geometry(f"{int(660 * scale)}x{int(470 * scale)}")
        self.minsize(int(600 * scale), int(430 * scale))
        self.protocol("WM_DELETE_WINDOW", self.on_close)

        self.settings = load_settings()
        self.messages = queue.Queue()
        self.stop_event = None
        self.thread = None
        self.running = False
        self.firewall_port = self.settings.get("firewall_port")

        addresses = local_addresses()

        self.ip_var = tk.StringVar(value=self.settings.get("ip", addresses[0]))
        self.port_var = tk.StringVar(
            value=str(self.settings.get("port", suggest_free_port(PREFERRED_PORT)))
        )
        self.pin_var = tk.StringVar(
            value=self.settings.get("pin", f"{secrets.randbelow(1_000_000):06d}")
        )
        self.mode_var = tk.StringVar(value=self.settings.get("mode", "Xbox 360"))
        self.status_var = tk.StringVar(value="Stopped")
        self.driver_var = tk.StringVar()
        self.firewall_var = tk.StringVar()

        self.build_ui(addresses)
        self.refresh_driver()
        self.refresh_firewall()

        sys.stdout = LogWriter(self.log)
        sys.stderr = LogWriter(self.log)

        self.say(f"{APP_NAME} ready. Press START, then connect the iPhone.")
        self.after(120, self.drain_messages)

    def dark_style(self):
        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure(
            "Dark.TCombobox",
            fieldbackground="#1b2438",
            background="#1b2438",
            foreground=TEXT,
            arrowcolor=TEXT,
            bordercolor="#22304a",
            lightcolor="#1b2438",
            darkcolor="#1b2438",
            selectbackground="#26334c",
            selectforeground=TEXT,
        )
        style.map(
            "Dark.TCombobox",
            fieldbackground=[("readonly", "#1b2438"), ("active", "#1b2438")],
            foreground=[("readonly", TEXT), ("active", TEXT)],
            background=[("active", "#26334c")],
            arrowcolor=[("active", TEXT)],
        )
        for option, value in (
            ("*TCombobox*Listbox.background", "#1b2438"),
            ("*TCombobox*Listbox.foreground", TEXT),
            ("*TCombobox*Listbox.selectBackground", "#26334c"),
            ("*TCombobox*Listbox.selectForeground", TEXT),
        ):
            self.option_add(option, value)

    # ---------------------------------------------------------------- layout

    def build_ui(self, addresses):
        self.dark_style()

        header = tk.Frame(self, bg=BG)
        header.pack(fill="x", padx=18, pady=(16, 6))

        tk.Label(
            header,
            text=APP_NAME,
            bg=BG,
            fg=TEXT,
            font=("Segoe UI Semibold", 20),
        ).pack(side="left")

        tk.Label(
            header,
            textvariable=self.status_var,
            bg=BG,
            fg=MUTED,
            font=("Segoe UI", 11),
        ).pack(side="right")

        panel = tk.Frame(self, bg=PANEL, highlightthickness=1, highlightbackground="#22304a")
        panel.pack(fill="x", padx=18, pady=8)
        panel.columnconfigure(1, weight=1)

        tk.Label(
            panel,
            text="TYPE THIS INTO THE IPHONE APP",
            bg=PANEL,
            fg=MUTED,
            font=("Segoe UI Semibold", 9),
        ).grid(row=0, column=0, columnspan=3, sticky="w", padx=12, pady=(10, 4))

        self.field(panel, 1, "PC IP", ttk.Combobox(
            panel,
            textvariable=self.ip_var,
            values=addresses,
            font=("Consolas", 13),
            width=18,
            style="Dark.TCombobox",
        ))

        self.field(panel, 2, "UDP port", tk.Entry(
            panel,
            textvariable=self.port_var,
            bg="#1b2438",
            fg=TEXT,
            insertbackground=TEXT,
            relief="flat",
            font=("Consolas", 13),
            width=20,
        ))

        pin_row = tk.Frame(panel, bg=PANEL)
        pin_row.grid(row=3, column=1, columnspan=2, sticky="ew", padx=(0, 12), pady=4)

        tk.Entry(
            pin_row,
            textvariable=self.pin_var,
            bg="#1b2438",
            fg=ACCENT,
            insertbackground=TEXT,
            relief="flat",
            font=("Consolas", 13),
            width=10,
        ).pack(side="left")

        tk.Button(
            pin_row,
            text="New PIN",
            command=self.new_pin,
            bg="#1b2438",
            fg=TEXT,
            relief="flat",
            activebackground="#26334c",
            activeforeground=TEXT,
            font=("Segoe UI", 9),
            padx=10,
        ).pack(side="left", padx=8)

        tk.Label(panel, text="PIN", bg=PANEL, fg=MUTED, font=("Segoe UI", 10)).grid(
            row=3, column=0, sticky="e", padx=(12, 10), pady=4
        )

        self.field(panel, 4, "Virtual pad", ttk.Combobox(
            panel,
            textvariable=self.mode_var,
            values=["Xbox 360", "PlayStation 4"],
            state="readonly",
            font=("Segoe UI", 11),
            width=18,
            style="Dark.TCombobox",
        ))

        tk.Frame(panel, bg=PANEL, height=8).grid(row=5, column=0, columnspan=3)

        controls = tk.Frame(self, bg=BG)
        controls.pack(fill="x", padx=18, pady=4)

        self.start_button = tk.Button(
            controls,
            text="START",
            command=self.start,
            bg=ACCENT,
            fg="#04140b",
            relief="flat",
            font=("Segoe UI Semibold", 12),
            padx=26,
            pady=8,
            activebackground="#2bb863",
        )
        self.start_button.pack(side="left")

        self.stop_button = tk.Button(
            controls,
            text="STOP",
            command=self.stop,
            bg="#1b2438",
            fg=TEXT,
            relief="flat",
            state="disabled",
            font=("Segoe UI Semibold", 12),
            padx=26,
            pady=8,
            activebackground="#26334c",
        )
        self.stop_button.pack(side="left", padx=8)

        self.button(controls, "Install driver", self.install_driver_clicked).pack(side="left", padx=(18, 6))
        self.button(controls, "Allow firewall", self.allow_firewall_clicked).pack(side="left")

        info = tk.Frame(self, bg=BG)
        info.pack(fill="x", padx=18, pady=(6, 0))

        tk.Label(
            info,
            textvariable=self.driver_var,
            bg=BG,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(side="left")

        tk.Label(
            info,
            textvariable=self.firewall_var,
            bg=BG,
            fg=MUTED,
            font=("Segoe UI", 9),
        ).pack(side="left", padx=14)

        log_frame = tk.Frame(self, bg=PANEL)
        log_frame.pack(fill="both", expand=True, padx=18, pady=(8, 16))

        self.log_view = tk.Text(
            log_frame,
            bg=PANEL,
            fg=TEXT,
            relief="flat",
            font=("Consolas", 9),
            height=8,
            wrap="word",
            state="disabled",
        )
        self.log_view.pack(fill="both", expand=True, padx=8, pady=8)

    def field(self, parent, row, label, widget):
        tk.Label(parent, text=label, bg=PANEL, fg=MUTED, font=("Segoe UI", 10)).grid(
            row=row, column=0, sticky="e", padx=(12, 10), pady=4
        )
        widget.grid(row=row, column=1, sticky="w", pady=4)

    def button(self, parent, text, command):
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg="#1b2438",
            fg=TEXT,
            relief="flat",
            activebackground="#26334c",
            activeforeground=TEXT,
            font=("Segoe UI", 9),
            padx=12,
            pady=7,
        )

    # ------------------------------------------------------------------ log

    def log(self, message):
        self.messages.put(message)

    def say(self, message):
        self.log(message)

    def drain_messages(self):
        while True:
            try:
                message = self.messages.get_nowait()
            except queue.Empty:
                break

            self.log_view.configure(state="normal")
            self.log_view.insert("end", message + "\n")
            self.log_view.see("end")
            self.log_view.configure(state="disabled")

            if "iPhone paired" in message:
                self.status_var.set("iPhone connected")
            elif "Controller idle" in message:
                self.status_var.set("Running - waiting for iPhone")
            elif "Cannot bind" in message:
                self.status_var.set("Port unavailable")

        self.after(120, self.drain_messages)

    # ------------------------------------------------------------- controls

    def new_pin(self):
        self.pin_var.set(f"{secrets.randbelow(1_000_000):06d}")

    def refresh_driver(self):
        if service_running():
            self.driver_var.set("Driver: ViGEmBus OK")
        else:
            self.driver_var.set("Driver: ViGEmBus missing - press Install driver")

    def refresh_firewall(self):
        try:
            port = int(self.port_var.get())
        except ValueError:
            port = 0

        if rule_exists() and self.firewall_port == port:
            self.firewall_var.set(f"Firewall: UDP {port} allowed")
        else:
            self.firewall_var.set("Firewall: rule not set")

    def install_driver_clicked(self):
        if service_running():
            self.refresh_driver()
            return

        if not messagebox.askyesno(
            "Install ViGEmBus",
            "TouchPadFC needs the free ViGEmBus driver from Nefarius to create a "
            "virtual controller.\n\nDownload and install it now? Windows will ask "
            "for permission.",
        ):
            return

        threading.Thread(
            target=self._install_driver_worker, daemon=True
        ).start()

    def _install_driver_worker(self):
        install_driver(self.log)
        self.after(0, self.refresh_driver)

    def allow_firewall_clicked(self):
        try:
            port = int(self.port_var.get())
        except ValueError:
            messagebox.showerror(APP_NAME, "Enter a numeric UDP port first.")
            return

        if not messagebox.askyesno(
            "Windows Firewall",
            f"Allow incoming UDP {port} so the iPhone can reach this PC?\n\n"
            "Windows will ask for permission. Keep this rule for private networks only.",
        ):
            return

        if add_firewall_rule(port):
            self.firewall_port = port
            self.settings["firewall_port"] = port
            save_settings(self.settings)
            self.say(f"Firewall rule added for UDP {port}.")
        else:
            self.say("Firewall rule was not added.")

        self.after(1500, self.refresh_firewall)

    def start(self):
        if self.running:
            return

        if not service_running():
            messagebox.showwarning(
                APP_NAME,
                "The ViGEmBus driver is not installed.\n\nPress Install driver first.",
            )
            return

        try:
            port = int(self.port_var.get())

            if not 1 <= port <= 65535:
                raise ValueError
        except ValueError:
            messagebox.showerror(APP_NAME, "Enter a UDP port between 1 and 65535.")
            return

        pin = self.pin_var.get().strip()

        if len(pin) != 6 or not pin.isdigit():
            messagebox.showerror(APP_NAME, "The PIN must be six digits.")
            return

        mode = "ds4" if self.mode_var.get().startswith("PlayStation") else "xbox"

        if not rule_exists() or self.firewall_port != port:
            if messagebox.askyesno(
                "Windows Firewall",
                f"The iPhone must reach UDP {port}.\n\nAdd the firewall rule now? "
                "Windows will ask for permission.",
            ):
                if add_firewall_rule(port):
                    self.firewall_port = port
                    self.settings["firewall_port"] = port
                    self.say(f"Firewall rule added for UDP {port}.")

        self.settings.update(
            {
                "ip": self.ip_var.get(),
                "port": port,
                "pin": pin,
                "mode": self.mode_var.get(),
                "firewall_port": self.firewall_port,
            }
        )
        save_settings(self.settings)

        self.running = True
        self.stop_event = threading.Event()
        self.start_button.configure(state="disabled")
        self.stop_button.configure(state="normal")
        self.status_var.set("Running - waiting for iPhone")

        self.say("")
        self.say(f"PC address: {self.ip_var.get()}   port: {port}   PIN: {pin}")
        self.say("In the iPhone app: PC > type all three values > Connect > Play.")

        self.thread = threading.Thread(
            target=self._worker, args=(mode, pin, port), daemon=True
        )
        self.thread.start()

        self.after(2000, self.refresh_firewall)

    def _worker(self, mode, pin, port):
        try:
            run_receiver(mode, pin, port, False, None, self.stop_event)
        except SystemExit:
            self.log("Receiver stopped: the UDP port is not usable.")
        except Exception as exc:
            self.log(f"Receiver error: {exc}")
        finally:
            self.after(0, self._stopped)

    def stop(self):
        if not self.running:
            return

        if self.stop_event is not None:
            self.stop_event.set()

        self.running = False
        self.start_button.configure(state="normal")
        self.stop_button.configure(state="disabled")
        self.status_var.set("Stopped")
        self.say("Stopped. All virtual buttons released.")

    def _stopped(self):
        self.running = False
        self.start_button.configure(state="normal")
        self.stop_button.configure(state="disabled")
        self.status_var.set("Stopped")

    def on_close(self):
        if self.running and self.stop_event is not None:
            self.stop_event.set()
            time.sleep(0.3)

        self.destroy()


def selftest(target: str) -> int:
    lines = [
        f"{APP_NAME} self-test",
        f"frozen={bool(getattr(sys, 'frozen', False))}",
        f"python={sys.version.split()[0]}",
        f"driver={service_running()}",
        f"suggested_port={suggest_free_port(PREFERRED_PORT)}",
        f"addresses={','.join(local_addresses())}",
        f"settings={SETTINGS_PATH}",
    ]
    lines.append("receiver_import=ok")

    try:
        Path(target).write_text("\n".join(lines), encoding="utf-8")
    except OSError:
        return 1

    return 0


def headless(target: str, seconds: float, port: int, pin: str) -> int:
    """Run the receiver without a window - used to smoke-test the bundle."""

    collected = []
    sys.stdout = LogWriter(collected.append)
    sys.stderr = LogWriter(collected.append)

    stop_event = threading.Event()

    def worker():
        try:
            run_receiver("xbox", pin, port, False, None, stop_event)
        except SystemExit:
            collected.append("receiver exited: port unusable")
        except Exception as exc:
            collected.append(f"receiver error: {exc}")

    thread = threading.Thread(target=worker, daemon=True)
    thread.start()
    time.sleep(seconds)
    stop_event.set()
    thread.join(5)

    status = "stuck" if thread.is_alive() else "clean"

    try:
        Path(target).write_text(
            "\n".join([f"headless exit={status}"] + collected), encoding="utf-8"
        )
    except OSError:
        return 1

    return 0


def main() -> int:
    if "--selftest" in sys.argv:
        index = sys.argv.index("--selftest")
        target = (
            sys.argv[index + 1]
            if len(sys.argv) > index + 1
            else str(Path(tempfile.gettempdir()) / "touchpadfc-selftest.txt")
        )

        return selftest(target)

    if "--headless" in sys.argv:
        index = sys.argv.index("--headless")
        target = sys.argv[index + 1]
        port = int(sys.argv[index + 2])
        pin = sys.argv[index + 3]
        seconds = float(sys.argv[index + 4]) if len(sys.argv) > index + 4 else 5.0

        return headless(target, seconds, port, pin)

    app = ReceiverApp()
    app.mainloop()

    return 0


if __name__ == "__main__":
    sys.exit(main())
