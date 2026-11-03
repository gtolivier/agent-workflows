# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml"]
# ///
"""Change a project-init register (.project-init.yml) in place.

Usage: uv run --quiet --script register-edit.py <file> <op>...

Operations, applied in order; KEY is dotted (host.required-checks), JSON a
JSON value:
  load JSON            replace the whole register (a new one: init-repo)
  set KEY JSON         set a value
  delete KEY           remove a key
  add KEY JSON         append to a list, unless already there
  remove KEY JSON      remove from a list
  deviation PATH JSON  record the deviation of a file: JSON holds its
                       status, reason and, if any, until or issue; null
                       forgets it

The file is written back in the register's own layout: the comment lines
at its top, one line per value, scalars as JSON but for the bare words of
PLAIN. Other scripts read some
lines as text: "kind: workspace", 'stack: "hugo"', "  tdd: true".
"""

import json
import re
import sys

import yaml

ORDER = ["project-init", "kind", "name", "stack", "description", "choices", "host", "managed", "deviations"]
HEADERS = {
    "repo": [
        "# project-init register: the version that set this repository up, the",
        "# choices made, and the files it manages. Read by project-init's scripts;",
        '# record deviations from the common layer under "deviations".',
    ],
    "workspace": [
        "# project-init register: the version that set this workspace up and the",
        "# choices made. Read by project-init's scripts; record deviations from the",
        '# common layer under "deviations".',
    ],
}
SIMPLE_KEY = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*$")
# Values written as bare words, as init-repo and init-workspace write them.
PLAIN = {"kind", "host.squash-body"}


def key(k):
    return k if SIMPLE_KEY.match(k) else json.dumps(k)


def flow(v):
    if isinstance(v, dict):
        return "{" + ", ".join(f"{key(k)}: {flow(x)}" for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + ", ".join(flow(x) for x in v) + "]"
    return json.dumps(v, ensure_ascii=False)


def value(dotted, v):
    if dotted in PLAIN and isinstance(v, str) and SIMPLE_KEY.match(v):
        return v
    return flow(v)


def emit(data):
    lines = []
    ordered = sorted(data, key=lambda k: ORDER.index(k) if k in ORDER else len(ORDER))
    for k in ordered:
        v = data[k]
        if isinstance(v, dict) and v:
            lines.append(f"{key(k)}:")
            lines += [f"  {key(sub)}: {value(f'{k}.{sub}', x)}" for sub, x in v.items()]
        elif isinstance(v, list) and any(isinstance(x, dict) for x in v):
            lines.append(f"{key(k)}:")
            lines += [f"  - {flow(x)}" for x in v]
        else:
            lines.append(f"{key(k)}: {value(k, v)}")
    return lines


def walk(data, dotted, create):
    *parents, last = dotted.split(".")
    node = data
    for p in parents:
        if p not in node and create:
            node[p] = {}
        node = node[p]
    return node, last


def apply(data, op, args):
    if op == "load":
        data.clear()
        data.update(json.loads(args[0]))
    elif op == "set":
        node, last = walk(data, args[0], True)
        node[last] = json.loads(args[1])
    elif op == "delete":
        node, last = walk(data, args[0], False)
        node.pop(last, None)
    elif op in ("add", "remove"):
        node, last = walk(data, args[0], op == "add")
        items = node.setdefault(last, []) if op == "add" else node.get(last, [])
        value = json.loads(args[1])
        if op == "add" and value not in items:
            items.append(value)
        while op == "remove" and value in items:
            items.remove(value)
    elif op == "deviation":
        path, value = args[0], json.loads(args[1])
        entries = [d for d in data.get("deviations") or [] if d.get("path") != path]
        if value is not None:
            entries.append({"path": path, **value})
            entries.sort(key=lambda d: d["path"])
        data["deviations"] = entries
    else:
        sys.exit(f"register-edit: unknown operation '{op}'")


ARITY = {"load": 1, "set": 2, "delete": 1, "add": 2, "remove": 2, "deviation": 2}


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path, ops = sys.argv[1], sys.argv[2:]
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        text = ""
    data = yaml.safe_load(text) or {}
    header = []
    for line in text.splitlines():
        if not line.startswith("#"):
            break
        header.append(line)
    while ops:
        op = ops[0]
        n = ARITY.get(op)
        if n is None or len(ops) < n + 1:
            sys.exit(f"register-edit: '{op}' takes {n} arguments" if n else f"register-edit: unknown operation '{op}'")
        apply(data, op, ops[1 : n + 1])
        ops = ops[n + 1 :]
    if not header:
        header = HEADERS.get(data.get("kind"), [])
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(header + emit(data)) + "\n")


main()
