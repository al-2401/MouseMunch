#!/usr/bin/env python3
"""Generates the game's sound effects as 16-bit mono WAV files.

The game ships small synthesised effects instead of licensed samples, so the
repository stays self contained. Re-run this script to regenerate
``assets/audio``:

    python3 tool/generate_sounds.py
"""

import math
import os
import random
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "audio")


def silence(duration):
    return [0.0] * int(duration * SAMPLE_RATE)


def mix(buf, start, samples, gain=1.0):
    """Adds ``samples`` into ``buf`` at ``start`` seconds, growing it if needed."""
    offset = int(start * SAMPLE_RATE)
    needed = offset + len(samples)
    if needed > len(buf):
        buf.extend([0.0] * (needed - len(buf)))
    for i, value in enumerate(samples):
        buf[offset + i] += value * gain
    return buf


def envelope(n, attack=0.005, release=0.5, curve=2.0):
    attack_n = max(1, int(attack * SAMPLE_RATE))
    out = []
    for i in range(n):
        if i < attack_n:
            amp = i / attack_n
        else:
            rest = (i - attack_n) / max(1, n - attack_n)
            amp = max(0.0, 1.0 - rest) ** curve
        out.append(amp)
    return out


def tone(duration, f_start, f_end, vibrato_hz=0.0, vibrato_depth=0.0, harmonics=(1.0, 0.35, 0.15)):
    n = int(duration * SAMPLE_RATE)
    env = envelope(n, attack=0.01, release=duration, curve=1.6)
    phase = 0.0
    out = []
    for i in range(n):
        t = i / n
        freq = f_start + (f_end - f_start) * t
        if vibrato_hz:
            freq *= 1.0 + vibrato_depth * math.sin(2 * math.pi * vibrato_hz * i / SAMPLE_RATE)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        value = sum(amp * math.sin(phase * (k + 1)) for k, amp in enumerate(harmonics))
        out.append(value * env[i] * 0.35)
    return out


def noise_burst(duration, low_pass=0.35, curve=3.0, attack=0.001):
    n = int(duration * SAMPLE_RATE)
    env = envelope(n, attack=attack, release=duration, curve=curve)
    out = []
    state = 0.0
    for i in range(n):
        white = random.uniform(-1.0, 1.0)
        state += low_pass * (white - state)
        out.append(state * env[i])
    return out


def click(duration, freq, curve=6.0):
    n = int(duration * SAMPLE_RATE)
    env = envelope(n, attack=0.0008, release=duration, curve=curve)
    return [math.sin(2 * math.pi * freq * i / SAMPLE_RATE) * env[i] for i in range(n)]


def write_wav(name, buf, peak=0.85):
    os.makedirs(OUT_DIR, exist_ok=True)
    loudest = max((abs(v) for v in buf), default=0.0)
    scale = (peak / loudest) if loudest > 0 else 0.0
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767)) for v in buf)
        handle.writeframes(frames)
    print("wrote %s (%d bytes)" % (path, os.path.getsize(path)))


def build_move():
    """Loopable pitter-patter of four little paws."""
    random.seed(11)
    buf = silence(0.48)
    for index, at in enumerate((0.0, 0.12, 0.24, 0.36)):
        pitch = 240 + (index % 2) * 60
        mix(buf, at, click(0.05, pitch), gain=0.5)
        mix(buf, at, noise_burst(0.045, low_pass=0.5, curve=5.0), gain=0.35)
    return buf


def build_eat():
    """A short crunch built from three grainy bites."""
    random.seed(23)
    buf = silence(0.34)
    for at, gain in ((0.0, 1.0), (0.11, 0.8), (0.21, 0.6)):
        mix(buf, at, noise_burst(0.1, low_pass=0.6, curve=4.0), gain=gain)
        mix(buf, at, click(0.06, 180), gain=0.25 * gain)
    return buf


def build_squeak():
    """The startled squeak: two rising chirps with vibrato."""
    buf = silence(0.42)
    mix(buf, 0.0, tone(0.18, 1750, 2650, vibrato_hz=38, vibrato_depth=0.04), gain=1.0)
    mix(buf, 0.2, tone(0.16, 2100, 2900, vibrato_hz=44, vibrato_depth=0.05), gain=0.8)
    return buf


def build_pour():
    """Crumbs raining out of the feeder."""
    random.seed(37)
    buf = silence(1.0)
    mix(buf, 0.0, noise_burst(0.85, low_pass=0.25, curve=2.2), gain=0.5)
    at = 0.02
    while at < 0.8:
        mix(buf, at, click(0.035, random.uniform(420, 1500)), gain=random.uniform(0.25, 0.6))
        at += random.uniform(0.02, 0.06)
    return buf


def build_tap():
    """Knock on the feeder."""
    random.seed(53)
    buf = silence(0.16)
    mix(buf, 0.0, click(0.09, 320, curve=8.0), gain=1.0)
    mix(buf, 0.0, click(0.05, 640, curve=9.0), gain=0.4)
    mix(buf, 0.0, noise_burst(0.05, low_pass=0.5, curve=7.0), gain=0.3)
    return buf


def build_ui():
    """Soft blip for menu interactions."""
    buf = silence(0.12)
    mix(buf, 0.0, tone(0.09, 880, 1320, harmonics=(1.0, 0.2)), gain=1.0)
    return buf


def main():
    write_wav("move.wav", build_move(), peak=0.55)
    write_wav("eat.wav", build_eat(), peak=0.8)
    write_wav("squeak.wav", build_squeak(), peak=0.9)
    write_wav("pour.wav", build_pour(), peak=0.8)
    write_wav("tap.wav", build_tap(), peak=0.85)
    write_wav("ui.wav", build_ui(), peak=0.5)


if __name__ == "__main__":
    main()
