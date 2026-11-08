#!/usr/bin/env python3
"""Capture every screen of the app on an iOS simulator.

    python3 tool/screenshots.py --sim <udid>            # capture + process
    python3 tool/screenshots.py --sim <udid> --only home,cards
    python3 tool/screenshots.py --process-only          # re-frame raw shots

For each shot it builds the app with that shot's launch hooks (see the
table in CLAUDE.md), installs it, writes the auth stage and theme straight
into the app's stored preferences, launches, waits for the splash and the
screen's entrance, and screenshots. Builds are shared between shots with
the same hooks. The status bar is pinned to 9:41 / full battery.

Raw captures go to build/screenshots/ (full resolution, not committed).
Processed copies — downscaled, corners rounded like the device screen —
go to docs/screenshots/ for the README, plus docs/hero.png.

Requires Xcode, Flutter and Pillow.
"""
from __future__ import annotations

import argparse
import json
import plistlib
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "build" / "screenshots"
OUT = ROOT / "docs" / "screenshots"
BUNDLE = "dev.strata.strata"
SETTLE = 6.5  # seconds: splash (~3.2s) + first screen's entrance + margin

# name, launch hooks, auth stage, theme
SHOTS: list[tuple[str, dict[str, str], str, str]] = [
    ("onboarding-1", {}, "onboarding", "light"),
    ("onboarding-2", {"startSlide": "1"}, "onboarding", "light"),
    ("onboarding-3", {"startSlide": "2"}, "onboarding", "light"),
    ("sign-in", {}, "signedOut", "light"),
    ("sign-up", {"startAuthStep": "signUp"}, "signedOut", "light"),
    ("forgot-password", {"startAuthStep": "forgot"}, "signedOut", "light"),
    ("verify-code", {"startAuthStep": "otp"}, "signedOut", "light"),
    ("create-pin", {}, "needsPin", "light"),
    ("home", {}, "signedIn", "light"),
    ("wallet", {"startTab": "1"}, "signedIn", "light"),
    ("cards-carousel", {"startTab": "1", "startLayout": "0"}, "signedIn", "light"),
    ("add-card", {"startRoute": "/add-card"}, "signedIn", "light"),
    ("send", {"startRoute": "/send"}, "signedIn", "light"),
    ("convert", {"startRoute": "/convert"}, "signedIn", "light"),
    ("activity", {"startRoute": "/transactions"}, "signedIn", "light"),
    ("activity-filter",
     {"startRoute": "/transactions", "startFilter": "true"}, "signedIn", "light"),
    ("notifications", {"startSheet": "notifications"}, "signedIn", "light"),
    ("profile", {"startTab": "2"}, "signedIn", "light"),
    ("demo-settings", {"startSheet": "demo"}, "signedIn", "light"),
    ("sign-in-dark", {}, "signedOut", "dark"),
    ("home-dark", {}, "signedIn", "dark"),
    ("cards-carousel-dark",
     {"startTab": "1", "startLayout": "0"}, "signedIn", "dark"),
    ("profile-dark", {"startTab": "2"}, "signedIn", "dark"),
]


def sh(*args: str, check: bool = True, quiet: bool = False) -> str:
    r = subprocess.run(args, capture_output=True, text=True)
    if check and r.returncode != 0:
        sys.exit(f"failed: {' '.join(args)}\n{r.stderr}")
    if not quiet and r.stdout.strip():
        print(r.stdout.strip().splitlines()[-1])
    return r.stdout


def build(defines: dict[str, str]):
    args = ["flutter", "build", "ios", "--simulator", "--debug",
            "--dart-define=hideDemoControl=true"]
    args += [f"--dart-define={k}={v}" for k, v in sorted(defines.items())]
    print(f"build {defines or '(no hooks)'}")
    subprocess.run(args, cwd=ROOT, check=True, capture_output=True)


def prefs_path(sim: str) -> Path | None:
    base = Path.home() / f"Library/Developer/CoreSimulator/Devices/{sim}/data/Containers/Data/Application"
    hits = list(base.glob(f"*/Library/Preferences/{BUNDLE}.plist"))
    return hits[0] if hits else None


def set_state(sim: str, stage: str, theme: str):
    """Write the auth stage and theme into the app's stored preferences."""
    sh("xcrun", "simctl", "spawn", sim, "killall", "cfprefsd", check=False, quiet=True)
    path = prefs_path(sim)
    if path is None:
        sys.exit("no preferences yet — launch the app once first")
    d = plistlib.load(open(path, "rb"))
    d["flutter.strata.auth.stage.v1"] = stage
    profile = json.loads(d.get("flutter.strata.profile.v1", "{}"))
    if profile:
        profile["themeMode"] = theme
        profile["showDemoHints"] = True
        d["flutter.strata.profile.v1"] = json.dumps(profile)
    plistlib.dump(d, open(path, "wb"))
    sh("xcrun", "simctl", "spawn", sim, "killall", "cfprefsd", check=False, quiet=True)


