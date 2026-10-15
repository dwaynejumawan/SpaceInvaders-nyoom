# SpaceInvaders-nyoom
Computer Architecture Final Project
# Space Invaders (NASM, 32-bit Windows)

A Space Invaders-style game written entirely in x86 assembly (NASM).
Graphics are drawn pixel by pixel into an in-memory bitmap and shown with GDI.

## Controls
- Left/Right or A/D: move
- Space: shoot
- Z: use power-up
- Up/Down or 1-5: pick a power-up slot
- P or Esc: pause

## Run it
Download `invaders_gdi.exe` and double-click it (Windows only).

## Build it yourself
Install [NASM](https://www.nasm.us/), then run:

    nasm -f bin invaders_gdi.asm -o invaders_gdi.exe

    -- Hey Ethan Finished.
