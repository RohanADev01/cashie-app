#!/usr/bin/env python3
"""
Generates Cashie.xcodeproj/project.pbxproj from the Cashie/ source tree.

Why: Xcode 15.4 doesn't support synchronized folders (Xcode 16+ feature),
so every Swift file must be enumerated in the pbxproj. Running this after
adding files keeps the project in sync.

Usage:  python3 scripts/gen_pbxproj.py
"""
from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_NAME = "Cashie"
APP_DIR = ROOT / APP_NAME
PROJ_DIR = ROOT / f"{APP_NAME}.xcodeproj"
PROJ_FILE = PROJ_DIR / "project.pbxproj"
BUNDLE_ID = "com.cashie.app"
DEPLOYMENT = "16.0"
SWIFT_VER = "5.0"


def stable_id(key: str) -> str:
    """Deterministic 24-char hex ID (matches PBX object ID format)."""
    return hashlib.sha1(key.encode()).hexdigest()[:24].upper()


def collect_sources():
    """Return list of (rel_path, abs_path) for all .swift files."""
    out = []
    for p in sorted(APP_DIR.rglob("*.swift")):
        rel = p.relative_to(ROOT)
        out.append((str(rel), p))
    return out


def collect_resources():
    """Return list of (rel_path, abs_path) for resource files (xcassets, ttf, plist refs)."""
    out = []
    res_dir = APP_DIR / "Resources"
    if not res_dir.exists():
        return out
    for p in sorted(res_dir.iterdir()):
        if p.is_dir() and p.suffix == ".xcassets":
            out.append((str(p.relative_to(ROOT)), p))
        elif p.is_file() and p.suffix in {".ttf", ".otf"}:
            out.append((str(p.relative_to(ROOT)), p))
        elif p.is_file() and p.suffix == ".xcprivacy":
            # Apple privacy manifest, copied into the app bundle root.
            out.append((str(p.relative_to(ROOT)), p))
    fonts_dir = res_dir / "Fonts"
    if fonts_dir.exists():
        for p in sorted(fonts_dir.iterdir()):
            if p.suffix in {".ttf", ".otf"}:
                out.append((str(p.relative_to(ROOT)), p))
    return out


def build_group_tree(paths: list[tuple[str, str, Path]]):
    """
    Build nested group dicts from list of (kind, rel_path, abs_path).
    kind in {"src", "res"}.

    Returns root group with children.
    Each group: {"name", "path", "children": [groups], "files": [(kind, rel)]}
    """
    root = {"name": APP_NAME, "path": APP_NAME, "children": {}, "files": []}

    for kind, rel, _abs in paths:
        # rel is "Cashie/foo/bar/Baz.swift"
        parts = Path(rel).parts
        # First part is "Cashie" — skip
        assert parts[0] == APP_NAME
        cur = root
        for sub in parts[1:-1]:
            if sub not in cur["children"]:
                cur["children"][sub] = {
                    "name": sub,
                    "path": sub,
                    "children": {},
                    "files": [],
                }
            cur = cur["children"][sub]
        cur["files"].append((kind, rel, parts[-1]))

    return root


