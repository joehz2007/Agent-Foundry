# Writing artifacts

Artifacts live under `artifacts/<type>/` and use a neutral YAML format.

## Common fields

```yaml
id: backend-reviewer
type: agent # agent | skill | command
title: Backend Code Reviewer
version: 0.1.0
description: >-
  Short but trigger-friendly summary of what this artifact does and when to use it.
triggers:
  - review代码
  - code review
  - 看看这个接口有没有问题
targets:
  - claude-code
  - codex
  - pi
inputs:
  - git_diff
  - source_code
outputs:
  format: markdown
  sections:
    - summary
    - findings
instructions: |
  Main instruction body.
resources:
  references: []
  scripts: []
evals:
  - evals/backend-reviewer/basic.yaml
changelog:
  - version: 0.1.0
    date: 2026-06-05
    changes:
      - Initial version.
```

## Agent guidance

Use agents for role-based execution. Include:

- responsibilities
- non-goals
- decision rules
- when to ask the user for more context
- output format

## Skill guidance

Use skills for specialized workflows. Include:

- trigger contexts in `description`
- methodology
- step-by-step workflow
- checklists
- optional references/scripts
- result format

## Command guidance

Use commands for short task entrypoints. Include:

- argument hint
- what context to inspect
- which agent/skill to use conceptually
- concise output format

Commands should orchestrate, not contain all domain knowledge.

## Platform overrides

If a target needs special metadata, add `platforms`:

```yaml
platforms:
  claude-code:
    tools: [Read, Grep, Glob, Bash]
    model: sonnet
    argument_hint: "[path or git diff]"
  codex:
    name: backend-reviewer
  pi:
    name: backend-reviewer
```
