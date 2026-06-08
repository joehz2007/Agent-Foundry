#!/usr/bin/env python3
"""Validate Agent Foundry registry and artifacts."""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

import json
import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SUPPORTED_TARGETS = {"claude-code", "codex", "pi"}


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a YAML object")
    return data


def ensure_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def validate_description(artifact: dict[str, Any]) -> list[str]:
    warnings: list[str] = []
    description = artifact.get("description", "")
    if len(description) < 80:
        warnings.append("description is short; triggering may be weak")
    if "use" not in description.lower() and "当" not in description and "whenever" not in description.lower():
        warnings.append("description should explicitly say when to use the artifact")
    return warnings


def validate_artifact(path: Path, schema: dict[str, Any]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        artifact = load_yaml(path)
    except Exception as exc:  # noqa: BLE001
        return [f"failed to parse YAML: {exc}"], warnings

    validator = Draft202012Validator(schema)
    for error in sorted(validator.iter_errors(artifact), key=lambda e: e.path):
        loc = ".".join(str(part) for part in error.path) or "<root>"
        errors.append(f"{loc}: {error.message}")

    if errors:
        return errors, warnings

    expected_dir = f"artifacts/{artifact['type']}s"
    if expected_dir not in path.as_posix():
        warnings.append(f"artifact type is {artifact['type']} but path is outside {expected_dir}/")

    for target in ensure_list(artifact.get("targets")):
        if target not in SUPPORTED_TARGETS:
            errors.append(f"unsupported target: {target}")

    for eval_path in ensure_list(artifact.get("evals")):
        if not (ROOT / eval_path).exists():
            warnings.append(f"missing eval file: {eval_path}")

    resources = artifact.get("resources") or {}
    if isinstance(resources, dict):
        for key in ("references", "scripts"):
            for resource in ensure_list(resources.get(key)):
                if not (ROOT / resource).exists():
                    warnings.append(f"missing resource: {resource}")

    warnings.extend(validate_description(artifact))
    return errors, warnings


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", help="Specific artifact files to validate")
    args = parser.parse_args()

    schema = json.loads((ROOT / "schemas" / "artifact.schema.json").read_text(encoding="utf-8"))
    registry = load_yaml(ROOT / "registry.yaml")

    paths: list[Path]
    if args.paths:
        paths = [Path(p) if Path(p).is_absolute() else ROOT / p for p in args.paths]
    else:
        paths = [ROOT / item["path"] for item in registry.get("assets", [])]

    registry_ids: set[str] = set()
    failed = False

    for item in registry.get("assets", []):
        asset_id = item.get("id")
        if asset_id in registry_ids:
            print(f"ERROR registry: duplicate id {asset_id}")
            failed = True
        registry_ids.add(asset_id)
        if not (ROOT / item["path"]).exists():
            print(f"ERROR registry: missing artifact path {item['path']}")
            failed = True

    for path in paths:
        rel = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
        errors, warnings = validate_artifact(path, schema)
        if errors:
            failed = True
            for error in errors:
                print(f"ERROR {rel}: {error}")
        for warning in warnings:
            print(f"WARN  {rel}: {warning}")
        if not errors:
            print(f"OK    {rel}")

    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
