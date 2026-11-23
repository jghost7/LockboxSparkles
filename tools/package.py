"""Build a CurseForge-ready zip of LockboxSparkles.

    python tools/package.py                 # package current version from TOC
    python tools/package.py --bump patch    # 1.0.0 -> 1.0.1, then package
    python tools/package.py --version 1.1.0
    python tools/package.py --skip-tests
"""
import argparse
import pathlib
import re
import subprocess
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "LockboxSparkles"
TOC = ADDON / "LockboxSparkles.toc"
CHANGELOG = ADDON / "CHANGELOG.md"
LICENSE = ROOT / "LICENSE"
DIST = ROOT / "dist"
SHIP_EXTS = {".lua", ".toc", ".xml", ".tga", ".blp", ".txt", ".md"}


def fail(msg):
    print("PACKAGE FAILED:", msg)
    sys.exit(1)


def current_version(text):
    m = re.search(r"^## Version:\s*(\S+)\s*$", text, re.M)
    if not m:
        fail("LockboxSparkles.toc has no '## Version:' line")
    return m.group(1)


def bumped(version, part):
    nums = [int(n) for n in version.split(".")]
    while len(nums) < 3:
        nums.append(0)
    idx = {"major": 0, "minor": 1, "patch": 2}[part]
    nums[idx] += 1
    for j in range(idx + 1, 3):
        nums[j] = 0
    return ".".join(map(str, nums))


def run_tests():
    print("Running unit tests...")
    r = subprocess.run(
        [sys.executable, str(ROOT / "tests" / "run.py")],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    output = (r.stdout + r.stderr).strip()
    if output:
        print(" ", output)
    if r.returncode != 0:
        fail("Unit tests failed")


def toc_files():
    out = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line.replace("\\", "/"))
    return out


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--bump", choices=("patch", "minor", "major"))
    g.add_argument("--version")
    ap.add_argument("--skip-tests", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    toc_text = TOC.read_text(encoding="utf-8")
    old = current_version(toc_text)
    new = args.version or (bumped(old, args.bump) if args.bump else old)
    if not re.fullmatch(r"\d+\.\d+\.\d+", new):
        fail(f"Version '{new}' must match N.N.N")

    out = DIST / f"LockboxSparkles-{new}.zip"
    if out.exists() and not args.force:
        fail(f"{out.name} already exists (bump version or pass --force)")

    if not args.skip_tests:
        run_tests()

    if new != old:
        TOC.write_text(
            re.sub(r"^## Version:.*$", f"## Version: {new}", toc_text, count=1, flags=re.M),
            encoding="utf-8",
        )
        print(f"Updated version {old} -> {new} in LockboxSparkles.toc")

    DIST.mkdir(exist_ok=True)
    files = sorted(
        p
        for p in ADDON.rglob("*")
        if p.is_file()
        and p.suffix.lower() in SHIP_EXTS
        and not any(part.startswith(".") for part in p.relative_to(ADDON).parts)
    )

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in files:
            z.write(p, "LockboxSparkles/" + p.relative_to(ADDON).as_posix())
        if LICENSE.exists():
            z.write(LICENSE, "LockboxSparkles/LICENSE.txt")

    # Verify zip contents
    with zipfile.ZipFile(out, "r") as z:
        names = set(z.namelist())
        for rel in toc_files():
            expected = f"LockboxSparkles/{rel}"
            if expected not in names:
                fail(f"Missing TOC file in zip: {expected}")
        for asset in ("sparkle_star.tga", "sparkle_glow.tga", "sparkle_dot.tga"):
            expected = f"LockboxSparkles/Media/{asset}"
            if expected not in names:
                fail(f"Missing media asset in zip: {expected}")

    print(f"Built {out} ({out.stat().st_size:,} bytes, {len(names)} files)")


if __name__ == "__main__":
    main()
