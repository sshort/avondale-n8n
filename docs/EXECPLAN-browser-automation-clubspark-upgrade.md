# Upgrade ClubSpark Exporter To Browser Automation With Payload Credentials

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this change, the local Playwright service in this repository will match the newer `browser-automation` service shape used in `/mnt/c/dev/avondale-deploy` for ClubSpark work, while deliberately preserving the newer local Metabase PDF renderer that already exists in this repository. An operator will be able to run the ClubSpark auth-session, contacts export, members export, and main-contacts export workflows against a `browser-automation` service that accepts a JSON request body, reads ClubSpark and LTA credentials from `public.global_settings`, and exposes both the old compatibility routes and the newer `/jobs/...` routes.

The visible proof is simple. After implementation, a human can execute the ClubSpark auth-session workflow and see it return a reusable authenticated session without relying on container-level ClubSpark credential environment variables. The same person can then run the contacts, members, and main-contacts export workflows and see the CSV imports complete through the new service boundary. The Metabase dashboard PDF workflow must still produce the same PDF output as before because this plan keeps `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs` as the canonical renderer.

## Progress

- [x] (2026-04-28 11:03Z) Compared `/mnt/c/dev/avondale-n8n` against `/mnt/c/dev/avondale-deploy` and confirmed that the primary gap is the HTTP service and packaging layer, not the ClubSpark Playwright export logic.
- [x] (2026-04-28 11:07Z) Confirmed that `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs` is newer and materially different from the deploy-repo version, so the local Metabase PDF script must remain in place.
- [x] (2026-04-28 11:12Z) Confirmed that the current ClubSpark workflows still use `clubspark_exporter_base_url`, legacy `/clubspark-*` routes, and request headers rather than JSON request bodies.
- [x] (2026-04-28 11:18Z) Drafted this ExecPlan for the browser-automation upgrade, including the requested move of ClubSpark and LTA credentials into `public.global_settings`.
- [x] (2026-04-28 11:31Z) Created GitHub issue `#92`, added it to the `avondale-n8n board`, and moved the project item to `In Progress`.
- [x] (2026-04-28 11:50Z) Refined the plan to include a portable repo-relative bind-mount strategy for script iteration without making it a required production deployment mode.
- [ ] Add a SQL migration that seeds `browser_automation_base_url` and the ClubSpark/LTA credential keys in `public.global_settings`.
- [ ] Add the repository-native `browser-automation` packaging and service entry point while preserving the local Metabase PDF script.
- [ ] Update the ClubSpark service wrapper and ClubSpark scripts so JSON payload credentials are supported in this repository.
- [ ] Update the ClubSpark and Metabase-report workflows to load the new settings, send JSON request bodies, and migrate from compatibility aliases to `/jobs/...`.
- [ ] Update the repository build scripts and documentation to describe `browser-automation` as the supported service.
- [ ] Validate the workflow JSON files, service scripts, and database migration, then move the project item to `Done`.

## Surprises & Discoveries

- Observation: the three ClubSpark Playwright scripts are already effectively aligned between the two repositories.
  Evidence: `diff -u` between the local and deploy-repo versions of `export-clubspark-contacts-local.mjs`, `export-clubspark-members-local.mjs`, and `export-clubspark-auth-session-local.mjs` returned no differences during research.

- Observation: the major implementation gap is the service shell, not the browser automation itself.
  Evidence: `/mnt/c/dev/avondale-n8n/scripts/clubspark-export-server.mjs` only exposes legacy routes and does not map JSON credential fields into the runtime environment, while `/mnt/c/dev/avondale-deploy/browser-automation/scripts/browser-automation-server.mjs` adds `GET /jobs`, `/jobs/...` routes, and payload-to-environment credential mapping.

- Observation: the local Metabase PDF renderer must not be replaced wholesale.
  Evidence: the local `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs` contains substantial newer logic that is absent from the deploy-repo copy, including more advanced dashcard snapshotting and redaction-path behavior.

- Observation: the current local workflows are header-driven and only indirectly payload-aware.
  Evidence: the checked-in ClubSpark workflows POST to legacy routes such as `/clubspark-members-export` and pass `X-ClubSpark-Target-Url`, `X-ClubSpark-Cookie-Header`, and `X-ClubSpark-User-Agent` headers rather than JSON `targetUrl`, `cookieHeader`, and `userAgent` fields.

