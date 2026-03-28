# Agent Instructions for avondale-n8n

This file contains specific instructions for AI agents working on this repository.

## Project Management & Tracking

### Obsidian Kanban Board
- **File**: `/mnt/c/dev/avondale-notes/Dev Kanban.md`
- **Requirement**: Keep this board up to date for **significant functionality changes** and **large effort jobs**.
- **Process**:
    1. **New Card**: Create a new card if one doesn't exist for the task.
    2. **In Progress**: Move the card to `## In Progress` before starting the work.
    3. **Complete**: Move the card to `## Complete` and mark as `[x]` once the task is finished/verified.

## Technical Standards

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
- **Services List**: See **[SERVICES.md](file:///mnt/c/dev/avondale-n8n/SERVICES.md)** for a consolidated list of entry points and monitoring URLs.
