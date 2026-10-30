# Optional REA (morluto/rea) workflow

REA is an agent-assisted reverse-engineering tool, **not** an iOS gamepad framework.

Install the official tool if you want to inspect binaries or understand your own app's compiled behavior:

```bash
npx rea-agents setup
```

Official project: https://github.com/morluto/rea

Suggested agent task:

> Inspect binaries I built from my own TouchPadFC iOS and Windows code. Identify the UDP packet encode/decode paths and compare button and joystick mapping with the source. Explain findings with evidence. Do not modify EA FC 27, game executables, anti-cheat, console firmware, or third-party proprietary code.

No part of this prototype imports or executes REA; using it is entirely optional.
