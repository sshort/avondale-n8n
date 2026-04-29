# Replace Test And Production Mode With Runtime-Aware Profiles

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with [/mnt/c/dev/PLAN.md](/mnt/c/dev/PLAN.md).

## Purpose / Big Picture

After this change, the repository will stop treating outbound behavior as a binary `test` versus `production` switch and will instead resolve behavior from two explicit axes:

- `runtime_environment`: where the stack is running, such as `homelab` or `hetzner`
- `profile`: how the action should behave, such as `dev`, `test`, or `production`

The visible proof is straightforward. A page such as the Team Management mailout view will show a profile selector instead of a test-mode checkbox. Choosing `dev`, `test`, or `production` will consistently change the resolved URLs, recipients, sender settings, and any profile-scoped credential references without every workflow having to hand-roll its own mode logic. The same repository should be able to run in the home lab or on Hetzner and derive its default runtime environment from configuration, while still allowing the operator to choose a non-default profile explicitly when that is safe.

This plan deliberately separates environment from profile. `homelab` versus `hetzner` is not the same decision as `dev` versus `test` versus `production`. If those concerns are collapsed into one field, the system quickly becomes awkward and unsafe because names like `homelab-test` and `hetzner-test` start leaking into every workflow and UI.

## Progress

- [x] (2026-04-29 13:40Z) Confirmed issue `#91` is the correct tracker for replacing test and production modes with profiles.
- [x] (2026-04-29 13:44Z) Confirmed the current binary mode logic is duplicated across multiple workflow exports and is not limited to a single app or webhook.
- [x] (2026-04-29 13:49Z) Confirmed the current settings surface is centered on `email_delivery_mode`, `email_test_recipient`, and `n8n_base_url`, with request-time `test_mode` and `delivery_mode` flags layered on top.
- [x] (2026-04-29 13:56Z) Drafted this ExecPlan for a runtime-aware profile model built around `runtime_environment + profile` resolution rather than a single flat mode field.

## Surprises & Discoveries

- Observation: the current `test` versus `production` concept is duplicated in many workflows rather than being resolved once in a shared helper.
  Evidence: repository search showed current mode handling in `team-management-app`, `generate-team-contact-sheets`, `send-team-captain-contact-lists`, `send-no-address-batch-emails`, `send-member-template-email`, `send-case-tracking-email`, refund email flows, case tracking pages, and preview pages.

- Observation: some of the existing mode-related settings are not really “mode” settings at all; they are environment- or transport-specific defaults.
  Evidence: `n8n_base_url` is currently loaded alongside `email_delivery_mode` and `email_test_recipient`, but `n8n_base_url` is about where the app is running, not whether the operator wants a test send.

- Observation: profile-based URLs and recipients are easy to scope, but profile-based credentials are not uniformly easy because many n8n nodes bind credentials statically in workflow JSON.
  Evidence: send workflows such as `send-member-template-email`, `send-case-tracking-email`, `send-no-address-batch-emails`, `send-team-captain-contact-lists`, and refund workflows contain explicit `credentials` blocks in the exported workflow JSON.

- Observation: the current Team Management mailout app is the clearest first migration target because it exposes the old test-mode concept directly in the UI and feeds it into downstream send flows.
  Evidence: `team-management-app.json` currently resolves `delivery_mode` from query params and `email_delivery_mode`, and the page renders a mode control rather than a profile selector.

## Decision Log

- Decision: model this as two axes, `runtime_environment` and `profile`, rather than replacing `test|production` with only `dev|test|production`.
  Rationale: the same profile names must be usable in more than one deployment location. Environment and behavior are different decisions and should remain independently resolvable.
  Date/Author: 2026-04-29 / Codex

- Decision: allow the runtime environment to be derived from deployment context, but do not allow profile selection to be derived implicitly in a safety-critical way.
  Rationale: deriving `homelab` versus `hetzner` from an explicit environment variable is reasonable. Deriving `production` automatically from host location is not safe enough for outbound email or credential selection.
  Date/Author: 2026-04-29 / Codex

- Decision: make profile resolution additive and backward compatible for one rollout window.
  Rationale: existing flows currently send `test_mode` or `delivery_mode`. A safe migration must accept old inputs while the UI and downstream workflows move to `profile`.
  Date/Author: 2026-04-29 / Codex

