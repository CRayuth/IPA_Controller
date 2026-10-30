# TouchPadFC v3 — Custom controller layout

## What is new

All visible controller pieces can be moved and resized without changing the Windows receiver or the EA FC 27 gamepad protocol:

- Left and right analog sticks
- D-pad and four face buttons (each group moves and scales together)
- L1, L2, R1 and R2
- Six contextual attack/defend shortcut tiles
- L3, R3, Share/View and Options/Menu
- Sprint Lock

The attack and defend shortcuts share six tile *positions*. You can place the tile once, then use ATTACK/DEFEND during play to change the actions shown there.

## How to edit on your iPhone

1. Open TouchPadFC in **landscape**. You do not need to connect to Windows first.
2. Tap **EDIT LAYOUT** in the top bar. The app releases all held inputs before editing.
3. Touch a control to **select** it. Drag to move it.
4. Use the **size slider** at the bottom to make the selected control 65%–145% of its default size.
5. Tap **RESET ITEM** to restore just the selected control. **RESET ALL** asks for confirmation and restores the whole layout.
6. Tap **DONE** to play. Changes save automatically to iPhone `UserDefaults`; the app restores them next launch.

The canvas keeps a control's center inside the playable area, including after resizing. Overlapping controls are allowed intentionally; move them apart if touches are blocked. On a compact phone, consider shrinking shortcut tiles and using a larger move joystick.

## Suggested layout for football games

- Make **MOVE** larger and keep it near your left thumb.
- Put **R2/SPRINT** and **PASS** close to your right thumb without overlapping the face buttons.
- Keep **SHOOT**, **PASS**, and **THROUGH** comfortably reachable; do not enlarge everything.
- Place finesse/chip/power-shot shortcut tiles farther from the two sticks to avoid accidental shots.
- Prefer **Xbox** virtual-controller mode first for Windows. PS/Xbox *text* on the iPhone is cosmetic.

## Behavior and limitations

- Editing blocks all controller input while you drag and resize. The Windows connection can stay open with neutral inputs.
- Match mode is still selected manually; the app cannot detect who has possession.
- iPhone cannot produce true analog PS5 adaptive-trigger behavior or operate as a native PS5 console controller.
- Local layout storage is per app installation, not synced to other iPhones.
- iOS/Xcode compilation and hardware gameplay remain to be tested on a Mac and iPhone.
