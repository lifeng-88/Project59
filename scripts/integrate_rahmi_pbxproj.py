#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = ROOT / "Hub.xcodeproj" / "project.pbxproj"


def uid(seed: str) -> str:
    return "R" + hashlib.md5(seed.encode()).hexdigest()[:23].upper()


def rel_hub(path: Path) -> str:
    return path.relative_to(ROOT / "Hub").as_posix()


swift_files = sorted((ROOT / "Hub" / "Rahmi").rglob("*.swift"))
swift_files += sorted((ROOT / "Hub" / "Shell").rglob("*.swift"))

resources = [
    # Rahmi 位图已合并进 Hub/Assets.xcassets；同步请运行 scripts/sync_rahmi_assets.sh
    (ROOT / "Hub" / "Rahmi" / "Localizable.xcstrings", "text.json.xcstrings"),
    (ROOT / "Hub" / "Rahmi" / "LaunchScreen.storyboard", "file.storyboard"),
    (ROOT / "Hub" / "Rahmi" / "Config" / "IAP.storekit", "text"),
]

text = PBX.read_text()
if "RahmiRootContentView.swift in Sources" in text:
    print("Rahmi already in pbxproj")
    raise SystemExit(0)

build_lines = []
ref_lines = []
source_lines = []
res_build = []
res_ref = []
res_lines = []

for path in swift_files:
    r = rel_hub(path)
    name = path.name
    fr, bf = uid(f"fr:{r}"), uid(f"bf:{r}")
    ref_lines.append(
        f"\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {r}; sourceTree = \"<group>\"; }};"
    )
    build_lines.append(
        f"\t\t{bf} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
    )
    source_lines.append(f"\t\t\t\t{bf} /* {name} in Sources */,")

for path, ftype in resources:
    if not path.exists():
        continue
    r = rel_hub(path)
    name = path.name
    fr, bf = uid(f"fr:{r}"), uid(f"bf:{r}")
    ref_lines.append(
        f"\t\t{fr} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {r}; sourceTree = \"<group>\"; }};"
    )
    res_build.append(
        f"\t\t{bf} /* {name} in Resources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {name} */; }};"
    )
    res_lines.append(f"\t\t\t\t{bf} /* {name} in Resources */,")

sk_fr, sk_bf = uid("fr:StoreKit"), uid("bf:StoreKit")
if "StoreKit.framework" not in text:
    ref_lines.append(
        f"\t\t{sk_fr} /* StoreKit.framework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.framework; name = StoreKit.framework; path = System/Library/Frameworks/StoreKit.framework; sourceTree = SDKROOT; }};"
    )
    build_lines.append(
        f"\t\t{sk_bf} /* StoreKit.framework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {sk_fr} /* StoreKit.framework */; }};"
    )

text = text.replace("/* End PBXBuildFile section */", "\n".join(build_lines + res_build) + "\n/* End PBXBuildFile section */")
text = text.replace("/* End PBXFileReference section */", "\n".join(ref_lines) + "\n/* End PBXFileReference section */")

text = text.replace(
    "\t\t\t\tA10000000000000000000028 /* ProfileAvatarView.swift in Sources */,",
    "\t\t\t\tA10000000000000000000028 /* ProfileAvatarView.swift in Sources */,\n" + "\n".join(source_lines),
)

text = text.replace(
    "\t\t\t\tA10000000000000000000013 /* Assets.xcassets in Resources */,",
    "\t\t\t\tA10000000000000000000013 /* Assets.xcassets in Resources */,\n" + "\n".join(res_lines),
)

if "StoreKit.framework in Frameworks" not in text:
    text = text.replace(
        "/* End PBXFrameworksBuildPhase section */",
        f"\t\t\t\t{sk_bf} /* StoreKit.framework in Frameworks */,\n/* End PBXFrameworksBuildPhase section */",
    )

if "INFOPLIST_KEY_NSPhotoLibraryUsageDescription" not in text:
    text = text.replace(
        "INFOPLIST_KEY_NSUserNotificationsUsageDescription = \"Hub 需要发送通知以提醒您按时完成任务。\";",
        "INFOPLIST_KEY_NSPhotoLibraryUsageDescription = \"用于从相册选择人像照片以进行模板生成。\";\n"
        "\t\t\t\tINFOPLIST_KEY_NSPhotoLibraryAddUsageDescription = \"将生成的图片或视频保存到您的相册。\";\n"
        "\t\t\t\tINFOPLIST_KEY_UIBackgroundModes = \"remote-notification audio\";\n"
        "\t\t\t\tINFOPLIST_KEY_NSUserNotificationsUsageDescription = \"Hub 需要发送通知以提醒您按时完成任务。\";",
        2,
    )

# aps-environment for push
if "aps-environment" not in text:
    ent = ROOT / "Hub" / "Hub.entitlements"
    ent.write_text(ent.read_text().replace(
        "</dict>",
        "\t<key>aps-environment</key>\n\t<string>development</string>\n</dict>",
    ))

PBX.write_text(text)
print(f"Integrated {len(source_lines)} Swift files, {len(res_lines)} resources")
print("Run: python3 scripts/fix_pbxproj_rahmi_refs.py  # fix paths + Xcode group tree")