- Observation: the current local stack stores ClubSpark and LTA credentials in Docker environment variables, not in workflow-accessible settings.
  Evidence: `/mnt/c/dev/avondale-n8n/docker-compose.yml` currently sets `CLUBSPARK_EMAIL`, `CLUBSPARK_PASSWORD`, `LTA_USERNAME`, and `LTA_PASSWORD` on the `clubspark-exporter` container, while `/mnt/c/dev/avondale-n8n/sql/009_global_settings.sql` does not contain any credential keys.

- Observation: a portable bind mount can be repo-relative, but the worker process must not use a read-only mounted script directory as its writable working directory.
  Evidence: the ClubSpark export scripts write failure screenshots such as `clubspark-export-debug.png` and `clubspark-members-export-debug.png` using `path.resolve('./...')`, so a future read-only script mount requires a separate writable process cwd such as `/tmp`.

## Decision Log

- Decision: keep `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs` as the canonical Metabase PDF renderer and only migrate its service route and packaging context.
  Rationale: the local script is newer than the deploy-repo copy, so replacing it would risk losing already-developed behavior while solving the wrong problem.
  Date/Author: 2026-04-28 / Codex

- Decision: add a new `browser_automation_base_url` setting instead of mutating every consumer to reuse `clubspark_exporter_base_url` forever.
  Rationale: the new service is not only a rename; it is a different contract with a broader job surface. A new key makes the target architecture explicit, while compatibility logic can still read the old key during rollout.
  Date/Author: 2026-04-28 / Codex

- Decision: store `clubspark_email`, `clubspark_password`, `lta_username`, and `lta_password` in `public.global_settings` because the user explicitly requested that the workflows load credentials from global settings.
  Rationale: this is not the ideal secret-management model, but it is the required design for this work. The implementation must therefore move the operational credential source from container environment variables into workflow-loaded database settings.
  Date/Author: 2026-04-28 / Codex

- Decision: make the ClubSpark service support both payload-driven credentials and environment-variable fallback.
  Rationale: the workflows should move to JSON-body credentials from `global_settings`, but local direct script execution and phased rollout are safer if the service and scripts continue to tolerate the older environment-driven path.
  Date/Author: 2026-04-28 / Codex

- Decision: perform the workflow cutover in two layers: first move callers onto the new base URL and JSON body while the compatibility aliases still work, then switch the endpoints to `/jobs/...`.
  Rationale: this reduces blast radius. A broken route migration and a broken payload migration should not happen in the same opaque step if avoidable.
  Date/Author: 2026-04-28 / Codex

- Decision: plan for a portable development-time script mount using a repo-relative bind mount such as `./scripts:/app/runtime-scripts:ro`, but keep baked-in fallback scripts in the image so the mount is optional.
  Rationale: this gives faster iteration when the container runs from a checked-out repository on any host, without making the deployment depend on one specific machine path or on the mount always being present.
  Date/Author: 2026-04-28 / Codex

## Outcomes & Retrospective

This plan is at the design stage. The repository comparison is complete and the scope is now explicit: preserve the local Metabase PDF script, upgrade the ClubSpark service contract to `browser-automation`, move ClubSpark and LTA credentials into `public.global_settings`, and migrate the workflows to JSON request bodies and new route names. The remaining work is issue tracking, implementation, and end-to-end validation.

## Context and Orientation

The repository to change is `/mnt/c/dev/avondale-n8n`. The local Playwright-backed HTTP service currently lives in two places. The container packaging is under `/mnt/c/dev/avondale-n8n/clubspark-exporter`, and the HTTP entry point is `/mnt/c/dev/avondale-n8n/scripts/clubspark-export-server.mjs`. That server currently exposes the legacy routes `POST /clubspark-export`, `POST /clubspark-members-export`, `POST /clubspark-members-main-contacts-export`, `POST /clubspark-auth-session`, and `POST /metabase-dashboard-pdf`.

The browser automation scripts that do the real ClubSpark work are `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-contacts-local.mjs`, `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-members-local.mjs`, and `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-auth-session-local.mjs`. These scripts currently expect credentials through environment variables such as `CLUBSPARK_EMAIL` and `LTA_USERNAME`. The Metabase PDF job is implemented separately in `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs`.

