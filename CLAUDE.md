# Claude Instructions for avondale-n8n

This file contains repository-specific instructions for Claude Code when working on this project.

## Project Management & Tracking

### GitHub Projects Board

- Project: `avondale-n8n board`
- URL: `https://github.com/users/sshort/projects/3`
- Repository: `sshort/avondale-n8n`

For significant functionality changes, large-effort jobs, complex refactors, or multi-stage work:

1. Create a GitHub issue if one does not already exist.
2. Add relevant GitHub labels where suitable.
3. Add the issue to the GitHub Project.
4. Move the project item to `In Progress` before starting implementation.
5. Track multi-stage work with a checklist in the GitHub issue.
6. Move the project item to `Done` once the work is finished and verified.

GitHub Projects is the source of truth for task state.

Working notes may be kept:
- in the GitHub issue body/comments
- in `/mnt/c/dev/avondale-notes/kanban-notes`
- moved to `/mnt/c/dev/avondale-notes/kanban-completed` when complete

If a markdown working note is used, ensure final notes are also reflected in the GitHub issue.

## Technical Standards

### Documents

Keep documentation in the `docs/` folder.

### ExecPlans

For complex features or significant refactors, use an ExecPlan as described in:

```text
.agent/PLANS.md
```

Use the ExecPlan from design through implementation.

### Code Style

- Use ESM / ECMAScript Modules for all new scripts.
- Prefer `node:fs/promises` for file operations.
- Ensure all scripts are executable with `chmod +x`.

## Implementation

Use MCPs for:
- database actions
- Metabase actions
- n8n actions

Ask for API tokens or credentials when required.

If the MCP does not provide the required functionality, use the available local tools.

## Deployment

Deployment is typically to the `n8n` server:

```text
192.168.1.237
```

Use the root `docker compose` configuration for service updates.

## Reference Services

See:

```text
docs/SERVICES.md
```

for the consolidated list of entry points and monitoring URLs.