- Decision: start with a shared profile resolver before changing UI pages broadly.
  Rationale: the current mode logic is duplicated across many workflows. If the UI changes first, each page will continue carrying its own custom rules and the migration will drift.
  Date/Author: 2026-04-29 / Codex

- Decision: scope credential profiling narrowly and centrally instead of trying to make every node’s credential binding dynamic in one pass.
  Rationale: URLs, recipients, sender names, reply-to addresses, and service endpoints can be resolved from settings cheaply. Arbitrary per-profile switching of n8n credential IDs is harder because many nodes bind credentials statically in workflow JSON. The first implementation should route credential-sensitive behavior through a smaller number of shared send/core workflows.
  Date/Author: 2026-04-29 / Codex

## Outcomes & Retrospective

_To be filled in after implementation._

## Context and Orientation

The existing binary mode model currently appears in three forms.

First, there are flat global settings:

- `email_delivery_mode`
- `email_test_recipient`
- `n8n_base_url`
- related sender defaults such as `email_sender_name` and `email_reply_to`

Second, there are request-time flags and fields:

- `test_mode`
- `delivery_mode`
- `test_recipient`

Third, there are page-level controls and workflow-local normalization rules that convert those fields into `test` or `production`.

The most visible current entry points are:

- [team-management-app.json](/mnt/c/dev/avondale-n8n/workflows/team-management-app.json)
- [generate-team-contact-sheets.json](/mnt/c/dev/avondale-n8n/workflows/generate-team-contact-sheets.json)
- [send-team-captain-contact-lists.json](/mnt/c/dev/avondale-n8n/workflows/send-team-captain-contact-lists.json)
- [send-no-address-batch-emails.json](/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json)
- [case-tracking-app.json](/mnt/c/dev/avondale-n8n/workflows/case-tracking-app.json)
- [send-case-tracking-email.json](/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json)
- [send-member-template-email.json](/mnt/c/dev/avondale-n8n/workflows/send-member-template-email.json)
- refund preview/send flows

The tracked product requirement from issue `#91` is concise: create profiles and update pages that currently use test mode so they select a profile instead.

The missing detail is the data model. This plan proposes the minimum robust model:

- runtime environments: `homelab`, `hetzner`
- delivery profiles: `dev`, `test`, `production`
- resolved values: URLs, recipients, sender details, and selected credential references

## Target Model

### Resolution Rules

The runtime environment should resolve in this order:

1. explicit request override, only where an operator-facing page is allowed to expose one
2. `AVONDALE_RUNTIME_ENV`
3. fallback heuristic based on host or forwarded host if explicitly enabled
4. persisted default from settings
5. hardcoded safe fallback of `homelab`

The profile should resolve in this order:

1. explicit request `profile`
2. legacy request `delivery_mode` or `test_mode`, mapped into `test` or `production`
3. environment-specific default profile
4. hardcoded safe fallback of `test`

Effective setting lookup should resolve in this order:

1. exact `(runtime_environment, profile, key)` match
2. global fallback for `key`
3. hardcoded code fallback where strictly necessary

### Data Model

This plan recommends an additive profile-settings table instead of overloading `public.global_settings` with prefixed keys.

Suggested shape:

```sql
CREATE TABLE public.profile_settings (
  runtime_environment text NOT NULL,
  profile_key text NOT NULL,
  key text NOT NULL,
  value text NOT NULL DEFAULT '',
  description text NOT NULL DEFAULT '',
  setting_type text NOT NULL DEFAULT 'text',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (runtime_environment, profile_key, key),
  CHECK (runtime_environment IN ('homelab', 'hetzner')),
  CHECK (profile_key IN ('dev', 'test', 'production'))
);
```

This keeps the current `global_settings` table intact as the fallback layer and avoids exploding the flat key namespace with names like `hetzner_production_browser_automation_base_url`.

Additional default-setting keys can remain in `global_settings`, for example:

- `default_runtime_environment`
- `default_profile_homelab`
- `default_profile_hetzner`

### Candidate Profile-Scoped Keys