The term “payload” in this plan means the JSON body sent to the Playwright HTTP service. The term “legacy alias” means an older endpoint path that the new service keeps temporarily so that callers do not all need to change at once. The term “global settings” means rows in the database table `public.global_settings`, which is seeded by `/mnt/c/dev/avondale-n8n/sql/009_global_settings.sql` and loaded at runtime by several checked-in n8n workflows.

The checked-in workflows that matter here are:

- `/mnt/c/dev/avondale-n8n/workflows/clubspark-auth-session.json`
- `/mnt/c/dev/avondale-n8n/workflows/clubspark-contacts-export.json`
- `/mnt/c/dev/avondale-n8n/workflows/clubspark-members-export.json`
- `/mnt/c/dev/avondale-n8n/workflows/clubspark-main-contacts-export.json`
- `/mnt/c/dev/avondale-n8n/workflows/clubspark-full-refresh.json`
- `/mnt/c/dev/avondale-n8n/workflows/metabase-report-generate.json`

Each of the four ClubSpark workflows currently queries `clubspark_exporter_base_url` from `public.global_settings`, then calls the old `clubspark-exporter` routes. They do not currently read ClubSpark or LTA credentials from the database. The Metabase report workflow also queries `clubspark_exporter_base_url` and posts JSON to `/metabase-dashboard-pdf`. That workflow already sends a JSON body and already has the data the renderer needs, so its main migration is to use the new service name and route while keeping the renderer code itself unchanged.

The target reference implementation lives in `/mnt/c/dev/avondale-deploy/browser-automation`. Its server wrapper is `/mnt/c/dev/avondale-deploy/browser-automation/scripts/browser-automation-server.mjs`, and its Docker packaging is `/mnt/c/dev/avondale-deploy/docker/browser-automation.Dockerfile`. That reference adds `GET /jobs`, standardizes the container on port `3000`, uses `BROWSER_AUTOMATION_TOKEN`, and accepts ClubSpark credentials in the JSON body under `credentials.clubspark` and `credentials.lta`. This plan imports that contract into the current repository without discarding the local Metabase renderer.

## Plan of Work

Begin with tracking and schema. This tracking step is already opened as GitHub issue `#92`, which is on the `avondale-n8n board` and marked `In Progress`. Keep that issue updated as work proceeds, and attach it to the existing ClubSpark parent issue if helpful. Then add a new SQL migration under `/mnt/c/dev/avondale-n8n/sql`. That migration must seed `browser_automation_base_url` with `http://browser-automation:3000` and also add four credential keys to `public.global_settings`: `clubspark_email`, `clubspark_password`, `lta_username`, and `lta_password`. The migration should preserve the existing `clubspark_exporter_base_url` row during the transition. The implementation may later stop using that older key, but this plan does not delete it during the first rollout.

Next, replace the packaging boundary. Create a new repository-local `browser-automation` directory modeled after the deploy repository packaging layout. This should include a package manifest and a service entry point called `browser-automation-server.mjs`. The new Docker build should live in a new path such as `/mnt/c/dev/avondale-n8n/browser-automation` plus a matching Dockerfile, or another repo-local structure that clearly supersedes `/mnt/c/dev/avondale-n8n/clubspark-exporter`. The resulting container should listen on port `3000` internally, expose `GET /health`, expose `GET /jobs`, and publish the job routes:

- `POST /jobs/clubspark/contacts/export`
- `POST /jobs/clubspark/members/export`
- `POST /jobs/clubspark/members/main-contacts/export`
- `POST /jobs/clubspark/auth-session`
- `POST /jobs/metabase/dashboard-pdf`

The service must also retain the old aliases `/clubspark-export`, `/clubspark-members-export`, `/clubspark-members-main-contacts-export`, `/clubspark-auth-session`, and `/metabase-dashboard-pdf` so the migration can proceed safely. The route handler for the Metabase job must continue to invoke `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs`, not the older deploy-repo version.

When designing that packaging boundary, treat script mounting as an optional development and operations convenience, not as a hard requirement for correctness. The image should still contain a working copy of the server wrapper and job scripts so it can run without any bind mount. In addition, the compose definition for repository-based deployments should support a portable repo-relative mount of the checked-out scripts directory, for example `./scripts:/app/runtime-scripts:ro`. The service entry point should prefer the mounted script directory when present and fall back to the baked-in scripts when it is absent. This is how the same container design remains portable across hosts: the compose file uses a relative path rooted at the repository checkout, not a workstation-specific absolute path.

