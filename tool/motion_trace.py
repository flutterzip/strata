#!/usr/bin/env python3
"""Measure how a horizontal UI motion decays, from a screen recording.

Why this exists
---------------
`Motion.carousel` in `lib/config/motion.dart` was fitted from frame-by-frame
tracking of a reference clip: a constant per-frame velocity ratio is the
signature of exponential decay, i.e. a spring rather than a fixed-duration
curve. That measurement was done by hand once. This script makes it
repeatable, so our own build can be compared against the same clip instead
of against a remembered number.

Method
------
1. ffmpeg decodes the video to raw 8-bit grayscale.
2. Each frame is collapsed to two 1-D profiles over the region of interest —
   one per axis. A carousel moving sideways shifts the horizontal profile
   bodily, which is exactly what cross-correlation measures well. Both axes
   are measured and the larger motion wins, so the tool does not have to be
   told which way the thing moved.
3. The shift between consecutive frames is found by phase correlation, with
   a parabolic fit around the peak for sub-pixel resolution.
4. Shifts are divided by the real gap between their two frames, taken from
   the container's presentation timestamps rather than assumed from a
   nominal frame rate. A simulator recording is variable frame rate — it
   emits frames when the screen changes — so a nominal "8.7 fps" average
   says nothing about how finely the fling itself was sampled.
5. sigma is also fitted by least squares on ln|v| against time, which is
   less sensitive to any single noisy frame than the ratios are.

Usage
-----
    python3 tool/motion_trace.py --video path/to/clip.mp4
    python3 tool/motion_trace.py --video clip.mp4 --roi 0.1 0.9 0.3 0.6

`--roi` is `LEFT RIGHT TOP BOTTOM` as fractions, and it matters more than
anything else here. Phase correlation finds the shift of the *whole*
profile, so a region that is mostly static — a desktop around a simulator
window, a page around a carousel — locks the correlation onto zero and
reports no motion at all. Crop to the thing that moves.

Where this method cannot be trusted
-----------------------------------
Phase correlation assumes the thing being tracked is distinctive. Two cases
break it, and both are visible in the output rather than silent:

- **Repeating content.** A carousel of near-identical cards is a periodic
  signal, and the correlation peak is ambiguous between one card-pitch and
  the next. It shows up as velocities that repeat an identical value, or
  drop to exactly zero, in the middle of a fast movement. Track something
  with a unique mark in it — a distinctive card, a cursor — or accept that
  only the slow tail of the motion is reliable.
- **Movement larger than half the region per frame**, which wraps.

Both are worst at the start of a fling, where the motion is fastest, and
both fade as it settles. When the fast frames look wrong and the tail looks
clean, measure the tail with `--frames` and say so.
"""

from __future__ import annotations

import argparse
import json
import math
import subprocess
import sys
from dataclasses import dataclass, asdict

import numpy as np


def timestamps(video: str) -> np.ndarray:
    """Presentation time of every video frame, in seconds."""
    out = subprocess.run(
        [
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "frame=best_effort_timestamp_time",
            "-of", "csv=p=0", video,
        ],
        capture_output=True, text=True, check=True,
    ).stdout
    times = []
    for line in out.splitlines():
        # csv=p=0 still emits a trailing comma when a frame carries only the
        # one requested field, so strip it before parsing.
        value = line.strip().rstrip(",").strip()
        if not value or value == "N/A":
            continue
        try:
            times.append(float(value))
        except ValueError:
            continue
    return np.array(times, dtype=np.float64)


def probe(video: str) -> tuple[int, int, float]:
    """Width, height and nominal frame rate, straight from the container."""
    out = subprocess.run(
        [
            "ffprobe", "-v", "error", "-select_streams", "v:0",
            "-show_entries", "stream=width,height,avg_frame_rate",
            "-of", "json", video,
        ],
        capture_output=True, text=True, check=True,
    ).stdout
    stream = json.loads(out)["streams"][0]
    num, _, den = stream["avg_frame_rate"].partition("/")
    fps = float(num) / float(den or 1)
    return int(stream["width"]), int(stream["height"]), fps


def frames(video: str, width: int, height: int) -> np.ndarray:
    """Every frame as grayscale, shape (n, height, width)."""
    raw = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", video,
            "-f", "rawvideo", "-pix_fmt", "gray", "-",
        ],
        capture_output=True, check=True,
    ).stdout
    per_frame = width * height
    count = len(raw) // per_frame
    if count == 0:
        raise SystemExit(
            f"{video} decoded to no frames. A recording of a static screen "
            f"can contain a single frame; check the clip plays."
        )
    return (
        np.frombuffer(raw[: count * per_frame], dtype=np.uint8)
        .reshape(count, height, width)
        .astype(np.float64)
    )


def crop(stack: np.ndarray, roi: tuple[float, float, float, float]) -> np.ndarray:
    """The region of interest, as `LEFT RIGHT TOP BOTTOM` fractions."""
    _, height, width = stack.shape
    x0 = max(0, min(width - 1, int(roi[0] * width)))
    x1 = max(x0 + 1, min(width, int(roi[1] * width)))
    y0 = max(0, min(height - 1, int(roi[2] * height)))
    y1 = max(y0 + 1, min(height, int(roi[3] * height)))
    return stack[:, y0:y1, x0:x1]


