#!/usr/bin/env python3
"""Fix Rahmi file reference paths and attach them to the Hub group tree."""

from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "Hub.xcodeproj" / "project.pbxproj"
HUB_GROUP_ID = "A50000000000000000000002"

REF_RE = re.compile(
    r"(?P<id>[A-Z0-9]{24}) /\* (?P<name>[^*]+) \*/ = \{isa = PBXFileReference; "
    r"lastKnownFileType = (?P<type>[^;]+); path = (?P<path>[^;]+); sourceTree = \"<group>\"; \};"
)


def gid(key: str) -> str:
    return "G" + hashlib.md5(key.encode()).hexdigest()[:23].upper()


def label(file_id: str, refs: dict[str, dict[str, str]], group_meta: dict[str, tuple[str, str]]) -> str:
    if file_id in refs:
        return refs[file_id]["name"]
    if file_id in group_meta:
        return group_meta[file_id][0]
    return file_id


def main() -> None:
    text = PBX.read_text()

    if "/* Rahmi */" in text and "path = Rahmi/" in text and "Recovered" not in text:
        # Heuristic: already fixed if Rahmi group comment exists in groups
        pass

    text = text.replace("path = Hub/Rahmi/", "path = Rahmi/")
    text = text.replace("path = Hub/Shell/", "path = Shell/")
    text = text.replace("path = Hub/LaunchScreen.storyboard", "path = LaunchScreen.storyboard")
    text = text.replace("path = Hub/RahmiAssets.xcassets", "path = RahmiAssets.xcassets")

    refs: dict[str, dict[str, str]] = {}
    for m in REF_RE.finditer(text):
        refs[m.group("id")] = {
            "name": m.group("name"),
            "path": m.group("path"),
            "type": m.group("type"),
        }

    managed: dict[str, str] = {}
    for fid, ref in refs.items():
        p = ref["path"]
        if p.startswith("Rahmi/") or p.startswith("Shell/"):
            managed[p] = fid
        elif p in {"LaunchScreen.storyboard", "RahmiAssets.xcassets"}:
            managed[p] = fid

    if not managed:
        print("No Rahmi refs found")
        return

    group_children: dict[str, list[str]] = {}
    group_meta: dict[str, tuple[str, str]] = {}

    def ensure_group(rel_parts: list[str]) -> str:
        chain = "/".join(rel_parts)
        g = gid(f"group:{chain}")
        if g not in group_meta:
            group_meta[g] = (rel_parts[-1], rel_parts[-1])
            parent = HUB_GROUP_ID
            if len(rel_parts) > 1:
                parent = ensure_group(rel_parts[:-1])
            group_children.setdefault(parent, []).append(g)
        return g

    def attach_file(parent_gid: str, file_id: str) -> None:
        group_children.setdefault(parent_gid, []).append(file_id)

    top_level_files: list[str] = []
    hub_new_children: list[str] = []

    for rel_path, fid in sorted(managed.items()):
        parts = rel_path.split("/")
        if len(parts) == 1:
            top_level_files.append(fid)
            continue

        basename = parts[-1]
        parent_gid = ensure_group(parts[:-1])
        attach_file(parent_gid, fid)

        text = re.sub(
            rf"({re.escape(fid)} /\* [^*]+ \*/ = {{isa = PBXFileReference; lastKnownFileType = [^;]+; path = )[^;]+",
            rf"\g<1>{basename}",
            text,
            count=1,
        )

    for key in ("Rahmi", "Shell"):
        if any(p.startswith(f"{key}/") for p in managed):
            g = gid(f"group:{key}")
            if g not in group_meta:
                group_meta[g] = (key, key)
            if g not in hub_new_children:
                hub_new_children.append(g)

    for fid in top_level_files:
        hub_new_children.append(fid)

    if "/* Rahmi */" not in text:
        group_lines: list[str] = []
        for g, (name, path) in sorted(group_meta.items(), key=lambda x: x[0]):
            kids = group_children.get(g, [])
            children_block = "\n".join(
                f"\t\t\t\t{k} /* {label(k, refs, group_meta)} */," for k in kids
            )
            group_lines.append(
                f"\t\t{g} /* {name} */ = {{\n"
                f"\t\t\tisa = PBXGroup;\n"
                f"\t\t\tchildren = (\n{children_block}\n"
                f"\t\t\t);\n"
                f"\t\t\tpath = {path};\n"
                f"\t\t\tsourceTree = \"<group>\";\n"
                f"\t\t}};"
            )
        text = text.replace(
            "/* End PBXGroup section */",
            "\n".join(group_lines) + "\n/* End PBXGroup section */",
        )

    hub_pattern = re.compile(
        rf"({HUB_GROUP_ID} /\* Hub \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \()(.*?)(\n\t\t\t\);)",
        re.DOTALL,
    )
    m = hub_pattern.search(text)
    if not m:
        raise SystemExit("Hub group not found")

    existing = m.group(2)
    additions = []
    for item in hub_new_children:
        if item not in existing:
            additions.append(f"\t\t\t\t{item} /* {label(item, refs, group_meta)} */,")
    if additions:
        new_children = existing + "\n" + "\n".join(additions)
        text = text[:m.start(2)] + new_children + text[m.end(2):]

    PBX.write_text(text)
    print(f"Fixed {len(managed)} references, {len(group_meta)} folder groups")


if __name__ == "__main__":
    main()