def install_and_seed(sim: str):
    """Fresh install, one launch so every store writes its seed."""
    sh("xcrun", "simctl", "uninstall", sim, BUNDLE, check=False, quiet=True)
    sh("xcrun", "simctl", "install", sim,
       str(ROOT / "build/ios/iphonesimulator/Runner.app"), quiet=True)
    sh("xcrun", "simctl", "launch", sim, BUNDLE, quiet=True)
    time.sleep(SETTLE)
    # Walk past onboarding once so the wallet and activity stores seed too.
    sh("xcrun", "simctl", "terminate", sim, BUNDLE, check=False, quiet=True)
    time.sleep(1)
    set_state(sim, "signedIn", "light")
    sh("xcrun", "simctl", "launch", sim, BUNDLE, quiet=True)
    time.sleep(SETTLE)


def capture(sim: str, only: set[str] | None):
    RAW.mkdir(parents=True, exist_ok=True)
    sh("xcrun", "simctl", "status_bar", sim, "override", "--time", "9:41",
       "--batteryState", "charged", "--batteryLevel", "100",
       "--wifiBars", "3", "--cellularMode", "active", "--cellularBars", "4",
       quiet=True)

    shots = [s for s in SHOTS if not only or s[0] in only]
    groups: dict[tuple, list] = {}
    for shot in shots:
        groups.setdefault(tuple(sorted(shot[1].items())), []).append(shot)

    seeded = False
    for key, group in groups.items():
        build(dict(key))
        if not seeded:
            install_and_seed(sim)
            seeded = True
        else:
            sh("xcrun", "simctl", "terminate", sim, BUNDLE, check=False, quiet=True)
            sh("xcrun", "simctl", "install", sim,
               str(ROOT / "build/ios/iphonesimulator/Runner.app"), quiet=True)
        for name, _, stage, theme in group:
            sh("xcrun", "simctl", "terminate", sim, BUNDLE, check=False, quiet=True)
            time.sleep(0.8)
            sh("xcrun", "simctl", "ui", sim, "appearance", theme, quiet=True)
            set_state(sim, stage, theme)
            sh("xcrun", "simctl", "launch", sim, BUNDLE, quiet=True)
            time.sleep(SETTLE)
            sh("xcrun", "simctl", "io", sim, "screenshot", str(RAW / f"{name}.png"),
               quiet=True)
            print(f"  captured {name}")

    # Leave the simulator as it was found: light, signed in, normal build.
    sh("xcrun", "simctl", "status_bar", sim, "clear", check=False, quiet=True)
    sh("xcrun", "simctl", "ui", sim, "appearance", "light", quiet=True)


# ------------------------------------------------------------- processing
def rounded(img, radius_frac: float = 0.125):
    from PIL import Image, ImageDraw
    w, h = img.size
    ss = 3
    mask = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, w * ss - 1, h * ss - 1), radius=w * ss * radius_frac, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask.resize((w, h), Image.LANCZOS))
    return out


def process(width: int = 600):
    from PIL import Image
    OUT.mkdir(parents=True, exist_ok=True)
    for raw in sorted(RAW.glob("*.png")):
        img = Image.open(raw)
        h = round(img.height * width / img.width)
        small = img.convert("RGB").resize((width, h), Image.LANCZOS)
        rounded(small).save(OUT / raw.name, optimize=True)
    hero()
    print(f"processed {len(list(OUT.glob('*.png')))} screenshots into {OUT}")


def hero():
    """A row of five phones on the paper colour, for the top of the README."""
    from PIL import Image, ImageDraw, ImageFilter
    names = ["onboarding-1", "sign-in", "home", "cards-carousel", "home-dark"]
    paths = [RAW / f"{n}.png" for n in names]
    if not all(p.exists() for p in paths):
        return
    W, H = 2400, 1180
    paper = (0xF4, 0xF3, 0xEE)
    canvas = Image.new("RGBA", (W, H), paper + (255,))
    phone_w = 400
    gap = 52
    total = len(paths) * phone_w + (len(paths) - 1) * gap
    x0 = (W - total) // 2
    for i, p in enumerate(paths):
        img = Image.open(p).convert("RGB")
        ph = round(img.height * phone_w / img.width)
        shot = rounded(img.resize((phone_w, ph), Image.LANCZOS))
        # Middle phone sits highest; the row arcs gently down to the ends.
        lift = [70, 34, 0, 34, 70][i]
        x, y = x0 + i * (phone_w + gap), (H - ph) // 2 + lift
        shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        shadow.paste((27, 32, 25, 70), (x + 6, y + 26, x + phone_w + 6, y + ph + 26),
                     mask=shot.split()[3])
        canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
        canvas.alpha_composite(shot, (x, y))
        # A hairline edge, so a light screen does not dissolve into the
        # paper behind it.
        edge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(edge).rounded_rectangle(
            (x, y, x + phone_w - 1, y + ph - 1), radius=phone_w * 0.125,
            outline=(27, 32, 25, 38), width=2)
        canvas.alpha_composite(edge)
    canvas.convert("RGB").save(ROOT / "docs" / "hero.png", optimize=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sim", help="simulator UDID (see `xcrun simctl list devices`)")
    ap.add_argument("--only", help="comma-separated shot names")
    ap.add_argument("--process-only", action="store_true")
    a = ap.parse_args()
    if not a.process_only:
        if not a.sim:
            ap.error("--sim is required unless --process-only")
        capture(a.sim, set(a.only.split(",")) if a.only else None)
    process()


if __name__ == "__main__":
    main()
