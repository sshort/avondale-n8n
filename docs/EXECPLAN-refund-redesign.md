# Redesign The Refund Process Around A Single Refund Landing Page

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `/mnt/c/dev/PLAN.md`.

## Purpose / Big Picture

After this change, an operator will manage refunds from one HTML landing page at `/webhook/refunds` instead of jumping between disconnected refund forms and JSON-style workflow responses. From that landing page, the operator will be able to create a new refund case, open an existing refund, preview and edit template-based emails in test or production mode, request bank details from the member, submit the refund request to treasury, and see success or failure messages rendered back into the HTML flow.

This plan assumes the refund feature is still unreleased. That means we do not need to preserve old webhook URLs, old saved links, or perform a cautious staged rollout. We can replace the current refund pages and statuses directly so long as the final behavior works end to end in local n8n and against the local PostgreSQL database.

## Progress

- [x] (2026-04-03 14:35Z) Reviewed the redesign brief in `docs/REFUND_PROCESS_REDESIGN.md`, the current implementation notes in `docs/REFUND-PROCESS.md`, and the current refund schema/workflow files.
- [x] (2026-04-03 14:35Z) Wrote this ExecPlan for the redesign as a concrete implementation plan tied to the current repository files.
- [x] (2026-04-03 12:15Z) Replaced the local refund status model with the redesign lifecycle and mapped existing local refund rows to the new statuses.
- [x] (2026-04-03 12:15Z) Rebuilt `refund-status-form.json` so `/webhook/refunds` is now the operator landing page with status-driven actions and inline message support.
- [x] (2026-04-03 12:15Z) Reworked refund creation so `refund-form` is an HTML create page that posts back into the refunds flow instead of using the old terminal form behavior.
- [x] (2026-04-03 12:15Z) Converted the refund email actions to the shared preview/edit/send pattern with test mode and HTML responses.
- [ ] Verify the full lifecycle locally in test mode: create refund, request bank details, mark bank details obtained, submit treasury request, mark processed or rejected.
- [ ] Update `docs/REFUND-PROCESS.md` after the redesign is implemented so it describes the new flow instead of the old one.

## Surprises & Discoveries

- Observation: The existing implementation already has refund-specific preview/send infrastructure, but it is only partially aligned with the redesign. The repository already contains `workflows/preview-refund-request-email.json`, `workflows/send-refund-request-email.json`, and `sql/034_refund_calculation_member_template.sql`.
  Evidence: `find workflows -maxdepth 1 -type f | rg 'refund'` returns both the legacy create/status workflows and the newer preview/send workflows.

- Observation: The current refund status tracking migration in `sql/033_refunds_add_status_tracking.sql` uses the older lifecycle `Requested | Awaiting Bank Details | Bank Details Received | Ready For Treasury | Sent To Treasury | Paid | Rejected | Cancelled`, which does not match the redesign lifecycle.
  Evidence: The column comment in `sql/033_refunds_add_status_tracking.sql` still names the older statuses, while `docs/REFUND_PROCESS_REDESIGN.md` asks for `New Request`, `Request Bank Details`, `Bank Details Obtained`, `Submitted for Refund`, `Refund Processed`, and `Refund Rejected`.

- Observation: Directly editing `n8n.workflow_entity` is not enough on this n8n build. Production webhooks are served from the published version chain (`workflow_history`, `activeVersionId`, and webhook registrations), and placeholder `versionId` strings break later publishing.
  Evidence: `/webhook/refunds` stayed unregistered until the refund workflows were republished into `workflow_history`, and the UI publish action errored with `Version not found` until `workflow_entity.versionId` was realigned to UUID-backed active versions.

## Decision Log

- Decision: Treat `/webhook/refunds` as the new canonical operator page and replace the current refund status page rather than layering another landing page on top.
  Rationale: The feature is unreleased, so there is no value in preserving multiple operator entry points. One landing page reduces branching and makes error handling easier.
  Date/Author: 2026-04-03 / Codex

- Decision: Keep using the existing `public.refunds` table and current refund workflows where possible, but rewrite them around the redesign lifecycle rather than bolting more states onto the old model.
  Rationale: The redesign brief explicitly says to use the existing refund resource where possible. Reuse is appropriate for the table and several workflows, but the state model must be simplified so the user-facing workflow is coherent.
  Date/Author: 2026-04-03 / Codex

