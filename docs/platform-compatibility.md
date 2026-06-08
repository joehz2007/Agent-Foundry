# Platform compatibility

## Claude Code

Generated paths:

- skills: `dist/claude-code/.claude/skills/<id>/SKILL.md`
- agents: `dist/claude-code/.claude/agents/<id>.md`
- commands: `dist/claude-code/.claude/commands/<id>.md`

Claude Code skills use a `SKILL.md` file under `.claude/skills/<id>/`. Claude Code agents and commands are Markdown files with YAML frontmatter. This project generates conservative frontmatter:

- skill: `name`, `description`
- agent: `name`, `description`, optional `tools`, optional `model`
- command: `description`, optional `argument-hint`, optional `allowed-tools`

## Codex-style skills

Generated paths:

- skills: `dist/codex/skills/<id>/SKILL.md`
- agents: `dist/codex/skills/<id>/SKILL.md` as role-oriented skills
- commands: `dist/codex/commands/<id>.md`

A Codex skill uses `SKILL.md` with frontmatter containing `name` and `description`.

## pi

Generated paths mirror Codex-style skills for now:

- skills: `dist/pi/skills/<id>/SKILL.md`
- agents: `dist/pi/skills/<id>/SKILL.md`
- commands: `dist/pi/commands/<id>.md`

The adapter is intentionally conservative. Add platform-specific overrides as you learn more about the runtime.

## Compatibility rule

The neutral artifact should describe intent and workflow. Adapter scripts own file paths, frontmatter shape, and naming conventions.