The first wave should cover values that are clearly environment- or profile-sensitive:

- `n8n_base_url`
- `browser_automation_base_url`
- `metabase_base_url`
- `email_test_recipient`
- `email_sender_name`
- `email_reply_to`
- `gmail_send_core_profile` or another transport-routing key
- any external webhook base URLs that differ by environment

Credential handling should be represented as references, not raw secrets, unless there is already an accepted repository pattern for storing the secret in `public.global_settings`. For example:

- `gmail_send_credential_ref`
- `gmail_read_credential_ref`
- `case_tracking_mailbox_credential_ref`

The exact meaning of each `*_credential_ref` depends on the implementation chosen for the shared send/core workflows.

## Plan of Work

### 1. Design the shared resolver first

Add one reusable profile-resolution unit before migrating any app UI. This can be a small n8n helper workflow, a shared code-node block copied consistently, or a repository-local helper script if the team already has a preferred pattern.

Its contract should accept:

- request headers
- request query/body
- optional explicit `runtime_environment`
- optional explicit `profile`
- optional legacy `delivery_mode`
- optional legacy `test_mode`

And return:

- `runtime_environment`
- `profile_key`
- resolved `n8n_base_url`
- resolved `browser_automation_base_url`
- resolved `email_test_recipient`
- resolved `email_sender_name`
- resolved `email_reply_to`
- resolved credential references

This shared resolver becomes the only supported place where old `test_mode` and `delivery_mode` semantics are translated into the new model.

### 2. Add profile storage and seed data

Create a SQL migration to add `public.profile_settings` and seed a safe initial matrix for:

- `homelab/dev`
- `homelab/test`
- `homelab/production`
- `hetzner/dev`
- `hetzner/test`
- `hetzner/production`

Initially, several rows can point at the same values. The point of the seed is to make the matrix explicit and editable.

Also seed the default-resolution keys in `public.global_settings`:

- `default_runtime_environment`
- `default_profile_homelab`
- `default_profile_hetzner`

And add `setting_type` rows for those settings.

### 3. Extend the settings editor for profile-scoped settings

The current global settings editor is row-based and global. It must be extended or supplemented so an operator can browse and edit settings by environment and profile.

Minimum viable UI:

- list runtime environments
- list profiles under each environment
- edit key/value/type rows for a selected `(environment, profile)`
- show inherited global fallback values where no profile-specific override exists

This plan does not require removing the existing global settings editor. The cleaner path is to add a dedicated profile-settings editor and leave global settings as the fallback store.

### 4. Migrate the Team Management mailout flow first

This is the first functional slice because it currently exposes the old test-mode concept directly.

Change:

- Team Management app page
- Generate Team Contact Sheets
- Send Team Captain Contact Lists

From:

- checkbox or field implying `test` versus `production`

To:

- explicit `profile` selector
- resolved environment/profile context passed downstream

Keep old request parameters working during rollout by mapping them through the shared resolver.

### 5. Migrate the reusable outbound email flows

Next migrate the generic send and preview flows that currently read `email_delivery_mode` and `email_test_recipient` directly:

- `send-no-address-batch-emails`
- `send-member-template-email`
- `send-case-tracking-email`
- refund email flows
- preview flows that currently render “Send in test mode”

These should stop resolving mode locally and instead consume the shared profile result.

### 6. Refactor UI pages that currently expose test mode

After the underlying send flows are profile-aware, update the operator-facing pages:

- Team Management app
- Case Tracking app
- member template preview/send pages
- refund preview/send pages
- any maintenance pages or scripts that still present “test mode”

Replace the checkbox mental model with:

- profile selector
- optional environment badge or readonly display
- explicit presentation of actual recipients and transport behavior for `dev` and `test`

### 7. Rationalize credentials

This is the most sensitive part and should be done after the profile resolution path works for URLs and recipients.

The first implementation should avoid trying to make every arbitrary n8n node credential dynamic. Instead:

- identify the small set of shared send/core workflows that actually need profile-specific credentials
- move credential selection behind those cores
- pass credential references or account keys into the shared cores rather than scattering credential-choice logic everywhere

If a workflow cannot safely make credential choice dynamic because of n8n node limitations, keep it on a single credential until a cleaner transport abstraction is in place.

