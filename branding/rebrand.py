#!/usr/bin/env python3
"""Rebrand an upstream Mattermost tree as Mattermax.

    rebrand.py list  TREE                 regenerate branding/files.list
    rebrand.py apply TREE [--report FILE] rebrand TREE in place

Text: every rule in rules.json is applied to the in-scope text files, except
occurrences covered by an allowlist.json entry. Assets: every file under
branding/assets/ replaces the file at the same path in TREE, and must keep
its format (and pixel size, for PNG).

`apply` refuses to run if files.list doesn't match the files the rules would
change, so new upstream strings are always reviewed (`just branding-files`).
Run it on an unbranded copy only; work/src is never branded.

Python standard library only.
"""

import argparse
import json
import os
import re
import shutil
import struct
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RULES = HERE / "rules.json"
ALLOWLIST = HERE / "allowlist.json"
FILES_LIST = HERE / "files.list"
ASSETS = HERE / "assets"
SKIP_DIRS = {".git", "node_modules"}


def glob_re(pattern):
    """Translate a path glob (** crosses directories, * doesn't) to a regex."""
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


class Globs:
    def __init__(self, patterns):
        self.res = [glob_re(p) for p in patterns]

    def match(self, path):
        return any(r.match(path) for r in self.res)


class Branding:
    def __init__(self):
        rules = json.loads(RULES.read_text())
        self.include = Globs(rules["include"])
        self.exclude = Globs(rules["exclude"])
        self.icons = Globs(rules["icons"])
        self.rules = [
            dict(r, re=re.compile(r["find"]), only=Globs(r.get("files", ["**"])))
            for r in rules["replace"]
        ]
        self.allow = [
            dict(a, re=re.compile(a["match"]), only=Globs(a.get("files", ["**"])))
            for a in json.loads(ALLOWLIST.read_text())
        ]
        self._cache = {}

    def in_scope(self, path):
        return self.include.match(path) and not self.exclude.match(path)

    def for_file(self, path):
        """The combined rule regex and allowlist that apply to one file."""
        rules = tuple(i for i, r in enumerate(self.rules) if r["only"].match(path))
        allow = tuple(i for i, a in enumerate(self.allow) if a["only"].match(path))
        key = (rules, allow)
        if key not in self._cache:
            combined = None
            if rules:
                # One alternation, in rule order: at any position the earlier
                # (more specific) rule wins, and each occurrence counts once.
                combined = re.compile(
                    "|".join(f"(?P<r{i}>{self.rules[i]['find']})" for i in rules)
                )
            self._cache[key] = (combined, [self.allow[i] for i in allow])
        return self._cache[key]

    def rebrand_text(self, path, text, stats):
        combined, allow = self.for_file(path)
        if combined is None or not combined.search(text):
            return text
        out = []
        for line in text.splitlines(keepends=True):
            if not combined.search(line):
                out.append(line)
                continue
            spans = [(m.start(), m.end(), a["id"]) for a in allow for m in a["re"].finditer(line)]

            def sub(m):
                for s, e, aid in spans:
                    if s <= m.start() and m.end() <= e:
                        stats.kept(path, aid)
                        return m.group(0)
                rule = self.rules[int(m.lastgroup[1:])]
                stats.replaced(path, rule["id"])
                return rule["replace"]

            out.append(combined.sub(sub, line))
        return "".join(out)


class Stats:
    def __init__(self):
        self.by_rule, self.by_allow, self.by_file = {}, {}, {}

    def replaced(self, path, rid):
        self.by_rule[rid] = self.by_rule.get(rid, 0) + 1
        self.by_file.setdefault(path, [0, 0])[0] += 1

    def kept(self, path, aid):
        self.by_allow[aid] = self.by_allow.get(aid, 0) + 1
        self.by_file.setdefault(path, [0, 0])[1] += 1


def walk(tree):
    for dirpath, dirnames, filenames in os.walk(tree):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            full = Path(dirpath) / name
            if full.is_file() and not full.is_symlink():
                yield full.relative_to(tree).as_posix(), full


def read_text(full):
    data = full.read_bytes()
    if b"\0" in data[:8192]:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def scan(branding, tree):
    """Rebrand every in-scope file in memory. Returns ({path: new text}, stats)."""
    stats, changed = Stats(), {}
    for path, full in walk(tree):
        if not branding.in_scope(path):
            continue
        text = read_text(full)
        if text is None:
            continue
        new = branding.rebrand_text(path, text, stats)
        if new != text:
            changed[path] = new
    return changed, stats


# --- assets ----------------------------------------------------------------

