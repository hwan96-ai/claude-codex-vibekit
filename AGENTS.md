# Agent Router

This repository is a Claude Code and Codex workflow harness. Treat it as
portfolio-sensitive harness engineering, not product application code.

## Source Of Truth

Start with [docs/claude/README.md](docs/claude/README.md), then open only the
child document relevant to the task:

- [Project overview](docs/claude/project-overview.md)
- [Repository map](docs/claude/repository-map.md)
- [Development workflow](docs/claude/development-workflow.md)
- [Testing and validation](docs/claude/testing-and-validation.md)
- [Security and secrets](docs/claude/security-and-secrets.md)
- [Portfolio showcase rules](docs/claude/portfolio-showcase-rules.md)
- [Release and git hygiene](docs/claude/release-and-git-hygiene.md)

`docs/solutions/` contains documented solutions and workflow learnings,
organized by category with YAML frontmatter such as `module`, `tags`, and
`problem_type`. It is relevant when implementing or debugging in a documented
area.

## Working Rules

- Keep `AGENTS.md` and `CLAUDE.md` concise routers. Put durable instructions in
  `docs/claude/`.
- Do not change product behavior for harness-doc tasks.
- Do not expose secrets, credentials, private workflow notes, private prompts,
  internal URLs, or non-public automation details.
- Public portfolio or showcase extraction must happen in a separate sanitized
  repository, not by making this original repository public.
- Do not commit local task files such as `.codex_task.md`.

<!-- BEGIN COMPOUND CODEX TOOL MAP -->
## Compound Codex Tool Mapping (Claude Compatibility)

This section maps Claude Code plugin tool references to Codex behavior.
Only this block is managed automatically.

Tool mapping:
- Read: use shell reads (cat/sed) or rg
- Write: create files via shell redirection or apply_patch
- Edit/MultiEdit: use apply_patch
- Bash: use shell_command
- Grep: use rg (fallback: grep)
- Glob: use rg --files or find
- LS: use ls via shell_command
- WebFetch/WebSearch: use curl or Context7 for library docs
- AskUserQuestion/Question: present choices as a numbered list in chat and wait for a reply number. For multi-select (multiSelect: true), accept comma-separated numbers. Never skip or auto-configure -- always wait for the user's response before proceeding.
- Task (subagent dispatch) / Subagent / Parallel: run sequentially in main thread; use multi_tool_use.parallel for tool calls
- TaskCreate/TaskUpdate/TaskList/TaskGet/TaskStop/TaskOutput (Claude Code task-tracking, current): use update_plan (Codex's task-tracking primitive)
- TodoWrite/TodoRead (Claude Code task-tracking, legacy -- deprecated, replaced by Task* tools): use update_plan
- Skill: open the referenced SKILL.md and follow it
- ExitPlanMode: ignore
<!-- END COMPOUND CODEX TOOL MAP -->