Because the ClubSpark worker scripts write debug screenshots on failure, the process model must also separate script location from writable working directory. In plain language, the scripts may be read from `/app/runtime-scripts`, but the child `node` processes should run with a writable cwd such as `/tmp` or another writable application work directory so failure artifacts do not try to write into a read-only bind mount.

After the container boundary exists, add payload-driven credential handling for ClubSpark. The server wrapper must accept JSON request bodies that contain:

    {
      "targetUrl": "https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Contacts",
      "cookieHeader": "...",
      "userAgent": "...",
      "credentials": {
        "clubspark": {
          "email": "...",
          "password": "..."
        },
        "lta": {
          "username": "...",
          "password": "..."
        }
      }
    }

The exact JSON syntax above is illustrative; the real file must be valid JSON with commas between fields. The service should support the same path variants as the deploy repository, meaning it should accept both nested fields such as `credentials.clubspark.email` and flat fields such as `clubsparkEmail` if present. The three ClubSpark scripts should also be updated so that when `EXPORTER_PAYLOAD_JSON` is present they can read credentials from the request payload directly, then fall back to the environment variables if a field is absent. This keeps the direct-script path usable while ensuring this repository truly supports payload credentials rather than only having a clever server-side shim.

With the service updated, migrate the workflows. First update the workflow settings loads so they retrieve `browser_automation_base_url` and the four new credential rows from `public.global_settings`. For the ClubSpark workflows, replace the current header-only requests with JSON request bodies that carry `targetUrl`, cached-session details such as `cookieHeader` and `userAgent` when available, and the credential object built from the settings rows. Preserve the reusable session behavior. The auth-session workflow should obtain a new browser session using credentials from the JSON body, cache `cookieHeader` and `userAgent`, and return the same reusable session structure the downstream export workflows already expect.

During the first workflow edit, keep the URLs on compatibility aliases if that makes verification easier, but the completed plan must finish on `/jobs/...` routes and the new `browser_automation_base_url` key. The final steady-state routes are:

- contacts export: `/jobs/clubspark/contacts/export`
- members export: `/jobs/clubspark/members/export`
- main-contacts export: `/jobs/clubspark/members/main-contacts/export`
- auth session: `/jobs/clubspark/auth-session`
- Metabase PDF: `/jobs/metabase/dashboard-pdf`

The Metabase report workflow should be migrated more conservatively. Update it to load `browser_automation_base_url`, call the new Metabase job route, and continue sending the same JSON body it sends today. Do not replace or simplify `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs`. The purpose of this step is only to align the service boundary and naming.

Finally, update the rest of the repository narrative so a novice can follow it. Replace `clubspark-exporter` references in `/mnt/c/dev/avondale-n8n/workflows/README.md`, `/mnt/c/dev/avondale-n8n/docs/CLUB_SPARK_EXPORT_INSTRUCTIONS.md`, `/mnt/c/dev/avondale-n8n/docs/SERVICES.md`, and any build helper scripts that still point at `clubspark-exporter`. The local Docker helper that currently builds `clubspark-exporter` should build the new `browser-automation` image instead. The local docker-compose stack should stop supplying ClubSpark and LTA credentials as container environment variables once the workflows are proven to load them from `public.global_settings`; `METABASE_BASE_URL` can remain as an environment variable because the user explicitly asked only for the ClubSpark and LTA credential move.

## Concrete Steps

Work from `/mnt/c/dev/avondale-n8n`.

Create or update project tracking first. If there is no existing issue dedicated to this upgrade, create one and add it to the board:

    cd /mnt/c/dev/avondale-n8n
    gh issue create \
      --title "Upgrade ClubSpark exporter to browser-automation contract" \
      --label enhancement \
      --label feature:clubspark-sync \
      --body-file /tmp/browser-automation-upgrade-issue.md

After issue creation, add it to the GitHub Project and set the status to `In Progress`. Record the issue number in this plan and in the `Progress` section.

Create the new SQL migration after the latest numbered migration in `/mnt/c/dev/avondale-n8n/sql`. The migration should upsert these keys:

    browser_automation_base_url = http://browser-automation:3000
    clubspark_email = <placeholder or current value>
    clubspark_password = <placeholder or current value>
    lta_username = <placeholder or current value>
    lta_password = <placeholder or current value>