### 8. Deprecate the old mode model

Once all migrated entry points are using the resolver:

- stop reading `email_delivery_mode` directly in new code
- keep `email_delivery_mode`, `delivery_mode`, and `test_mode` only as backward-compatibility inputs
- remove the legacy UI text that implies only two modes

Actual deletion of the old keys should happen only after a soak period and after live pages have all switched to profile selection.

## Concrete Steps

Work from `/mnt/c/dev/avondale-n8n`.

1. Write a new SQL migration for `public.profile_settings` and default profile-selection keys.
2. Extend the settings type migration path so the new default keys have explicit types.
3. Create a profile-resolution helper workflow or shared code pattern and validate it with representative inputs.
4. Update the Team Management app and team-captain send chain to use `profile`.
5. Update the generic outbound send workflows to consume resolved profile data instead of resolving `test` versus `production` locally.
6. Add a profile-settings editor workflow pair or extend the current settings UI with a profile-scoped mode.
7. Update docs and runbooks that currently describe `delivery_mode=test|production`.

Suggested local validation commands during implementation:

```bash
cd /mnt/c/dev/avondale-n8n
jq empty \
  workflows/team-management-app.json \
  workflows/generate-team-contact-sheets.json \
  workflows/send-team-captain-contact-lists.json \
  workflows/send-no-address-batch-emails.json \
  workflows/send-member-template-email.json \
  workflows/send-case-tracking-email.json
```

```bash
cd /mnt/c/dev/avondale-n8n
rg -n "email_delivery_mode|test_mode|delivery_mode" workflows docs scripts sql
```

The second search should gradually shrink in implementation-owned files, while remaining references in historical plans and backups can be ignored.

## Validation and Acceptance

Acceptance is complete only when all of the following are true.

First, an operator-facing page that currently uses test mode, such as Team Management mailout, must present a profile selector with `dev`, `test`, and `production`.

Second, the effective runtime environment must be observable. A resolved request should clearly identify whether it is operating under `homelab` or `hetzner`, even if that environment was derived rather than manually selected.

Third, selecting different profiles must change the resolved behavior predictably:

- `dev` and `test` must not send to real production recipients unless the profile is explicitly configured that way
- `production` must use the production recipient and sender path
- environment-specific URLs must resolve correctly for homelab versus Hetzner

Fourth, migrated send workflows must no longer hand-roll binary mode conversion. They should consume the shared resolver result instead.

Fifth, the profile-settings editor or equivalent management surface must allow an operator to edit profile-scoped URLs and defaults without SQL.

Sixth, legacy callers that still send `test_mode` or `delivery_mode` must continue to work through the compatibility mapping until the rollout is complete.

## Idempotence and Recovery

The migration must be additive.

Keep `public.global_settings` in place as the fallback layer while `public.profile_settings` is introduced. Keep the old `email_delivery_mode` and `email_test_recipient` rows during rollout. Keep legacy request handling that maps `test_mode` and `delivery_mode` into `profile`.

If the new resolver misbehaves, revert individual entry points to their previous local mode logic while keeping the new schema in place. Because the schema is additive, this should not require data rollback.

If environment derivation causes ambiguity, disable heuristic derivation and rely on `AVONDALE_RUNTIME_ENV` plus explicit defaults in settings. The implementation should never require hostname guessing to remain enabled.

If profile-specific credential routing proves too fragile for some workflow, freeze that workflow on a single credential temporarily and continue migrating the URL and recipient surfaces first. Do not block the entire profile rollout on perfect credential abstraction for every node.

## Artifacts and Notes

Current mode-related settings and flows worth treating as the initial migration inventory:

- `email_delivery_mode`
- `email_test_recipient`
- `n8n_base_url`
- Team Management app
- Team captain contact list generation and send flows
- No-address batch email flow
- Case tracking email flow
- Member template email flow
- Refund preview/send flows

The explicit answer to the original design question is:

- yes, `runtime_environment` can be derived from the environment the stack is running in
- no, `profile` should not be inferred purely from deployment location

The safe steady state is:

- environment determines defaults
- profile determines behavior
- explicit operator selection overrides defaults where allowed
