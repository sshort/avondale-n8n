# Agent Instructions for avondale-n8n

This file contains specific instructions for AI agents working on this repository.

## Project Management & Tracking

### GitHub Projects Board
- **Project**: `avondale-n8n board`
- **URL**: `https://github.com/users/sshort/projects/3`
- **Repository**: `sshort/avondale-n8n`
- **Requirement**: Keep this board up to date for **significant functionality changes** and **large effort jobs**.
- **Process**:
    1. **New Issue**: Create a new GitHub issue if one does not exist for the task.
    2. **Categorisation**: Add one or more relevant GitHub labels when suitable.
    3. **Project Board**: Add the issue to the GitHub Project.
    4. **In Progress**: Move the project item to `In Progress` before starting the work.
    5. **Complete**: Move the project item to `Done` once the task is finished and verified.
- **Notes**:
    1. Keep working notes in the GitHub issue body/comments where practical.
    2. Markdown notes can also be kept in `/mnt/c/dev/avondale-notes/kanban-notes` and `/mnt/c/dev/avondale-notes/kanban-completed` when a longer working note is useful.
    3. When work starts, create or update the matching issue notes and, if used, in `kanban-notes`.
    4. When work is finished, ensure the final notes are present in the GitHub issue and, if a markdown note exists, move it into `kanban-completed`.
    5. Treat GitHub Projects as the source of truth for task state; markdown files are optional supporting notes.

## Technical Standards

### Documents

- keep documents in the docs folder

### ExecPlans
- When writing complex features or significant refactors, use an **ExecPlan** (as described in `.agent/PLANS.md`) from design to implementation.

### Code Style
- Use ESM (ECMAScript Modules) for all new scripts.
- Prefer `node:fs/promises` for file operations.
- Ensure all scripts are executable (`chmod +x`).

## Implementation
- use MCPs for database actions, metabase and n8n. Ask for APi tokens or credentials if needed.
- if the MCP does not have the functionality required, use the local tools available.


## Deployment
- Deployment is typically to the `n8n` server (`192.168.1.237`).
- Use the `docker compose` configuration in the root for service updates.

## Reference Services
- **Services List**: See **[docs/SERVICES.md](file:///mnt/c/dev/avondale-n8n/docs/SERVICES.md)** for a consolidated list of entry points and monitoring URLs.
