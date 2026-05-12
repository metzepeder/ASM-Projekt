# ASM-Project: Reaction Time Meter

An 8051 assembly program that measures human reaction time. The system lights an LED after a random delay, then measures how quickly the user presses a button — displaying the result in milliseconds on a 3-digit 7-segment display.

## Features

- Random wait time (1–15 seconds) before the start signal
- Reaction time measurement with 1 ms precision
- 3-digit multiplexed 7-segment display (0–999 ms)
- False start detection with buzzer alarm
- Startup LED blink as power-on indicator

## Hardware

| Pin       | Function                       |
| --------- | ------------------------------ |
| P1.0      | LED (start signal, active LOW) |
| P3.2      | Button (INT0, active LOW)      |
| P1.7      | Buzzer (active LOW)            |
| P2        | 7-segment display data         |
| P0.0–P0.2 | Digit select (multiplexing)    |

**Clock:** 12 MHz

## How It Works

1. On startup, the LED blinks briefly to confirm power-on.
2. The system waits a random 1–15 seconds (generated via 8-bit Galois LFSR).
3. The LED turns on — the player must press the button as fast as possible.
4. Timer 0 counts milliseconds until the button is pressed.
5. The reaction time is displayed on the 7-segment display.
6. If the button is pressed before the LED (false start), the buzzer sounds and the round restarts.
