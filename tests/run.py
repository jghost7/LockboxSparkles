"""Run LockboxSparkles headless under Lua 5.1 (lupa) with a WoW 1.60.1 API mock.

    python tests/run.py

Exits with code 0 when all assertions pass, non-zero otherwise.
"""
import pathlib
import sys

from lupa import lua51

ROOT = pathlib.Path(__file__).resolve().parent.parent
ADDON = ROOT / "LockboxSparkles"
TOC = ADDON / "LockboxSparkles.toc"
TEST_LUA = ROOT / "tests" / "test_lockbox_sparkles.lua"


def toc_lua_files():
    out = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            out.append(ADDON / line.replace("\\", "/"))
    return out


def verify_media_assets():
    expected = ["sparkle_star.tga", "sparkle_glow.tga", "sparkle_dot.tga"]
    media_dir = ADDON / "Media"
    for name in expected:
        p = media_dir / name
        if not p.exists() or p.stat().st_size == 0:
            raise AssertionError(f"Missing or empty media asset: {p}")


def main():
    verify_media_assets()

    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    # Build mock environment & test runner
    test_src = TEST_LUA.read_text(encoding="utf-8")
    load_fn = lua.eval(
        """function(chunk, name, addonName, ns)
            local fn, err = loadstring(chunk, name)
            if not fn then error(err) end
            return fn(addonName, ns)
        end"""
    )

    # First run test harness setup (defines MOCK and WoW globals)
    setup_fn = lua.eval(
        """function(chunk, name)
            local fn, err = loadstring(chunk, name)
            if not fn then error(err) end
            return fn()
        end"""
    )
    run_suite = setup_fn(test_src, "@test_lockbox_sparkles.lua")

    # Load all addon files strictly in TOC order, sharing addon namespace table
    ns = lua.table()
    files = toc_lua_files()
    assert files, "No Lua files listed in LockboxSparkles.toc"
    for path in files:
        load_fn(path.read_text(encoding="utf-8"), "@" + path.name, "LockboxSparkles", ns)

    passed, failed = run_suite(ns)
    print(f"LockboxSparkles tests: {passed} passed, {failed} failed ({len(files)} Lua files loaded)")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