def profiles(region: np.ndarray, axis: str) -> np.ndarray:
    """Collapse each frame to a 1-D profile along `axis`."""
    # Averaging over the other axis is what turns a 2-D shift into a 1-D one.
    prof = region.mean(axis=1) if axis == "x" else region.mean(axis=2)
    # Remove each frame's own mean so overall brightness changes — a fade, a
    # shadow passing — cannot masquerade as a shift.
    return prof - prof.mean(axis=1, keepdims=True)


def shift_between(a: np.ndarray, b: np.ndarray) -> float:
    """Sub-pixel horizontal shift from `a` to `b`, by phase correlation."""
    n = a.size
    window = np.hanning(n)
    fa = np.fft.rfft(a * window)
    fb = np.fft.rfft(b * window)
    cross = fa.conj() * fb
    magnitude = np.abs(cross)
    # Normalising to unit magnitude is what makes this phase correlation:
    # the peak then depends on alignment alone, not on contrast. Divide only
    # where it is safe — `np.where` would evaluate the division everywhere
    # first and warn on the zeros.
    safe = magnitude > 1e-12
    cross = np.divide(cross, magnitude, out=np.zeros_like(cross), where=safe)
    corr = np.fft.irfft(cross, n)

    peak = int(np.argmax(corr))
    # Parabolic fit through the peak and its neighbours, for sub-pixel.
    left = corr[(peak - 1) % n]
    right = corr[(peak + 1) % n]
    centre = corr[peak]
    denom = left - 2 * centre + right
    offset = 0.0 if abs(denom) < 1e-12 else 0.5 * (left - right) / denom

    pos = peak + offset
    # irfft wraps, so a shift past halfway is really a negative shift.
    return pos - n if pos > n / 2 else pos


@dataclass
class Decay:
    axis: str
    fps: float
    frames_used: int
    peak_velocity_px_per_frame: float
    mean_ratio: float
    ratio_min: float
    ratio_max: float
    sigma_from_mean_ratio: float
    sigma_fitted: float
    r_squared: float
    reversed_sign: bool

    def report(self) -> str:
        return "\n".join([
            f"  axis                  {self.axis}",
            f"  sampling in the decay {self.fps:.1f} fps",
            f"  frames in the decay   {self.frames_used}",
            f"  peak velocity         "
            f"{self.peak_velocity_px_per_frame:.1f} px/s",
            f"  per-frame ratio       {self.ratio_min:.3f}-{self.ratio_max:.3f}"
            f"  (mean {self.mean_ratio:.3f})",
            f"  sigma from that ratio {self.sigma_from_mean_ratio:.2f}/s",
            f"  sigma, least squares  {self.sigma_fitted:.2f}/s"
            f"  (R^2 {self.r_squared:.4f})",
            f"  velocity sign flips   "
            f"{'yes - underdamped' if self.reversed_sign else 'no'}",
        ])


def _fit(segment: np.ndarray, t: np.ndarray) -> tuple[float, float]:
    """Least-squares `sigma` and R^2 for an exponential decay."""
    log_v = np.log(np.maximum(segment, 1e-9))
    slope, intercept = np.polyfit(t, log_v, 1)
    predicted = slope * t + intercept
    ss_res = float(((log_v - predicted) ** 2).sum())
    ss_tot = float(((log_v - log_v.mean()) ** 2).sum())
    r2 = 1 - ss_res / ss_tot if ss_tot > 0 else 0.0
    return -float(slope), r2