def render_pbxproj() -> str:
    sources = [("src", rel, abs_) for rel, abs_ in collect_sources()]
    resources = [("res", rel, abs_) for rel, abs_ in collect_resources()]
    all_paths = sources + resources

    if not sources:
        print("ERROR: no Swift files found under Cashie/", file=sys.stderr)
        sys.exit(1)

    # Object IDs ----
    PROJ = stable_id("project")
    MAIN_GROUP = stable_id("mainGroup")
    PRODUCTS_GROUP = stable_id("productsGroup")
    APP_TARGET = stable_id("appTarget")
    APP_PRODUCT = stable_id("appProduct")
    SOURCES_PHASE = stable_id("sourcesPhase")
    FRAMEWORKS_PHASE = stable_id("frameworksPhase")
    RESOURCES_PHASE = stable_id("resourcesPhase")
    BUILD_CFG_LIST_PROJ = stable_id("buildCfgListProj")
    BUILD_CFG_LIST_TGT = stable_id("buildCfgListTgt")
    DEBUG_PROJ = stable_id("debugProj")
    RELEASE_PROJ = stable_id("releaseProj")
    DEBUG_TGT = stable_id("debugTgt")
    RELEASE_TGT = stable_id("releaseTgt")
    # No Swift Package Manager dependencies: Cashie uses native StoreKit 2 for
    # purchases, so the project links no third-party packages.

    # File references ----
    file_ref_ids: dict[str, str] = {}      # rel -> ID
    build_file_ids: dict[str, str] = {}    # rel -> ID
    for kind, rel, _ in all_paths:
        file_ref_ids[rel] = stable_id(f"fileRef:{rel}")
        build_file_ids[rel] = stable_id(f"buildFile:{rel}")

    # Build group tree ----
    tree = build_group_tree(all_paths)
    group_ids: dict[str, str] = {}  # path -> ID

    def assign_group_ids(node, path_prefix):
        full_path = path_prefix + "/" + node["path"] if path_prefix else node["path"]
        group_ids[full_path] = stable_id(f"group:{full_path}")
        for child in node["children"].values():
            assign_group_ids(child, full_path)

    assign_group_ids(tree, "")

    # ---- Render sections ----
    lines: list[str] = []

    # PBXBuildFile
    lines.append("/* Begin PBXBuildFile section */")
    for kind, rel, _ in all_paths:
        bf_id = build_file_ids[rel]
        fr_id = file_ref_ids[rel]
        name = Path(rel).name
        kind_label = "Sources" if kind == "src" else "Resources"
        lines.append(
            f"\t\t{bf_id} /* {name} in {kind_label} */ = "
            f"{{isa = PBXBuildFile; fileRef = {fr_id} /* {name} */; }};"
        )
    lines.append("/* End PBXBuildFile section */\n")

    # PBXFileReference
    lines.append("/* Begin PBXFileReference section */")
    lines.append(
        f"\t\t{APP_PRODUCT} /* {APP_NAME}.app */ = "
        "{isa = PBXFileReference; explicitFileType = wrapper.application; "
        f"includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )
    for kind, rel, _ in all_paths:
        fr_id = file_ref_ids[rel]
        name = Path(rel).name
        if name.endswith(".swift"):
            ftype = "sourcecode.swift"
            le = "lastKnownFileType"
        elif name.endswith(".xcassets"):
            ftype = "folder.assetcatalog"
            le = "lastKnownFileType"
        elif name.endswith((".ttf", ".otf")):
            ftype = "file"
            le = "lastKnownFileType"
        elif name.endswith(".xcprivacy"):
            ftype = "text.plist.xml"
            le = "lastKnownFileType"
        else:
            ftype = "text"
            le = "lastKnownFileType"
        # path is the leaf name; group provides the directory hierarchy
        # Quote the path so filenames with special characters (e.g. "+" in
        # AppContainer+Ranks.swift) don't break the old-style plist parser.
        lines.append(
            f"\t\t{fr_id} /* {name} */ = "
            f"{{isa = PBXFileReference; {le} = {ftype}; path = \"{name}\"; sourceTree = \"<group>\"; }};"
        )

    # Info.plist reference
    INFO_PLIST_ID = stable_id("infoPlist")
    lines.append(
        f"\t\t{INFO_PLIST_ID} /* Info.plist */ = "
        "{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
        "path = Info.plist; sourceTree = \"<group>\"; };"
    )
    lines.append("/* End PBXFileReference section */\n")

    # PBXGroup — mainGroup, products group, then app group tree
    def render_group(node, full_path) -> list[str]:
        gid = group_ids[full_path]
        out = [f"\t\t{gid} /* {node['name']} */ = {{"]
        out.append("\t\t\tisa = PBXGroup;")
        out.append("\t\t\tchildren = (")
        # Subgroups first
        for child in sorted(node["children"].values(), key=lambda n: n["name"]):
            cid = group_ids[full_path + "/" + child["path"]]
            out.append(f"\t\t\t\t{cid} /* {child['name']} */,")
        # Then files
        for kind, rel, name in sorted(node["files"], key=lambda f: f[2]):
            fr_id = file_ref_ids[rel]
            out.append(f"\t\t\t\t{fr_id} /* {name} */,")
        # If this is the root Cashie group, include Info.plist
        if full_path == APP_NAME:
            out.append(f"\t\t\t\t{INFO_PLIST_ID} /* Info.plist */,")
        out.append("\t\t\t);")
        out.append(f"\t\t\tpath = {node['path']};")
        out.append("\t\t\tsourceTree = \"<group>\";")
        out.append("\t\t};")
        return out

    def render_groups_recursive(node, full_path) -> list[str]:
        out = render_group(node, full_path)
        for child in node["children"].values():
            out.extend(render_groups_recursive(child, full_path + "/" + child["path"]))
        return out

    lines.append("/* Begin PBXGroup section */")
    # main group
    lines.append(f"\t\t{MAIN_GROUP} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{group_ids[APP_NAME]} /* {APP_NAME} */,")
    lines.append(f"\t\t\t\t{PRODUCTS_GROUP} /* Products */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    # products
    lines.append(f"\t\t{PRODUCTS_GROUP} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{APP_PRODUCT} /* {APP_NAME}.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    # app tree
    lines.extend(render_groups_recursive(tree, APP_NAME))
    lines.append("/* End PBXGroup section */\n")

    # PBXSourcesBuildPhase
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{SOURCES_PHASE} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for kind, rel, _ in all_paths:
        if kind != "src":
            continue
        bf_id = build_file_ids[rel]
        name = Path(rel).name
        lines.append(f"\t\t\t\t{bf_id} /* {name} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */\n")

    # PBXResourcesBuildPhase
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{RESOURCES_PHASE} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for kind, rel, _ in all_paths:
        if kind != "res":
            continue
        bf_id = build_file_ids[rel]
        name = Path(rel).name
        lines.append(f"\t\t\t\t{bf_id} /* {name} in Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */\n")

    # PBXFrameworksBuildPhase
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{FRAMEWORKS_PHASE} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */\n")

    # PBXNativeTarget
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{APP_TARGET} /* {APP_NAME} */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {BUILD_CFG_LIST_TGT};")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{SOURCES_PHASE} /* Sources */,")
    lines.append(f"\t\t\t\t{FRAMEWORKS_PHASE} /* Frameworks */,")
    lines.append(f"\t\t\t\t{RESOURCES_PHASE} /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = ();")
    lines.append("\t\t\tdependencies = ();")
    lines.append(f"\t\t\tname = {APP_NAME};")
    lines.append(f"\t\t\tproductName = {APP_NAME};")
    lines.append(f"\t\t\tproductReference = {APP_PRODUCT};")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */\n")

    # PBXProject
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{PROJ} = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = YES;")
    lines.append("\t\t\t\tLastSwiftUpdateCheck = 1540;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1540;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{APP_TARGET} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.4;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {BUILD_CFG_LIST_PROJ};")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (en, Base);")
    lines.append(f"\t\t\tmainGroup = {MAIN_GROUP};")
    lines.append(f"\t\t\tproductRefGroup = {PRODUCTS_GROUP};")
    lines.append("\t\t\tprojectDirPath = \"\";")
    lines.append("\t\t\tprojectRoot = \"\";")
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{APP_TARGET} /* {APP_NAME} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */\n")

    # XCBuildConfiguration
    lines.append("/* Begin XCBuildConfiguration section */")
    common_proj = [
        "ALWAYS_SEARCH_USER_PATHS = NO",
        "CLANG_ANALYZER_NONNULL = YES",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE",
        "CLANG_ENABLE_MODULES = YES",
        "CLANG_ENABLE_OBJC_ARC = YES",
        "CLANG_ENABLE_OBJC_WEAK = YES",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES",
        "CLANG_WARN_BOOL_CONVERSION = YES",
        "CLANG_WARN_COMMA = YES",
        "CLANG_WARN_CONSTANT_CONVERSION = YES",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES",
        "CLANG_WARN_EMPTY_BODY = YES",
        "CLANG_WARN_ENUM_CONVERSION = YES",
        "CLANG_WARN_INFINITE_RECURSION = YES",
        "CLANG_WARN_INT_CONVERSION = YES",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES",
        "CLANG_WARN_STRICT_PROTOTYPES = YES",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE",
        "CLANG_WARN_UNREACHABLE_CODE = YES",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES",
        "COPY_PHASE_STRIP = NO",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES",
        "GCC_C_LANGUAGE_STANDARD = gnu11",
        "GCC_NO_COMMON_BLOCKS = YES",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR",
        "GCC_WARN_UNDECLARED_SELECTOR = YES",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE",
        "GCC_WARN_UNUSED_FUNCTION = YES",
        "GCC_WARN_UNUSED_VARIABLE = YES",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT}",
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES",
        "MTL_FAST_MATH = YES",
        "SDKROOT = iphoneos",
        f"SWIFT_VERSION = {SWIFT_VER}",
    ]

    def emit_cfg(cfg_id, name, kvs):
        lines.append(f"\t\t{cfg_id} /* {name} */ = {{")
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")
        for kv in kvs:
            k, v = kv.split(" = ", 1)
            lines.append(f"\t\t\t\t{k} = {v};")
        lines.append("\t\t\t};")
        lines.append(f"\t\t\tname = {name};")
        lines.append("\t\t};")

    debug_proj = common_proj + [
        "DEBUG_INFORMATION_FORMAT = dwarf",
        "ENABLE_STRICT_OBJC_MSGSEND = YES",
        "ENABLE_TESTABILITY = YES",
        "GCC_DYNAMIC_NO_PIC = NO",
        "GCC_OPTIMIZATION_LEVEL = 0",
        "GCC_PREPROCESSOR_DEFINITIONS = (\"DEBUG=1\", \"$(inherited)\")",
        "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE",
        "ONLY_ACTIVE_ARCH = YES",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\"",
        "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\"",
    ]
    release_proj = common_proj + [
        "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\"",
        "ENABLE_NS_ASSERTIONS = NO",
        "ENABLE_STRICT_OBJC_MSGSEND = YES",
        "MTL_ENABLE_DEBUG_INFO = NO",
        "SWIFT_COMPILATION_MODE = wholemodule",
        "VALIDATE_PRODUCT = YES",
    ]
    emit_cfg(DEBUG_PROJ, "Debug", debug_proj)
    emit_cfg(RELEASE_PROJ, "Release", release_proj)

    target_common = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor",
        "CODE_SIGN_STYLE = Automatic",
        "CURRENT_PROJECT_VERSION = 1",
        "DEVELOPMENT_ASSET_PATHS = \"\"",
        "ENABLE_PREVIEWS = YES",
        "GENERATE_INFOPLIST_FILE = NO",
        f"INFOPLIST_FILE = {APP_NAME}/Info.plist",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation = YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\"",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait\"",
        "LD_RUNPATH_SEARCH_PATHS = (\"$(inherited)\", \"@executable_path/Frameworks\")",
        "MARKETING_VERSION = 1.0",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}",
        f"PRODUCT_NAME = \"$(TARGET_NAME)\"",
        "SWIFT_EMIT_LOC_STRINGS = YES",
        "TARGETED_DEVICE_FAMILY = \"1,2\"",
    ]
    emit_cfg(DEBUG_TGT, "Debug", target_common)
    emit_cfg(RELEASE_TGT, "Release", target_common)
    lines.append("/* End XCBuildConfiguration section */\n")

    # XCConfigurationList
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(
        f"\t\t{BUILD_CFG_LIST_PROJ} /* Build configuration list for PBXProject \"{APP_NAME}\" */ = {{"
    )
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{DEBUG_PROJ} /* Debug */,")
    lines.append(f"\t\t\t\t{RELEASE_PROJ} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append(
        f"\t\t{BUILD_CFG_LIST_TGT} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */ = {{"
    )
    lines.append("\t\t\tisa = XCConfigurationList;")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append(f"\t\t\t\t{DEBUG_TGT} /* Debug */,")
    lines.append(f"\t\t\t\t{RELEASE_TGT} /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */\n")

    # ---- Wrap in archive ----
    out = []
    out.append("// !$*UTF8*$!\n{")
    out.append("\tarchiveVersion = 1;")
    out.append("\tclasses = {};")
    out.append("\tobjectVersion = 56;")
    out.append("\tobjects = {")
    out.append("")
    out.extend(lines)
    out.append("\t};")
    out.append(f"\trootObject = {PROJ};")
    out.append("}")
    return "\n".join(out)


def main():
    PROJ_DIR.mkdir(parents=True, exist_ok=True)
    text = render_pbxproj()
    PROJ_FILE.write_text(text)
    print(f"Wrote {PROJ_FILE}")
    n_src = len(collect_sources())
    n_res = len(collect_resources())
    print(f"  {n_src} Swift sources, {n_res} resources")


if __name__ == "__main__":
    main()
