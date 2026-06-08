# Agent Foundry

A small factory for authoring AI coding assets once and publishing them to multiple agent tools: Claude Code skills/agents/commands, Codex-style skills, and other runtimes.

Core idea:

> Prompt is source code. Skill is a module. Command is an entrypoint. Eval is a test. Adapter is a compiler.

## Project layout

```text
agent-foundry/
├── registry.yaml              # Asset index
├── artifacts/                 # Neutral source format
│   ├── agents/
│   ├── skills/
│   └── commands/
├── schemas/                   # JSON schema for source format
├── scripts/                   # Build and validation tools
├── evals/                     # Test prompts / expected behavior
├── docs/                      # Authoring rules and platform notes
├── templates/                 # Optional platform templates
└── dist/                      # Generated files, ignored by git if desired
```

## Quick start

Install dependencies:

```bash
python3 -m pip install -r requirements.txt
```

Validate all artifacts:

```bash
python3 scripts/validate.py
```

Build all targets:

```bash
python3 scripts/build.py --target all
```

Build a single target:

```bash
python3 scripts/build.py --target claude-code
python3 scripts/build.py --target codex
python3 scripts/build.py --target pi
```

Generated output appears under `dist/<target>/`.

## Asset types

- **agent**: a role-based executor with boundaries, responsibilities, and output contract.
- **skill**: a domain/workflow capability with methodology, references, and optional scripts.
- **command**: a short user-facing entrypoint for a repeatable task.

Included richer skill examples:

- `code-review-spring-boot`: technical implementation review for Java/Kotlin Spring Boot backends.
- `code-review-vue`: technical implementation review for Vue/TypeScript frontends.
- `zentao-execution-rd-audit`: audits ZenTao execution plans into RD baseline reports and JSON.
- `zentao-execution-code-review`: orchestrates PR-based task-alignment review from the RD baseline and delegates technical review to stack-specific skills.

See `docs/writing-artifacts.md` for the source format.
