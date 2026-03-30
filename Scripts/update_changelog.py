#!/usr/bin/env python3

from __future__ import annotations

import argparse
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass


BADGES = {
    "feature": "![Feature](https://img.shields.io/badge/Feature-10B981?style=flat-square)",
    "improvement": "![Optimize](https://img.shields.io/badge/Optimize-3B82F6?style=flat-square)",
    "fix": "![Fix](https://img.shields.io/badge/Fix-EF4444?style=flat-square)",
}


SECTION_HEADERS = {
    "feature": "**✨ 新增功能 (New Features)**",
    "improvement": "**🚀 优化改进 (Improvements)**",
    "fix": "**🐞 修复问题 (Bug Fixes)**",
}


PLACEHOLDERS = {
    "feature": f"- {BADGES['feature']} **暂无内容**：当前版本未新增独立功能项。",
    "improvement": f"- {BADGES['improvement']} **暂无内容**：当前版本未包含单独归类的优化项。",
    "fix": f"- {BADGES['fix']} **暂无内容**：当前版本未包含单独归类的问题修复。",
}


TYPE_TO_CATEGORY = {
    "feat": "feature",
    "fix": "fix",
    "perf": "improvement",
    "refactor": "improvement",
    "build": "improvement",
    "ci": "improvement",
    "docs": "improvement",
    "style": "improvement",
    "test": "improvement",
    "chore": "improvement",
    "revert": "fix",
}


IGNORED_SUBJECT_PREFIXES = (
    "merge ",
)


CONVENTIONAL_COMMIT_PATTERN = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?(?P<breaking>!)?:\s*(?P<description>.+)$"
)


@dataclass
class CommitEntry:
    category: str
    text: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate or update CHANGELOG.md from git commits.")
    parser.add_argument("--version", required=True, help="Release version without leading v")
    parser.add_argument("--to-ref", default="HEAD", help="Ending git ref for the changelog range")
    parser.add_argument("--from-ref", default="", help="Starting git ref (exclusive) for the changelog range")
    parser.add_argument("--changelog", default="CHANGELOG.md", help="Path to CHANGELOG.md")
    parser.add_argument(
        "--mode",
        choices=["section", "body", "write"],
        default="section",
        help="Print full section, body only, or write back to CHANGELOG.md",
    )
    return parser.parse_args()


def run_git(*args: str) -> str:
    completed = subprocess.run(
        ["git", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout


def build_revision_range(from_ref: str, to_ref: str) -> str:
    if from_ref:
        return f"{from_ref}..{to_ref}"
    return to_ref


def collect_commits(from_ref: str, to_ref: str) -> list[tuple[str, str, str]]:
    revision_range = build_revision_range(from_ref, to_ref)
    raw_log = run_git("log", "--reverse", "--format=%s%x1f%b%x1e", revision_range)
    commits: list[tuple[str, str, str]] = []

    for record in raw_log.strip("\x1e").split("\x1e"):
        if not record.strip():
            continue
        subject, body = (record.split("\x1f", maxsplit=1) + [""])[:2]
        normalized_subject = subject.strip()
        normalized_body = body.strip()
        lower_subject = normalized_subject.lower()
        if any(lower_subject.startswith(prefix) for prefix in IGNORED_SUBJECT_PREFIXES):
            continue
        commits.append((normalized_subject, normalized_body, lower_subject))

    return commits


def classify_commit(subject: str, body: str, lower_subject: str) -> CommitEntry:
    match = CONVENTIONAL_COMMIT_PATTERN.match(subject)

    if match:
        commit_type = match.group("type").lower()
        scope = match.group("scope")
        description = match.group("description").strip()
        breaking = bool(match.group("breaking")) or "BREAKING CHANGE" in body
        category = TYPE_TO_CATEGORY.get(commit_type, "improvement")
        prefix = "Breaking: " if breaking else ""
        if scope:
            text = f"**{scope}**：{prefix}{description}"
        else:
            text = f"{prefix}{description}"
        return CommitEntry(category=category, text=text)

    fallback_category = "fix" if any(keyword in lower_subject for keyword in ("fix", "bug")) else "improvement"
    return CommitEntry(category=fallback_category, text=subject)


def build_summary(entries_by_category: dict[str, list[CommitEntry]]) -> str:
    feature_count = len(entries_by_category["feature"])
    improvement_count = len(entries_by_category["improvement"])
    fix_count = len(entries_by_category["fix"])
    return (
        f"> 本次更新包含 **{feature_count} 项新增功能**、"
        f"**{improvement_count} 项优化改进** 和 **{fix_count} 项问题修复**，详情如下。"
    )


def render_category(category: str, entries: list[CommitEntry]) -> str:
    lines = [SECTION_HEADERS[category], ""]
    if not entries:
        lines.append(PLACEHOLDERS[category])
        return "\n".join(lines)

    badge = BADGES[category]
    for entry in entries:
        lines.append(f"- {badge} {entry.text}")
    return "\n".join(lines)


def render_section(version: str, entries_by_category: dict[str, list[CommitEntry]]) -> str:
    section_parts = [
        f"## v{version}",
        "",
        (
            f"![macOS](https://img.shields.io/badge/macOS-Supported-000000?style=flat-square&logo=apple) "
            f"![Version](https://img.shields.io/badge/Release-v{version}-10B981?style=flat-square) "
            f"![Core](https://img.shields.io/badge/Core-Mihomo-6366f1?style=flat-square)"
        ),
        "",
        build_summary(entries_by_category),
        "",
        "### 📝 更新日志 (Changelog)",
        "",
        render_category("feature", entries_by_category["feature"]),
        "",
        render_category("improvement", entries_by_category["improvement"]),
        "",
        render_category("fix", entries_by_category["fix"]),
    ]
    return "\n".join(section_parts).strip() + "\n"


def write_changelog(changelog_path: pathlib.Path, version: str, section: str) -> None:
    existing = changelog_path.read_text(encoding="utf-8") if changelog_path.exists() else ""
    pattern = re.compile(rf"^##\s+v?{re.escape(version)}\s*$\n(.*?)(?=^##\s+|\Z)", re.MULTILINE | re.DOTALL)

    if pattern.search(existing):
        updated = pattern.sub(section.rstrip() + "\n\n", existing, count=1)
    else:
        updated = section.rstrip() + "\n\n" + existing.lstrip()

    changelog_path.write_text(updated.rstrip() + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()

    commits = collect_commits(args.from_ref, args.to_ref)
    if not commits:
        print("No commits found for changelog generation.", file=sys.stderr)
        return 1

    entries_by_category: dict[str, list[CommitEntry]] = {
        "feature": [],
        "improvement": [],
        "fix": [],
    }
    for subject, body, lower_subject in commits:
        entry = classify_commit(subject, body, lower_subject)
        entries_by_category[entry.category].append(entry)

    section = render_section(args.version, entries_by_category)

    if args.mode == "section":
        sys.stdout.write(section)
        return 0

    if args.mode == "body":
        body = section.split("\n", maxsplit=1)[1]
        sys.stdout.write(body.lstrip())
        return 0

    changelog_path = pathlib.Path(args.changelog)
    write_changelog(changelog_path, args.version, section)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
