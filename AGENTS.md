# Agent Instructions for avondale-n8n

This file contains specific instructions for AI agents working on this repository.

## Project Management & Tracking

### Planka Board
- **Project**: `Avondale`
- **Board**: `Dev Kanban`
- **URL**: `http://192.168.1.139/boards/1749307018184754195`
- **Requirement**: Keep this board up to date for **significant functionality changes** and **large effort jobs**.
- **Process**:
    1. **New Card**: Create a new card in Planka if one does not exist for the task.
    2. **Categorisation**: Add one or more relevant Planka labels so the task is clearly categorised.
    3. **In Progress**: Move the card to the `In Progress` list before starting the work.
    4. **Complete**: Move the card to the `Complete` list once the task is finished and verified.
- **Notes**:
    1. Keep notes in the Planka card description/checklists where practical.
    2. Markdown notes can also be kept in `/mnt/c/dev/avondale-notes/kanban-notes` and `/mnt/c/dev/avondale-notes/kanban-completed` when a longer working note is useful.
    3. When a card is moved to `In Progress`, create or update the matching note content in Planka and, if used, in `kanban-notes`.
    4. When a card is moved to `Complete`, ensure the final notes are present in Planka and, if a markdown note exists, move it into `kanban-completed`.
    5. Treat Planka as the source of truth for task state; markdown files are optional supporting notes.

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