- Decision: Ignore saved-link compatibility and staged rollout concerns.
  Rationale: The user clarified that this is an unreleased feature, so we can optimize for a clean final design rather than backward compatibility.
  Date/Author: 2026-04-03 / Codex

- Decision: Standardize all refund emails on the existing email-template mechanism with preview-before-send and test mode.
  Rationale: This matches the redesign brief, matches patterns already used elsewhere in this repository, and avoids one-off hardcoded email bodies.
  Date/Author: 2026-04-03 / Codex

- Decision: Add a small repo helper script to sync workflow JSON into the n8n database without overwriting activation/version metadata.
  Rationale: The refund redesign exposed a recurring operational problem: we need to update workflow definitions in the DB while preserving the published-version repair state. A helper that updates only `name`, `nodes`, `connections`, `settings`, and `pinData` is safer than overwriting the whole row.
  Date/Author: 2026-04-03 / Codex

## Outcomes & Retrospective

The redesign is now mostly implemented locally. `/webhook/refunds` serves the new landing page, `refund-form` serves the new create page, and `preview-refund-request-email` serves the new preview/edit/send flow. The biggest work that remains is operational verification of the full lifecycle and then rewriting `docs/REFUND-PROCESS.md` so the documentation stops describing the old flow.

## Context and Orientation

The refund feature in this repository is built from three kinds of assets: PostgreSQL schema migrations in `/mnt/c/dev/avondale-n8n/sql`, n8n workflow definitions in `/mnt/c/dev/avondale-n8n/workflows`, and descriptive notes in `/mnt/c/dev/avondale-n8n/docs`.

The database table is `public.refunds`, originally created in `sql/030_refunds.sql` and later extended by `sql/033_refunds_add_status_tracking.sql`. That table stores one refund case per row. In this repository, a “refund case” means a single membership refund request with enough data to calculate a refund amount, track its progress, and record the email messages sent during the process.

The main refund workflows currently checked in are:

- `/mnt/c/dev/avondale-n8n/workflows/refund-form.json`
- `/mnt/c/dev/avondale-n8n/workflows/add-refund.json`
- `/mnt/c/dev/avondale-n8n/workflows/refund-status-form.json`
- `/mnt/c/dev/avondale-n8n/workflows/update-refund-status.json`
- `/mnt/c/dev/avondale-n8n/workflows/preview-refund-request-email.json`
- `/mnt/c/dev/avondale-n8n/workflows/send-refund-request-email.json`
- `/mnt/c/dev/avondale-n8n/workflows/send-treasury-refund-request.json`

The current user-facing behavior is split across multiple pages. `refund-form` creates refunds. `refund-status-form` lists refunds and offers management actions. Email preview and email send are separate workflows. Some responses are HTML pages, but the redesign asks for all operator-visible flows to stay inside a coherent HTML experience and to avoid JSON responses in the browser window.

The redesign brief in `/mnt/c/dev/avondale-n8n/docs/REFUND_PROCESS_REDESIGN.md` requires the following user-visible changes:

- a home page at `/refunds`
- action buttons based on the current refund status
- a create-refund page that returns messages to the home page
- member and requestor lookup by name or email, with free-form override
- request-bank-details email preview and send
- submit-refund-request email preview and send
- test mode for all email actions
- HTML success and error handling throughout

In this repository, “email template mechanism” means the `public.email_templates` table plus preview/send workflows that load a template row, render tokens into a subject and message, show the rendered content in an HTML form, and send the final edited message via Gmail. The new refund design must use that pattern instead of hardcoded one-off email messages.

## Plan of Work

The implementation starts in the database because the status lifecycle is the contract used by the HTML page and the action buttons. Add a new migration after `sql/034_refund_calculation_member_template.sql`; use `sql/035_...` for the next refund redesign migration. That migration must normalize `public.refunds.status` into the redesign lifecycle:

- `New Request`
- `Request Bank Details`
- `Bank Details Obtained`
- `Submitted for Refund`
- `Refund Processed`
- `Refund Rejected`

The migration must also map existing local rows from the older statuses into the new set. Because this feature is unreleased, there is no need to preserve the old textual status labels. The simplest mapping is:

- `Requested` and `Awaiting Bank Details` -> `Request Bank Details`
- `Bank Details Received` and `Ready For Treasury` -> `Bank Details Obtained`
- `Sent To Treasury` -> `Submitted for Refund`
- `Paid` -> `Refund Processed`
- `Rejected` and `Cancelled` -> `Refund Rejected`

