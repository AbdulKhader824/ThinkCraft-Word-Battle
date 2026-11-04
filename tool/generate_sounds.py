"""Generates the game's original sound effects as small WAV files.

Every sound is built from soft tones here, so there are no licensing
questions. Run it again after changing a sound:

    py -3 tool/generate_sounds.py

Uses only Python's standard library.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")

# Kept well below full scale so sounds are friendly, never loud or harsh.
LOUDNESS = 0.45


def note(name):
    """Frequency of a note such as 'C5' or 'F#4'."""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semitone = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        semitone += 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semitone + (octave - 4) * 12) / 12)


def tone(freq, seconds, wave_shape="sine", attack=0.005, release=0.6,
         glide_to=None, volume=1.0):
    """One tone with a quick fade in and a smooth fade out."""
    count = int(RATE * seconds)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / count
        current = freq if glide_to is None else freq + (glide_to - freq) * t
        phase += 2 * math.pi * current / RATE
        if wave_shape == "triangle":
            value = 2 / math.pi * math.asin(math.sin(phase))
        else:
            # A little of the second harmonic makes sine tones sound
            # bell-like, like a toy xylophone.
            value = math.sin(phase) + 0.25 * math.sin(2 * phase)
            value /= 1.25
        attack_part = min(1.0, (i / RATE) / attack) if attack else 1.0
        release_part = math.exp(-t * 5 / release)
        samples.append(value * attack_part * release_part * volume)
    return samples


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*tracks):
    length = max(len(track) for track in tracks)
    return [
        sum(track[i] for track in tracks if i < len(track))
        for i in range(length)
    ]


def sequence(*parts):
    out = []
    for part in parts:
        out.extend(part)
    return out


def offset(samples, seconds):
    return silence(seconds) + samples


def save(name, samples):
    peak = max(abs(value) for value in samples) or 1.0
    scale = LOUDNESS / peak
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767))
            for v in samples
        ))
    print(f"{name}.wav  {len(samples) / RATE:.2f}s")


def main():
    random.seed(7)

    # A short, soft pop for button taps.
    save("tap", tone(520, 0.07, glide_to=880, release=0.5))

    # A bright two-note blip for choosing a tile.
    save("select", sequence(
        tone(note("C6"), 0.06, release=0.7),
        tone(note("E6"), 0.09, release=0.6),
    ))

    # A bubbly pop when another player gets ready.
    save("ready", tone(380, 0.12, glide_to=760, wave_shape="triangle",
                       release=0.45))

    # A rising sparkle when the letter appears.
    save("reveal", mix(
        offset(tone(note("C5"), 0.25), 0.00),
        offset(tone(note("E5"), 0.25), 0.07),
        offset(tone(note("G5"), 0.25), 0.14),
        offset(tone(note("C6"), 0.45), 0.21),
        offset(tone(note("E7"), 0.20, volume=0.25), 0.30),
    ))

    # A gentle wood-block tick for the last seconds of the timer.
    save("tick", tone(1046, 0.05, wave_shape="triangle", release=0.25))

    # A two-note chime when answers are locked in.
    save("lock", mix(
        offset(tone(note("G5"), 0.35), 0.00),
        offset(tone(note("C6"), 0.45), 0.10),
    ))

    # A happy rising ding for a Valid vote.
    save("valid", mix(
        offset(tone(note("E5"), 0.20), 0.00),
        offset(tone(note("A5"), 0.30), 0.06),
    ))

    # A soft, friendly falling "boop" for an Invalid vote. Never harsh.
    save("invalid", sequence(
        tone(note("E4"), 0.12, wave_shape="triangle", release=0.8),
        tone(note("C4"), 0.20, wave_shape="triangle", release=0.6),
    ))

    # A short fanfare when results appear.
    save("results", mix(
        offset(tone(note("C5"), 0.20), 0.00),
        offset(tone(note("E5"), 0.20), 0.10),
        offset(tone(note("G5"), 0.20), 0.20),
        offset(tone(note("C6"), 0.60), 0.30),
        offset(tone(note("E6"), 0.60, volume=0.5), 0.30),
    ))

    # A bigger celebration with sparkles for winning the game.
    sparkles = [
        offset(tone(note(name), 0.12, volume=0.3), 0.55 + i * 0.07)
        for i, name in enumerate(["C7", "E7", "G7", "E7", "C7", "G7"])
    ]
    save("win", mix(
        offset(tone(note("G4"), 0.18), 0.00),
        offset(tone(note("C5"), 0.18), 0.12),
        offset(tone(note("E5"), 0.18), 0.24),
        offset(tone(note("G5"), 0.18), 0.36),
        offset(tone(note("C6"), 0.90), 0.48),
        offset(tone(note("E6"), 0.90, volume=0.6), 0.48),
        offset(tone(note("G6"), 0.90, volume=0.4), 0.48),
        *sparkles,
    ))


if __name__ == "__main__":
    main()
