#!/usr/bin/env python3
"""Copy src/ and the harness tests into a temp dir, prepending a header that injects the mock Roblox globals and a
mock `script` / `require` into every file (the plain Luau CLI has no Roblox globals and no shared global env)."""
import os, sys, json
src, harness, out = sys.argv[1:4]
GLOBALS = ("game, workspace, Instance, Enum, Vector3, Vector2, CFrame, Color3, UDim, UDim2, NumberRange, NumberSequence, "
           "NumberSequenceKeypoint, ColorSequence, ColorSequenceKeypoint, TweenInfo, Region3, Random, RaycastParams, task, os, typeof, warn")
def header(rel, path):
    return ("local __real = require; local __M = __real('%s__mock'); "
            "local require = function(x) if type(x) == 'string' then return __real(x) else return __M.require(x) end end; "
            "local script = __M.scriptFor('%s'); "
            "local %s = %s\n") % (rel, path, GLOBALS, ", ".join("__M.G." + g.strip() for g in GLOBALS.split(",")))
registry = []
for root in ("shared", "server", "client"):
    base = os.path.join(src, root)
    for dp, dn, fn in os.walk(base):
        for f in fn:
            if not f.endswith(".luau"): continue
            full = os.path.join(dp, f)
            rel_to_root = os.path.relpath(full, src)               # shared/Config.luau
            if f.endswith(".server.luau"): cls, name = "Script", f[:-12]
            elif f.endswith(".client.luau"): cls, name = "LocalScript", f[:-12]
            else: cls, name = "ModuleScript", f[:-5]
            parts = rel_to_root.split(os.sep)
            path = "/".join(parts[:-1] + [name])
            depth = len(parts) - 1
            rel = "../" * depth if depth else "./"
            dest = os.path.join(out, *parts[:-1], name + ".luau")
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            code = open(full, encoding="utf-8").read()
            if code.startswith("--!"):
                first, code = code.split("\n", 1)
                code = first + "\n" + code
            if cls in ("Script", "LocalScript"):
                # entry scripts run as their own thread in Roblox; expose them as a function the test can spawn
                code = "return function()\n" + code + "\nend\n"
            open(dest, "w", encoding="utf-8").write(header(rel, path) + code)
            registry.append((path, cls))
reg = ["return function(M)"]
for path, cls in sorted(registry):
    reg.append("\tM.registerFile(%r, %r)" % (path, cls))
reg.append("end")
open(os.path.join(out, "__registry.luau"), "w").write("\n".join(reg).replace("'", '"'))
os.rename(os.path.join(out, "mock.luau"), os.path.join(out, "__mock.luau"))
for f in os.listdir(harness):
    if f.endswith("_test.luau"):
        code = open(os.path.join(harness, f), encoding="utf-8").read()
        h = ("local __real = require; local __M = __real('./__mock'); __real('./__registry')(__M)\n"
             "local require = function(x) if type(x) == 'string' then return __real(x) else return __M.require(x) end end\n"
             "local %s = %s\n") % (GLOBALS, ", ".join("__M.G." + g.strip() for g in GLOBALS.split(",")))
        open(os.path.join(out, f), "w", encoding="utf-8").write(h + "local __M = __M\n__M.run(function()\n" + code + "\nend)\n")