MAGIC = {
    ".png": b"\x89PNG\r\n\x1a\n",
    ".ico": b"\x00\x00\x01\x00",
    ".jpg": b"\xff\xd8\xff",
    ".jpeg": b"\xff\xd8\xff",
    ".gif": b"GIF8",
}


def png_size(data):
    return struct.unpack(">II", data[16:24])


def asset_files():
    if not ASSETS.is_dir():
        return []
    return [(p, f) for p, f in walk(ASSETS) if not p.endswith(".gitkeep")]


def check_assets(tree):
    errors = []
    for path, src in asset_files():
        dst = tree / path
        if not dst.is_file():
            errors.append(f"assets/{path}: no such file upstream (renamed or removed?)")
            continue
        new, old = src.read_bytes(), dst.read_bytes()
        magic = MAGIC.get(src.suffix.lower())
        if magic and not (new.startswith(magic) and old.startswith(magic)):
            errors.append(f"assets/{path}: format differs from upstream {src.suffix} file")
        elif src.suffix.lower() == ".png" and png_size(new) != png_size(old):
            errors.append(
                "assets/{}: {}x{} px, upstream is {}x{} px".format(path, *png_size(new), *png_size(old))
            )
    return errors


# --- commands --------------------------------------------------------------


def read_list():
    if not FILES_LIST.exists():
        return []
    return [l for l in FILES_LIST.read_text().splitlines() if l and not l.startswith("#")]


def cmd_list(branding, tree):
    changed, _ = scan(branding, tree)
    FILES_LIST.write_text("".join(p + "\n" for p in sorted(changed)))
    print(f"files.list: {len(changed)} files", file=sys.stderr)


def cmd_apply(branding, tree, report):
    changed, stats = scan(branding, tree)
    want, got = set(read_list()), set(changed)
    if want != got:
        for p in sorted(got - want)[:20]:
            print(f"  new: {p}", file=sys.stderr)
        for p in sorted(want - got)[:20]:
            print(f"  gone: {p}", file=sys.stderr)
        sys.exit(
            f"error: branding/files.list is out of date ({len(got - want)} new, {len(want - got)} gone).\n"
            "Run 'just branding-files' and review the diff. (Is the tree already branded?)"
        )
    errors = check_assets(tree)
    if errors:
        sys.exit("error: bad assets:\n  " + "\n  ".join(errors))

    for path, text in changed.items():
        (tree / path).write_bytes(text.encode("utf-8"))
    assets = asset_files()
    for path, src in assets:
        shutil.copyfile(src, tree / path)

    if report:
        write_report(branding, tree, stats, assets, Path(report))
    total = sum(stats.by_rule.values())
    print(f"rebranded {len(changed)} files ({total} replacements), {len(assets)} assets", file=sys.stderr)


def write_report(branding, tree, stats, assets, out):
    replaced_assets = {p for p, _ in assets}
    icons_left = [p for p, _ in walk(tree) if branding.icons.match(p) and p not in replaced_assets]
    reasons = {a["id"]: a["reason"] for a in branding.allow}
    L = ["# Branding report", "", "Generated by `just build`. Do not edit.", ""]
    L += ["## Replacements", "", "| Rule | Replace with | Count |", "| --- | --- | ---: |"]
    for r in branding.rules:
        L.append(f"| `{r['id']}` | {r['replace']} | {stats.by_rule.get(r['id'], 0)} |")
    L += ["", "## Kept on purpose", "", "| Allowlist entry | Reason | Count |", "| --- | --- | ---: |"]
    for a in branding.allow:
        L.append(f"| `{a['id']}` | {reasons[a['id']]} | {stats.by_allow.get(a['id'], 0)} |")
    L += ["", f"## Assets replaced ({len(assets)})", ""]
    L += [f"- `{p}`" for p, _ in assets] or ["None yet."]
    L += ["", f"## Icons still showing the upstream logo ({len(icons_left)})", ""]
    L += [f"- `{p}`" for p in icons_left] or ["None."]
    L += ["", f"## Files ({len(stats.by_file)})", "", "| File | Replaced | Kept |", "| --- | ---: | ---: |"]
    for p in sorted(stats.by_file):
        r, k = stats.by_file[p]
        L.append(f"| `{p}` | {r} | {k} |")
    out.write_text("\n".join(L) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("command", choices=["list", "apply"])
    ap.add_argument("tree", type=Path)
    ap.add_argument("--report", help="write the branding report here (apply only)")
    args = ap.parse_args()
    tree = args.tree.resolve()
    if not (tree / "server").is_dir() or not (tree / "webapp").is_dir():
        sys.exit(f"error: {tree} doesn't look like an upstream tree")
    branding = Branding()
    if args.command == "list":
        cmd_list(branding, tree)
    else:
        cmd_apply(branding, tree, args.report)


if __name__ == "__main__":
    main()