Build the new packaging boundary and validate the JSON manifests:

    cd /mnt/c/dev/avondale-n8n
    jq empty browser-automation/package.json
    node --check browser-automation/scripts/browser-automation-server.mjs
    node --check scripts/export-clubspark-auth-session-local.mjs
    node --check scripts/export-clubspark-contacts-local.mjs
    node --check scripts/export-clubspark-members-local.mjs
    node --check scripts/export-metabase-dashboard-pdf.mjs

If the implementation includes the planned optional script mount, validate both startup modes. First verify the image-only path with no bind mount. Then verify the repo-relative mount path with a compose or compose-override file rooted in the repository checkout, not in a machine-specific absolute path. In the mount-enabled case, edit one of the mounted ClubSpark job scripts and confirm that the next request uses the new file without rebuilding the image. If the server wrapper itself changes, expect a container restart but not an image rebuild.

Validate each edited workflow export after every change:

    cd /mnt/c/dev/avondale-n8n
    jq empty \
      workflows/clubspark-auth-session.json \
      workflows/clubspark-contacts-export.json \
      workflows/clubspark-members-export.json \
      workflows/clubspark-main-contacts-export.json \
      workflows/clubspark-full-refresh.json \
      workflows/metabase-report-generate.json

Once the service container is buildable, verify the route surface locally or in the target stack:

    curl -sS http://browser-automation:3000/health
    curl -sS http://browser-automation:3000/jobs

The expected successful `/health` result is JSON that clearly identifies the service, for example:

    {"status":"ok","service":"browser-automation"}

The expected successful `/jobs` result is JSON listing the available `/jobs/...` routes. If `/jobs` is missing or returns only legacy routes, the new service wrapper is incomplete.

After the workflow migration, run the auth-session workflow first. The expected result is a JSON payload with `authenticated: true`, plus `cookieHeader` and `userAgent`. Then run the contacts, members, and main-contacts workflows. The expected result is the same user-visible behavior as today: CSV retrieval, parsing, and import into the target raw tables without relying on container-level ClubSpark credentials.

Run the Metabase report workflow last. The expected result is that the workflow still receives a PDF binary and that no feature regression appears in the final output compared with the current local behavior. If the PDF output changes materially, stop and compare the service wrapper wiring before touching the renderer itself.

## Validation and Acceptance

Acceptance is complete only when a human can verify all of the following behaviors.

First, the `browser-automation` service must exist and describe itself correctly. A request to `GET /health` must return HTTP `200` and JSON identifying the service as `browser-automation`. A request to `GET /jobs` must return the ClubSpark and Metabase job routes listed earlier in this plan.

Second, the ClubSpark auth-session workflow must succeed using credentials loaded from `public.global_settings`. To prove that, the service should no longer depend on `CLUBSPARK_EMAIL`, `CLUBSPARK_PASSWORD`, `LTA_USERNAME`, or `LTA_PASSWORD` being set in the container environment for the workflow path. A successful auth-session run must still return `authenticated: true`, `cookieHeader`, and `userAgent`, and the later export workflows must be able to reuse that session.

Third, the contacts, members, and main-contacts workflows must complete end to end through the new service contract. The proof is the same observable behavior the current flows provide: the CSV is returned, parsed, and loaded into the raw import tables and reconciliation path without a login failure or an HTML sign-in page being mistaken for CSV.

Fourth, the Metabase report workflow must still produce a PDF by calling the new `browser-automation` service boundary. The output should continue to reflect the local `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs` behavior, not the older deploy-repo script.

Repository acceptance requires `jq empty` to pass for all changed workflow JSON files, `node --check` to pass for all changed service and script files, and the new SQL migration to be syntactically valid and idempotent.

## Idempotence and Recovery

This plan is designed to be implemented additively. Keep the legacy route aliases while the workflows move to JSON bodies and new setting keys. Keep the old `clubspark_exporter_base_url` row during the transition. Keep environment-variable fallback in the service and scripts until the new payload-driven path is verified. These choices make it possible to retry the migration without leaving the repository or live stack in a broken half-state.

The optional script-mount path should also be additive. The image must still work with no bind mount. That makes recovery simple: if a host-specific compose override, a read-only mount, or a bad checked-out script causes trouble, disable the mount and run the baked-in scripts while continuing to use the same image and workflow contract.

