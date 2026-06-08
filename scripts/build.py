#!/usr/bin/env python3
"""Build neutral Agent Foundry artifacts into platform-specific files."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from typing import Any

import yaml

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_TARGETS = ("claude-code", "codex", "pi")


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML object")
    return data


def dump_frontmatter(data: dict[str, Any]) -> str:
    return yaml.safe_dump(data, allow_unicode=True, sort_keys=False).strip()


def ensure_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def artifact_body(artifact: dict[str, Any], *, heading: str | None = None) -> str:
    title = heading or artifact.get("title") or artifact["id"]
    triggers = ensure_list(artifact.get("triggers"))
    inputs = ensure_list(artifact.get("inputs"))
    outputs = artifact.get("outputs") or {}
    sections = ensure_list(outputs.get("sections")) if isinstance(outputs, dict) else []
    resources = artifact.get("resources") or {}
    references = ensure_list(resources.get("references")) if isinstance(resources, dict) else []
    scripts = ensure_list(resources.get("scripts")) if isinstance(resources, dict) else []
    instructions = artifact.get("instructions", "").strip()

    parts: list[str] = [f"# {title}", ""]
    parts += [f"Version: `{artifact.get('version', '0.1.0')}`", ""]

    if triggers:
        parts += ["## Trigger contexts", ""]
        parts += [f"- {item}" for item in triggers]
        parts.append("")

    if inputs:
        parts += ["## Expected inputs", ""]
        parts += [f"- {item}" for item in inputs]
        parts.append("")

    if sections:
        parts += ["## Output contract", ""]
        parts.append(f"Format: `{outputs.get('format', 'markdown')}`")
        parts.append("")
        parts += [f"- {section}" for section in sections]
        parts.append("")

    parts += ["## Instructions", "", instructions, ""]

    if references or scripts:
        parts += ["## Bundled resources", ""]
        for ref in references:
            parts.append(f"- Reference: `{resource_output_path(artifact, ref)}`")
        for script in scripts:
            parts.append(f"- Script: `{resource_output_path(artifact, script)}`")
        parts.append("")

    return "\n".join(parts).rstrip() + "\n"


def write_file(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"wrote {path.relative_to(ROOT)}")


def resource_output_path(artifact: dict[str, Any], resource: str) -> str:
    """Return the resource path as it should appear inside a generated skill.

    Source resources are commonly organized as `references/<artifact-id>/file.md`
    in the Agent Foundry repository. Generated skills already live in a directory
    named after the artifact, so repeating the artifact id under `references/` is
    redundant and makes in-skill links harder to follow. Strip that redundant
    segment for generated outputs.
    """
    artifact_id = artifact["id"]
    for base in ("references", "scripts"):
        prefix = f"{base}/{artifact_id}/"
        if resource.startswith(prefix):
            return f"{base}/{resource[len(prefix):]}"
    return resource


def copy_resources(artifact: dict[str, Any], output_dir: Path) -> None:
    """Copy bundled references/scripts next to generated skill files."""
    resources = artifact.get("resources") or {}
    if not isinstance(resources, dict):
        return
    for key in ("references", "scripts"):
        for resource in ensure_list(resources.get(key)):
            src = ROOT / resource
            if not src.exists():
                continue
            dest = output_dir / resource_output_path(artifact, resource)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest)
            print(f"copied {src.relative_to(ROOT)} -> {dest.relative_to(ROOT)}")


def build_claude_code(artifact: dict[str, Any]) -> None:
    artifact_type = artifact["type"]
    platform = (artifact.get("platforms") or {}).get("claude-code", {})

    if artifact_type == "command":
        frontmatter: dict[str, Any] = {"description": artifact["description"]}
        if platform.get("argument_hint"):
            frontmatter["argument-hint"] = platform["argument_hint"]
        if platform.get("allowed_tools"):
            frontmatter["allowed-tools"] = platform["allowed_tools"]
        content = f"---\n{dump_frontmatter(frontmatter)}\n---\n\n{artifact_body(artifact)}"
        write_file(ROOT / "dist" / "claude-code" / ".claude" / "commands" / f"{artifact['id']}.md", content)
        return

    if artifact_type == "skill":
        frontmatter = {
            "name": platform.get("name", artifact["id"]),
            "description": artifact["description"],
        }
        if platform.get("tools"):
            frontmatter["allowed-tools"] = platform["tools"]
        content = f"---\n{dump_frontmatter(frontmatter)}\n---\n\n{artifact_body(artifact)}"
        output_dir = ROOT / "dist" / "claude-code" / ".claude" / "skills" / artifact["id"]
        write_file(output_dir / "SKILL.md", content)
        copy_resources(artifact, output_dir)
        return

    frontmatter = {
        "name": platform.get("name", artifact["id"]),
        "description": artifact["description"],
    }
    if platform.get("tools"):
        frontmatter["tools"] = platform["tools"]
    if platform.get("model"):
        frontmatter["model"] = platform["model"]

    content = f"---\n{dump_frontmatter(frontmatter)}\n---\n\n{artifact_body(artifact)}"
    write_file(ROOT / "dist" / "claude-code" / ".claude" / "agents" / f"{artifact['id']}.md", content)


def build_skill_like(target: str, artifact: dict[str, Any]) -> None:
    artifact_type = artifact["type"]
    platform = (artifact.get("platforms") or {}).get(target, {})

    if artifact_type == "command":
        frontmatter = {"id": artifact["id"], "description": artifact["description"]}
        content = f"---\n{dump_frontmatter(frontmatter)}\n---\n\n{artifact_body(artifact)}"
        write_file(ROOT / "dist" / target / "commands" / f"{artifact['id']}.md", content)
        return

    frontmatter = {
        "name": platform.get("name", artifact["id"]),
        "description": artifact["description"],
    }
    heading = artifact.get("title")
    if artifact_type == "agent":
        heading = f"{artifact.get('title', artifact['id'])} Agent"
    content = f"---\n{dump_frontmatter(frontmatter)}\n---\n\n{artifact_body(artifact, heading=heading)}"
    output_dir = ROOT / "dist" / target / "skills" / artifact["id"]
    write_file(output_dir / "SKILL.md", content)
    copy_resources(artifact, output_dir)


def artifact_targets(registry_item: dict[str, Any], artifact: dict[str, Any]) -> set[str]:
    item_targets = set(ensure_list(registry_item.get("targets")) or SUPPORTED_TARGETS)
    own_targets = set(ensure_list(artifact.get("targets")) or SUPPORTED_TARGETS)
    return item_targets & own_targets


def build(target: str, *, clean: bool) -> None:
    if target != "all" and target not in SUPPORTED_TARGETS:
        raise SystemExit(f"Unsupported target: {target}")

    if clean:
        if target == "all":
            shutil.rmtree(ROOT / "dist", ignore_errors=True)
        else:
            shutil.rmtree(ROOT / "dist" / target, ignore_errors=True)

    registry = load_yaml(ROOT / "registry.yaml")
    for item in registry.get("assets", []):
        artifact = load_yaml(ROOT / item["path"])
        targets = artifact_targets(item, artifact)
        selected_targets = SUPPORTED_TARGETS if target == "all" else (target,)
        for selected in selected_targets:
            if selected not in targets:
                continue
            if selected == "claude-code":
                build_claude_code(artifact)
            elif selected in {"codex", "pi"}:
                build_skill_like(selected, artifact)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=("all", *SUPPORTED_TARGETS), default="all")
    parser.add_argument("--clean", action="store_true", help="Remove target output before building")
    args = parser.parse_args()
    build(args.target, clean=args.clean)


if __name__ == "__main__":
    main()