Use `New Request` as the initial status for newly created refunds. The create workflow must stop using `Requested` and must write `New Request` instead.

Once the table status contract is correct, rebuild the landing page in `workflows/refund-status-form.json`. Rename the user-facing page title and rendered navigation so this workflow becomes the landing page at `/webhook/refunds`. If the current webhook path is easier to keep in the JSON definition during development, that is acceptable temporarily, but the final workflow must expose `/webhook/refunds` as the operator entry point. The page should list refunds, show their current status, and show only the buttons relevant to that status. At minimum, each refund row or refund detail panel must decide:

- show `Request Bank Details` for `New Request` and `Request Bank Details`
- show `Submit Refund Request` for `Bank Details Obtained` and `Submitted for Refund`
- show `Mark Refund Processed` for `Submitted for Refund`
- show `Reject Refund` for any pre-processed state where rejection still makes sense

The landing page must also reserve a banner area for `success` and `error` messages from other refund actions. Use query parameters such as `?message=` and `?error=` or another simple HTML-safe mechanism. Since the feature is unreleased, prefer one obvious pattern and use it consistently across create, send-email, and status-change workflows.

After the landing page exists, rework refund creation. The existing pair `refund-form.json` and `add-refund.json` should be preserved only if they still make the implementation clearer. The redesign requirement is behavioral, not architectural: the operator clicks `Create Refund Request` from the landing page, completes a create page, and lands back on `/refunds` with a success or error message. The create page should allow searching by name or email for both the member and the requestor, while still allowing free-form entry. In practice, the easiest implementation is likely one GET page with optional search controls and standard text inputs that the operator can override manually. The acceptance criterion is not autocomplete sophistication; it is that the operator can quickly populate those names from current member/contact data without losing the ability to type a value directly.

Next, standardize the email flows. The current repository already has one preview/send pair for refund request emails, but the redesign needs two operator actions with the same shape:

- request bank details from the member
- submit the refund request to treasury

Each action should have a preview workflow and a send workflow, or one shared preview/send workflow keyed by action type if that results in less duplication. Use the existing `public.email_templates` table and append the signature template during rendering. Each preview page must allow the operator to edit the rendered subject and message before sending. Each send action must allow test mode and must redirect back to the landing page with a success or failure message rather than showing raw JSON.

The bank-details request action should update the refund status only after the email send succeeds. The target status after a successful send should be `Request Bank Details`. The treasury request action should update the refund status only after the email send succeeds. The target status after a successful treasury send should be `Submitted for Refund`.

The landing page also needs lightweight state transitions that do not send email. The clearest example is `Bank Details Obtained`. That should be an explicit operator action, probably a small POST form from the refund detail area, that updates the refund status and any note fields needed for audit. Do not store full bank details in `public.refunds`. If there is already a pattern for storing a message identifier or a note about how the bank details were received, keep using that pattern.

Finally, clean up the old documentation. `docs/REFUND-PROCESS.md` currently describes the older architecture and state names. Once the redesign is working, update that document so it matches the new landing page, new statuses, and new email actions. The redesign brief in `docs/REFUND_PROCESS_REDESIGN.md` can remain as the original requirement note; it should not become the source of truth after implementation.

## Concrete Steps

Work from the repository root:

    cd /mnt/c/dev/avondale-n8n

Inspect the current refund schema and workflow assets before editing:

    sed -n '1,220p' sql/030_refunds.sql
    sed -n '1,220p' sql/033_refunds_add_status_tracking.sql
    jq -r '.name, (.nodes[]?.name // empty)' workflows/refund-status-form.json
    jq -r '.name, (.nodes[]?.name // empty)' workflows/send-refund-request-email.json

Create the next migration file for the status redesign and apply it to the local database. The exact apply command depends on the operator’s current database tooling, but the implementation must leave local `public.refunds.status` using only the redesign statuses.

Update the refund workflows in this order:

1. `workflows/add-refund.json`
2. `workflows/refund-status-form.json`
3. `workflows/update-refund-status.json`
4. `workflows/preview-refund-request-email.json`
5. `workflows/send-refund-request-email.json`
6. `workflows/send-treasury-refund-request.json`

After editing each workflow JSON file, validate it structurally:

    jq empty workflows/add-refund.json
    jq empty workflows/refund-status-form.json
    jq empty workflows/update-refund-status.json
    jq empty workflows/preview-refund-request-email.json
    jq empty workflows/send-refund-request-email.json
    jq empty workflows/send-treasury-refund-request.json