def analyse(velocity: np.ndarray, times: np.ndarray, floor: float,
            axis: str) -> Decay:
    """Fit the decay that follows the fastest frame in `velocity` (px/s).

    The fastest frame is the start, deliberately. Anything cleverer — a
    search over windows for the best-fitting exponential — drifts onto
    whatever in the clip happens to fit a line best, which on real footage
    is a scene cut or a long slow drift, not the gesture. Point `--roi` and
    `--frames` at the motion you mean and this will measure it; leave them
    wide and it will measure the loudest thing in shot.

    One caveat worth knowing before reading the number: a *driven* fling is
    two motions in a row — the pointer being dragged, then the spring
    settling after release — and the drag is usually faster. If the clip
    contains both, narrow `--frames` to the settle, or the fit spans both
    and the R^2 will say so.
    """
    speed = np.abs(velocity)
    start = int(np.argmax(speed))
    peak = speed[start]
    if peak <= floor:
        raise SystemExit(
            f"no motion above the {floor} px/s floor; widen --roi or check "
            f"the clip contains the gesture"
        )

    # The decay runs from the peak until the motion dies into the noise.
    #
    # A dip below the threshold does not end it. An underdamped spring
    # crosses zero on its way back, and stopping at the first quiet frame
    # cuts the segment to two samples and throws the decay away.
    threshold = max(floor, peak * 0.02)
    quiet_allowed = 3
    end = start + 1
    quiet = 0
    last_loud = start + 1
    while end < len(speed) and quiet <= quiet_allowed:
        if speed[end] > threshold:
            quiet = 0
            last_loud = end + 1
        else:
            quiet += 1
        end += 1
    end = last_loud

    segment = speed[start:end]
    t = times[start:end] - times[start]
    if len(segment) < 4:
        raise SystemExit(
            f"the decay is only {len(segment)} frames; a higher capture rate "
            f"is needed to say anything about its shape"
        )

    ratios = segment[1:] / np.maximum(segment[:-1], 1e-9)
    # Ratios at or above 1 are not decay: they are the gesture still
    # accelerating, or noise. They would drag the mean towards 1 and
    # understate sigma, so they are left out.
    usable = ratios[(ratios > 0) & (ratios < 1)]
    mean_ratio = float(usable.mean()) if usable.size else float("nan")
    dt = float(np.mean(np.diff(t))) if len(t) > 1 else 0.0

    log_v = np.log(np.maximum(segment, 1e-9))
    slope, intercept = np.polyfit(t, log_v, 1)
    predicted = slope * t + intercept
    ss_res = float(((log_v - predicted) ** 2).sum())
    ss_tot = float(((log_v - log_v.mean()) ** 2).sum())

    tail = velocity[start:end]
    leading = np.sign(tail[0])
    reversed_sign = bool((np.sign(tail) == -leading).any())

    return Decay(
        axis=axis,
        fps=1 / dt if dt > 0 else float("nan"),
        frames_used=len(segment),
        peak_velocity_px_per_frame=float(peak),
        mean_ratio=mean_ratio,
        ratio_min=float(usable.min()) if usable.size else float("nan"),
        ratio_max=float(usable.max()) if usable.size else float("nan"),
        sigma_from_mean_ratio=float(-math.log(mean_ratio) / dt)
        if usable.size and dt > 0 else float("nan"),
        sigma_fitted=float(-slope),
        r_squared=1 - ss_res / ss_tot if ss_tot > 0 else float("nan"),
        reversed_sign=reversed_sign,
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--video", required=True)
    p.add_argument("--roi", nargs=4, type=float, default=(0.0, 1.0, 0.0, 1.0),
                   metavar=("LEFT", "RIGHT", "TOP", "BOTTOM"),
                   help="region to measure, as fractions (default: all of it)")
    p.add_argument("--axis", choices=("x", "y", "auto"), default="auto",
                   help="which axis moved; 'auto' takes the larger motion")
    p.add_argument("--frames", nargs=2, type=int, default=None,
                   metavar=("FIRST", "LAST"),
                   help="limit to this frame range; use it to exclude what "
                        "happens around the gesture, such as a launch "
                        "transition or the app being torn down at the end")
    p.add_argument("--fps", type=float, default=None,
                   help="override the container's frame rate")
    p.add_argument("--floor", type=float, default=8.0,
                   help="px/s below which motion is treated as noise")
    p.add_argument("--json", default=None, help="also write the result here")
    args = p.parse_args()

    width, height, fps = probe(args.video)
    stack = frames(args.video, width, height)
    times_all = timestamps(args.video)
    if args.fps:
        times_all = np.arange(len(stack)) / args.fps
    elif len(times_all) < len(stack):
        # The raw decode can yield a frame or two more than ffprobe counts.
        # Trim the pixels to the timestamps rather than inventing times, so
        # every velocity is divided by a gap that really happened.
        stack = stack[: len(times_all)]
    times_all = times_all[: len(stack)]
    if args.frames:
        lo, hi = args.frames
        stack = stack[lo:hi]
        times_all = times_all[lo:hi]
    region = crop(stack, tuple(args.roi))

    times = times_all
    # Gaps between frames, floored so a duplicated timestamp cannot divide
    # a shift by zero and report an infinite velocity.
    gaps = np.maximum(np.diff(times), 1e-4)

    speeds = {}
    for axis in ("x", "y"):
        prof = profiles(region, axis)
        shifts = np.array(
            [shift_between(prof[i], prof[i + 1]) for i in range(len(prof) - 1)]
        )
        speeds[axis] = shifts / gaps[: len(shifts)]

    chosen = args.axis
    if chosen == "auto":
        chosen = max(speeds, key=lambda a: float(np.abs(speeds[a]).max()))

    print(f"{args.video}  {width}x{height}, {len(stack)} frames")
    print(f"  region                {region.shape[2]}x{region.shape[1]} px")
    for axis in ("x", "y"):
        print(f"  peak along {axis}          "
              f"{float(np.abs(speeds[axis]).max()):.1f} px/s"
              f"{'   <- measured' if axis == chosen else ''}")
    result = analyse(speeds[chosen], times[1:], args.floor, chosen)
    print(result.report())

    # The decay rate is a property of the motion, not of how often it was
    # sampled. Stating the equivalent per-frame ratio at 60fps makes this
    # comparable with a figure recorded from 60fps footage.
    r60 = math.exp(-result.sigma_fitted / 60)
    print(f"  equivalent ratio @60fps {r60:.3f}")

    if args.json:
        with open(args.json, "w") as f:
            json.dump(asdict(result), f, indent=2)
        print(f"  written to {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