If the new `browser-automation` service boots but a workflow fails, point the workflow back to the compatibility alias or old base URL temporarily while debugging the JSON request body. If the workflow migration succeeds but the service naming update is incomplete, keep the legacy `clubspark-exporter` image build available long enough to compare behavior. Do not remove the old documentation or build helper until the new service and workflows have both been validated.

Because this plan deliberately places ClubSpark and LTA credentials into `public.global_settings`, recovery from a bad migration must include checking that those rows exist and are readable by the workflows. If a credential row is missing, the workflows should fail loudly with a clear validation error rather than quietly falling back to an empty string. A retry should only require updating the row and re-running the workflow.

## Artifacts and Notes

The current and target route surfaces can be summarized briefly.

Current local surface:

    POST /clubspark-export
    POST /clubspark-members-export
    POST /clubspark-members-main-contacts-export
    POST /clubspark-auth-session
    POST /metabase-dashboard-pdf

Target steady-state surface:

    GET /health
    GET /jobs
    POST /jobs/clubspark/contacts/export
    POST /jobs/clubspark/members/export
    POST /jobs/clubspark/members/main-contacts/export
    POST /jobs/clubspark/auth-session
    POST /jobs/metabase/dashboard-pdf

The final ClubSpark request body should carry both session reuse fields and credentials. A representative example is:

    {
      "targetUrl": "https://clubspark.lta.org.uk/AvondaleTennisClub/Admin/Membership/Members",
      "cookieHeader": "<cached-cookie-header-or-empty>",
      "userAgent": "<cached-user-agent-or-empty>",
      "credentials": {
        "clubspark": {
          "email": "<value from global_settings.clubspark_email>",
          "password": "<value from global_settings.clubspark_password>"
        },
        "lta": {
          "username": "<value from global_settings.lta_username>",
          "password": "<value from global_settings.lta_password>"
        }
      }
    }

The final Metabase request body should stay structurally the same as the one already produced by `workflows/metabase-report-generate.json`; only the base URL key and endpoint path should change. That is the operational meaning of “use the avondale-n8n Metabase script as is.”

The planned portable mount strategy can be summarized briefly:

    image contains:
      /app/default-scripts/<server-and-job-scripts>

    optional repo-relative compose mount:
      ./scripts:/app/runtime-scripts:ro

    runtime rule:
      if /app/runtime-scripts exists with the required files, prefer it
      otherwise run the baked-in /app/default-scripts copy

    worker rule:
      child job processes read scripts from the selected script directory
      but run with a separate writable cwd such as /tmp

## Interfaces and Dependencies

The service layer must end with a repository-local `browser-automation` package and a server entry point that mirrors the deploy-repo contract while calling the local scripts. The authoritative local scripts after implementation are:

- `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-auth-session-local.mjs`
- `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-contacts-local.mjs`
- `/mnt/c/dev/avondale-n8n/scripts/export-clubspark-members-local.mjs`
- `/mnt/c/dev/avondale-n8n/scripts/export-metabase-dashboard-pdf.mjs`

The workflow layer must continue using the checked-in Postgres credential already present in this repository. The SQL settings load nodes must fetch both service URLs and the new credential rows from `public.global_settings`.

The database layer depends on `public.global_settings`, which was created in `/mnt/c/dev/avondale-n8n/sql/009_global_settings.sql`. The new migration must use `INSERT ... ON CONFLICT ... DO UPDATE` so it can be re-run safely.

The container layer must continue to provide `METABASE_BASE_URL` to the service, because the Metabase PDF renderer still uses that as an environment fallback. ClubSpark and LTA credentials, however, should no longer be required as container environment variables once the workflow path is fully migrated.

Revision note: created this plan after comparing the local repository with `/mnt/c/dev/avondale-deploy`, confirming that the service wrapper and workflow contract are the main migration target, and incorporating the user’s explicit requirements to keep the local Metabase renderer and move ClubSpark/LTA credentials into `public.global_settings`.
Revision note: updated the plan after creating GitHub issue `#92` and moving the matching project item to `In Progress`, so the living-document status matches the actual board state.
Revision note: updated the plan to capture a portable repo-relative script-mount strategy as an optional implementation detail, including the need for a writable worker cwd separate from a read-only script mount.