Once the JSON files are valid, push the changed workflow definitions into local n8n using the same deployment approach already used elsewhere in this repository. The operator implementing the plan must verify the live local workflow behavior through the HTML pages, not only by saving JSON files in git.

During implementation, keep this plan updated. If you discover that one shared refund email workflow is clearer than two parallel ones, record that in the `Decision Log` and update the relevant sections of this document before proceeding.

## Validation and Acceptance

The redesign is complete only when a person can verify all of the following in local n8n and the local PostgreSQL-backed data set.

First, the landing page loads as HTML at `/webhook/refunds`. It lists refunds and does not show raw JSON.

Second, creating a new refund from the landing page returns the user to the landing page with a visible success banner. If validation fails, the user returns to the landing page or a dedicated HTML status page with a visible error banner. The browser must not land on a JSON payload.

Third, a refund in `New Request` or `Request Bank Details` shows a `Request Bank Details` action. Triggering that action opens an email preview page that:

- loads the correct email template
- appends the signature template
- lets the operator edit subject and message
- supports test mode

Sending in test mode must visibly succeed and must update the refund status to `Request Bank Details`.

Fourth, a refund in `Bank Details Obtained` or `Submitted for Refund` shows a `Submit Refund Request` action. Triggering that action opens the treasury preview page with the same edit-before-send and test-mode behavior. Sending in test mode must visibly succeed and must update the refund status to `Submitted for Refund`.

Fifth, the operator can mark a refund as processed or rejected from the landing page and see the resulting status there without leaving the HTML flow.

Sixth, the only statuses present in local `public.refunds` after migration and testing are:

- `New Request`
- `Request Bank Details`
- `Bank Details Obtained`
- `Submitted for Refund`
- `Refund Processed`
- `Refund Rejected`

Use a direct SQL check to prove that:

    SELECT status, count(*)
    FROM public.refunds
    GROUP BY status
    ORDER BY status;

The expected output must contain only the six redesign statuses above.

## Idempotence and Recovery

This redesign is safe to iterate on locally because the feature is unreleased and the plan explicitly allows replacing the old status model and landing page behavior. However, the status migration still changes persisted refund rows, so take a local database backup before applying the migration if any existing refund rows matter for testing.

The workflow JSON edits are idempotent so long as each updated workflow file is the source of truth. If a local n8n import or activation fails midway, re-import the edited workflow file and re-run the local validation scenario from the landing page.

If the landing page becomes unusable during implementation, the fastest recovery path is:

1. restore the previous workflow JSON from git or from a local backup
2. re-import it into local n8n
3. restore the local database from the pre-migration backup if the status migration has already been applied

Because the feature is unreleased, there is no need to preserve temporary bad states for compatibility.

## Artifacts and Notes

The most important existing artifacts for this redesign are:

- `docs/REFUND_PROCESS_REDESIGN.md`: the user requirement note
- `docs/REFUND-PROCESS.md`: the older implementation note that will need rewriting after completion
- `sql/033_refunds_add_status_tracking.sql`: the current status-tracking migration that must be superseded
- `sql/034_refund_calculation_member_template.sql`: the member-facing refund calculation email template seed

Expected status-migration proof looks like this:

    Request Bank Details|3
    Bank Details Obtained|1
    Submitted for Refund|1
    Refund Processed|2

Expected workflow-structure proof looks like this:

    jq empty workflows/refund-status-form.json
    jq empty workflows/send-refund-request-email.json

Those commands should print nothing and exit with status code `0`.

## Interfaces and Dependencies

The redesign must continue to use:

- PostgreSQL for the `public.refunds` table and supporting email-template data
- n8n webhook workflows for all HTML pages and actions
- the existing `public.email_templates` mechanism for refund emails
- the existing Gmail credential path used by the current refund send workflows

At the end of implementation, the repository should still contain explicit workflow files for refund management under `/mnt/c/dev/avondale-n8n/workflows`, and the local database should still use `public.refunds` as the single refund-case table.

The HTML landing page logic must live in `workflows/refund-status-form.json` unless that workflow is renamed in a deliberate cleanup step. If it is renamed, update this plan and `docs/REFUND-PROCESS.md` so a new contributor can still find the landing page workflow quickly.

Revision note: 2026-04-03. Created this ExecPlan from `docs/REFUND_PROCESS_REDESIGN.md`, the existing refund implementation files, and the user clarification that rollout compatibility is not required because the feature is unreleased.
