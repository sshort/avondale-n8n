# Make All Email Flows HTML-Capable And CID-Embedded

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This document must be maintained in accordance with `/mnt/c/dev/PLAN.md`.

## Purpose / Big Picture

After this change, every outbound email path in this repository will be able to send a proper HTML email with a plain-text fallback, and every HTML-capable editor will allow managed images to be inserted and previewed before send. Managed images means images stored in `public.images` and inserted through the Avondale UI, not arbitrary remote image URLs. At send time those managed images will be embedded into the email as inline attachments referenced by `cid:` URLs. “CID” means Content-ID, which is an identifier inside the email message itself; the HTML body uses `src="cid:..."` so the recipient’s mail client can show the image without fetching it from the public internet.

The visible proof is simple. An operator can open the email template editor or any preview editor, insert an image from the image library or upload a new one, see that image rendered in the browser preview, send the email in test mode, and then inspect the received message and confirm that the image is inline and the message source contains `multipart/related` and `Content-ID` headers. The same behavior must work for all business email flows, including the existing attachment-heavy team-captain mailout.

## Progress

- [x] (2026-04-24 10:20Z) Inspected the current email template editor, preview workflows, and send workflows in `/mnt/c/dev/avondale-n8n/workflows`.
- [x] (2026-04-24 10:24Z) Confirmed that `public.images` already exists in `/mnt/c/dev/avondale-n8n/sql/011_images.sql` and can already store binary image data with `image_key`, `content_type`, and `data`.
- [x] (2026-04-24 10:27Z) Confirmed that `workflows/send-case-tracking-email.json` already builds raw MIME and sends through the Gmail API, while most other outbound workflows still use the stock n8n Gmail send node.
- [x] (2026-04-24 10:31Z) Confirmed that `workflows/email-template-editor-app.json` and `workflows/preview-case-tracking-email.json` already use TinyMCE, but do not currently expose image insertion or upload controls.
- [x] (2026-04-24 10:34Z) Confirmed that `workflows/preview-member-template-email.json` and `workflows/preview-refund-request-email.json` still use plain `<textarea>` editing rather than a rich HTML editor.
- [x] (2026-04-24 10:42Z) Wrote this ExecPlan and checked it into `docs/EXECPLAN-email-html-cid.md`.
- [x] (2026-04-24 11:14Z) Created GitHub issue `#85`, added it to the `avondale-n8n board`, and moved the project item to `In Progress`.
- [x] (2026-04-24 11:44Z) Added `workflows/email-image-asset.json` and `workflows/email-send-core.json`, and validated both workflow JSON files plus all embedded Code-node scripts.
- [x] (2026-04-24 11:56Z) Migrated `workflows/send-gmail-test-message.json` to call `email-send-core` over a stable internal webhook path instead of using the stock Gmail node directly.
- [x] (2026-04-24 13:18Z) Migrated `workflows/send-member-template-email.json`, `workflows/send-refund-request-email.json`, `workflows/send-member-calculation-email.json`, and `workflows/send-treasury-refund-request.json` to the shared send helper, and updated the calculation/treasury renderers to emit HTML plus text payloads from stored templates.
- [x] (2026-04-24 13:42Z) Migrated `workflows/send-no-address-batch-emails.json` to the shared send helper and updated its per-recipient rendering to prefer HTML templates with a text fallback.
- [x] (2026-04-24 14:22Z) Migrated `workflows/send-team-captain-contact-lists.json` to the shared send helper while preserving grouped attachments, visible `To`, and BCC behavior for captain mailouts.
- [x] (2026-04-24 14:35Z) Migrated `workflows/send-case-tracking-email.json` to the shared send helper while preserving reply threading metadata, open-tracking token injection, and case-email logging.
- [x] (2026-04-24 15:18Z) Added managed-image insertion and in-page upload support to `workflows/email-template-editor-app.json` and `workflows/email-template-editor-actions.json`, backed by `public.images`.
- [x] (2026-04-24 15:42Z) Upgraded `workflows/preview-case-tracking-email.json` so the HTML compose surface can insert and upload managed images directly from the preview page.
- [x] (2026-04-24 16:24Z) Upgraded `workflows/preview-member-template-email.json` and `workflows/preview-refund-request-email.json` to HTML-first previews with live rendered output, managed-image insertion/upload, and normalized submit payloads.
- [x] Migrate the remaining outbound email workflows to the shared HTML plus CID-capable send path.
- [x] (2026-04-24 16:24Z) Validated all changed workflow JSON files and embedded Code-node scripts for the editor and preview layer after the managed-image changes.
- [x] (2026-04-24 16:31Z) Published the updated member and refund preview workflows to n8n using workflow ids `7YqE6u4FbNRAXaRp` and `KJ7Ys7oAxo0yGYhi`.
- [ ] Complete live browser and outbound-email verification for the updated editor and preview workflows, then move the project item to `Done`.

## Surprises & Discoveries

- Observation: the repository already has a durable binary image store and sync path.
  Evidence: `/mnt/c/dev/avondale-n8n/sql/011_images.sql` defines `public.images`, and `/mnt/c/dev/avondale-n8n/scripts/import-images.mjs` already imports local image files into that table.

- Observation: multipart file upload was not the best contract for these n8n-hosted editor pages.
  Evidence: the implemented editor and preview upload flows now read images in-browser and POST `image_base64` plus metadata into `email-template-editor-actions`, which avoided extra binary webhook plumbing while still writing canonical rows to `public.images`.

- Observation: CID embedding is straightforward only in the existing raw-MIME path.
  Evidence: `/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json` already constructs MIME headers and sends to `https://gmail.googleapis.com/gmail/v1/users/me/messages/send`, while most other send workflows still use the simpler Gmail node with only `message` and `emailType`.

- Observation: there is no existing image-serving webhook for browser preview or editor rendering.
  Evidence: repository search found storage and sync references for `public.images`, but no workflow that serves image bytes over a stable webhook path.

- Observation: the team-captain mailout is the highest-risk migration because it already sends normal attachments and will need to support inline images at the same time.
  Evidence: `/mnt/c/dev/avondale-n8n/workflows/send-team-captain-contact-lists.json` already builds and sends PDF attachments, so the final MIME structure must support both `multipart/related` for inline images and `multipart/mixed` for ordinary attachments.

- Observation: using the n8n `executeWorkflow` node for a brand-new shared helper is awkward before the helper exists live because the caller needs the target workflow database id.
  Evidence: existing `executeWorkflow` nodes in this repository reference concrete live workflow ids, while the new helper had no stable id yet. The implementation therefore exposed `email-send-core` as a stable internal webhook path first and migrated the test sender to HTTP-post into that path.

## Decision Log

- Decision: standardize all outbound email sends on a shared raw-MIME helper instead of trying to extend the stock n8n Gmail send node.
  Rationale: raw MIME gives explicit control over `multipart/alternative`, `multipart/related`, `Content-ID`, `In-Reply-To`, `References`, Cc, Bcc, and normal file attachments. The stock node does not provide enough control for a uniform CID strategy.
  Date/Author: 2026-04-24 / Codex

- Decision: use `public.images` as the canonical source of inline email images instead of adding a second image table.
  Rationale: the table already exists, already stores binary data, and already syncs between environments. Reusing it avoids unnecessary schema drift.
  Date/Author: 2026-04-24 / Codex

- Decision: treat only managed images as guaranteed CID candidates.
  Rationale: managed images are images chosen from or uploaded into `public.images`. They can be fetched reliably, deduplicated by `image_key`, previewed in the browser through an Avondale webhook, and rewritten to `cid:` during send. Arbitrary remote URLs are unpredictable and should not be the main contract for inline email content.
  Date/Author: 2026-04-24 / Codex

- Decision: store managed image references in HTML using a previewable `src` plus a durable `data-avondale-image-key` attribute.
  Rationale: the browser editor needs a real image URL to render during composition, while the send flow needs an unambiguous internal key to rewrite that image to a CID attachment without guessing from the URL.
  Date/Author: 2026-04-24 / Codex

- Decision: migrate one simple flow and one attachment-heavy flow as explicit prototypes before moving the rest.
  Rationale: `send-gmail-test-message` is the fastest proof that CID embedding works for simple HTML mail, and `send-team-captain-contact-lists` is the decisive proof that the MIME builder can handle both inline images and ordinary attachments.
  Date/Author: 2026-04-24 / Codex

- Decision: expose `email-send-core` as a webhook-backed transport helper, not only an `executeWorkflow` subworkflow.
  Rationale: a webhook path is stable before publication and avoids the bootstrap problem of needing a live workflow database id in callers. Internal workflows can post to `http://n8n:5678/webhook/email-send-core` without waiting for a second publication pass just to discover the helper id.
  Date/Author: 2026-04-24 / Codex

## Outcomes & Retrospective

Implementation is now substantially complete. The feature has a dedicated branch, a tracked GitHub issue, a checked-in ExecPlan, a new image asset workflow, a new shared raw-MIME transport workflow, migrated outbound senders, and upgraded authoring surfaces across the template editor, case preview, member preview, and refund preview. Managed images can now be uploaded into `public.images`, inserted into HTML compositions, previewed through the asset webhook, and carried through the shared send contract so they can be rewritten to CID at send time.

The remaining work is mostly verification and close-out, not core implementation. The updated preview workflows have been published to n8n, but the feature still needs live browser checks across all editor surfaces and end-to-end outbound email verification in received messages. After that, the GitHub issue notes and project item should be finalized and moved to `Done`.

## Context and Orientation

The relevant repository is `/mnt/c/dev/avondale-n8n`. Checked-in n8n workflow exports live under `/mnt/c/dev/avondale-n8n/workflows`, schema files live under `/mnt/c/dev/avondale-n8n/sql`, and supporting scripts live under `/mnt/c/dev/avondale-n8n/scripts`.

Today there are three distinct pieces of the email stack in this repository. First, there is authoring, which means the browser pages where operators edit templates or preview a rendered message before send. The main authoring files are `/mnt/c/dev/avondale-n8n/workflows/email-template-editor-app.json`, `/mnt/c/dev/avondale-n8n/workflows/preview-case-tracking-email.json`, `/mnt/c/dev/avondale-n8n/workflows/preview-member-template-email.json`, and `/mnt/c/dev/avondale-n8n/workflows/preview-refund-request-email.json`.

Second, there is business-specific rendering and send orchestration. These are the workflows that know which recipient, subject, tokens, and side effects belong to each feature. The relevant files are `/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-member-template-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-refund-request-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-member-calculation-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-treasury-refund-request.json`, `/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json`, `/mnt/c/dev/avondale-n8n/workflows/send-team-captain-contact-lists.json`, and `/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json`.

Third, there is image storage. `/mnt/c/dev/avondale-n8n/sql/011_images.sql` defines `public.images` with `image_key`, `file_name`, `content_type`, `byte_size`, and `data bytea`. `/mnt/c/dev/avondale-n8n/scripts/import-images.mjs` imports static image files into that table. There is no existing image asset webhook, image-library UI, or send-time HTML rewriter.

“HTML capable” in this plan means every outbound flow can render and send an HTML body and also produce a plain-text fallback. “CID capable” means that if the HTML contains a managed image, the final email sent through Gmail contains that image as an inline MIME part with a `Content-ID`, and the HTML body refers to it with `src="cid:..."`. “Raw MIME” means the full email message is assembled manually, including headers and multipart boundaries, rather than letting the stock n8n Gmail node build the message.

## Plan of Work

Begin by creating two new workflows: `/mnt/c/dev/avondale-n8n/workflows/email-image-asset.json` and `/mnt/c/dev/avondale-n8n/workflows/email-send-core.json`.

`email-image-asset.json` is a GET webhook that accepts an image key, loads the matching active row from `public.images`, sets the correct `Content-Type`, and returns the raw bytes. This workflow exists only for browser preview and editing. It does not perform CID embedding itself. It gives the editor a stable URL such as `/webhook/email-image-asset?image_key=avondale_banner` that can be used as the `src` of an `<img>` element while composing.

`email-send-core.json` is the transport helper that all business send workflows will call. It accepts normalized inputs such as recipients, sender name, reply-to, subject, rendered HTML, rendered text, thread metadata, ordinary file attachments, and the business flow name for logging. Inside a Code node it must parse the rendered HTML, collect every unique `data-avondale-image-key`, fetch the corresponding image rows from `public.images`, generate stable CIDs, rewrite the HTML `src` values to `cid:...`, and build the correct MIME envelope. If there is HTML but no ordinary attachments, the body should be `multipart/alternative` nested inside `multipart/related`. If there are ordinary attachments, wrap the whole thing in `multipart/mixed`. If there is no HTML, send plain text only. This helper then sends through the Gmail API the same way case tracking already does and returns Gmail ids plus the final normalized HTML and text bodies to the caller.

After the shared helper exists, update `/mnt/c/dev/avondale-n8n/workflows/email-template-editor-app.json` and `/mnt/c/dev/avondale-n8n/workflows/email-template-editor-actions.json` so the template editor becomes the canonical place to upload and manage email images. Extend the page with an image library panel that lists active rows from `public.images`, supports upload of PNG, JPEG, GIF, and WebP files, and lets the operator insert a selected image into the current HTML body.

Use `/mnt/c/dev/avondale-n8n/workflows/send-gmail-test-message.json` as the first migration target. It is the simplest place to prove that the shared helper can send HTML with a plain-text fallback and inline images. Then migrate `/mnt/c/dev/avondale-n8n/workflows/send-team-captain-contact-lists.json` as the attachment-heavy prototype.

After the transport is proven, upgrade `/mnt/c/dev/avondale-n8n/workflows/preview-member-template-email.json` and `/mnt/c/dev/avondale-n8n/workflows/preview-refund-request-email.json` to match the richer authoring model already used in case tracking, and add the same managed-image insertion UI to `/mnt/c/dev/avondale-n8n/workflows/preview-case-tracking-email.json`.

Finally, migrate the remaining outbound flows to the shared helper: `/mnt/c/dev/avondale-n8n/workflows/send-member-template-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-refund-request-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-member-calculation-email.json`, `/mnt/c/dev/avondale-n8n/workflows/send-treasury-refund-request.json`, `/mnt/c/dev/avondale-n8n/workflows/send-no-address-batch-emails.json`, and `/mnt/c/dev/avondale-n8n/workflows/send-case-tracking-email.json`.

## Concrete Steps

Work from `/mnt/c/dev/avondale-n8n`.

Before editing any workflow, create or update the GitHub issue and move the project item to `In Progress` using the GitHub UI or the authenticated `gh` workflow already used for this repository. This is required because this is a significant cross-cutting feature.

Validate the new and changed workflow JSON files after each edit:

    cd /mnt/c/dev/avondale-n8n
    jq empty \
      workflows/email-image-asset.json \
      workflows/email-send-core.json \
      workflows/email-template-editor-app.json \
      workflows/email-template-editor-actions.json \
      workflows/preview-case-tracking-email.json \
      workflows/preview-member-template-email.json \
      workflows/preview-refund-request-email.json \
      workflows/send-case-tracking-email.json \
      workflows/send-member-template-email.json \
      workflows/send-refund-request-email.json \
      workflows/send-member-calculation-email.json \
      workflows/send-treasury-refund-request.json \
      workflows/send-no-address-batch-emails.json \
      workflows/send-team-captain-contact-lists.json \
      workflows/send-gmail-test-message.json

Publish updated workflow JSON with the existing repository sync path once each batch is stable. The helper takes `<workflow-id> <workflow-json-file>` pairs, not only file paths:

    cd /mnt/c/dev/avondale-n8n
    node scripts/sync-workflow-json-to-n8n-db.mjs <workflow-id> workflows/email-image-asset.json
    node scripts/sync-workflow-json-to-n8n-db.mjs <workflow-id> workflows/email-send-core.json

Repeat that command for each workflow changed in later milestones. For example, the published preview updates used:

    cd /mnt/c/dev/avondale-n8n
    node scripts/sync-workflow-json-to-n8n-db.mjs 7YqE6u4FbNRAXaRp workflows/preview-member-template-email.json
    node scripts/sync-workflow-json-to-n8n-db.mjs KJ7Ys7oAxo0yGYhi workflows/preview-refund-request-email.json

After publishing the asset workflow, verify that an existing image can be served:

    curl -I -sS "https://n8n.proxy.shortcentral.com/webhook/email-image-asset?image_key=avondale_banner"

The expected result is HTTP `200` and an image content type such as `image/png`.

After publishing each updated preview workflow, open the relevant page in a browser, insert a managed image, and verify that the browser preview shows the image immediately. After publishing each updated send workflow, send a test email to the configured test recipient and inspect the received message source. The expected proof is a multipart message with a `Content-ID` part and an HTML body that refers to `cid:` instead of the public asset URL.

## Validation and Acceptance

Acceptance is behavioral, not structural.

The feature is accepted only when a human can do all of the following:

1. Open the email template editor, upload a new image into the managed library, insert it into a template, save the template, reopen it, and still see the image rendered in the editor.
2. Open the case-tracking preview, member preview, and refund preview pages, insert a managed image, and see the image in the live browser preview before send.
3. Send a test email through `send-gmail-test-message`, receive it, and confirm that the image is inline and the raw message source contains `Content-ID` and a multipart structure suitable for CID embedding.
4. Send a test email through each business flow in test mode and confirm that HTML content is used when present, plain text remains available as fallback, and any managed image appears inline in the received mail.
5. Send a team-captain mailout test that includes both a managed inline image and the existing PDF attachments, and confirm that both the inline image and the normal attachments survive.
6. Send a case-tracking HTML reply with a managed image and confirm that reply threading, open tracking, and inline images all still work together.

Repository acceptance is `jq empty` passing for every changed workflow export. Transport acceptance is observed in the received Gmail message source, not just the browser preview.

## Idempotence and Recovery

This plan is intentionally additive. Create `email-image-asset.json` and `email-send-core.json` first, then migrate each caller one at a time. That means a partially completed rollout can stop after any milestone without forcing every email path to switch at once.

Image uploads must be safe to retry. If an upload is repeated with the same replace action, it should update the existing `public.images` row deliberately. If the operator is creating a new image, the UI must refuse to overwrite a different image silently.

Workflow publication is also safe to repeat. Republishing the same workflow JSON should replace the prior live definition. If a migrated flow breaks in testing, restore the prior checked-in workflow JSON and republish it before continuing. Do not delete `public.images` rows as part of rollback; image rows are shared assets and should be deactivated rather than destroyed.

## Artifacts and Notes

The most important implementation artifact is the shared MIME builder inside `email-send-core.json`. It must be able to produce these three envelope shapes:

    plain text only:
      Content-Type: text/plain; charset=UTF-8

    HTML with inline images:
      multipart/related
        multipart/alternative
          text/plain
          text/html
        image/png with Content-ID

    HTML with inline images and normal attachments:
      multipart/mixed
        multipart/related
          multipart/alternative
            text/plain
            text/html
          image/png with Content-ID
        application/pdf attachment

The HTML authored in editors should preserve a previewable URL and an explicit managed-image key, for example:

    <img
      src="/webhook/email-image-asset?image_key=avondale_banner"
      data-avondale-image-key="avondale_banner"
      alt="Avondale banner"
    >

The send helper must rewrite only the `src` value for the final outbound HTML. The durable `data-avondale-image-key` attribute is the contract that lets the sender find the correct binary image row.

## Interfaces and Dependencies

The implementation depends on the existing local Postgres credential already used by checked-in workflows and on the existing Gmail OAuth2 credential already used by outbound send workflows. Do not introduce a second mail transport.

At the end of this plan, these workflow interfaces must exist:

`workflows/email-image-asset.json` must expose a GET webhook that accepts `image_key` and returns raw image bytes with the correct `Content-Type`.

`workflows/email-send-core.json` must accept normalized email inputs from caller workflows and return at least the Gmail message id, Gmail thread id when applicable, the final normalized HTML body, and the final normalized text body used for send.

Every business send workflow must become a caller of `email-send-core.json`, not a second MIME assembler. Each caller remains responsible for business-specific data lookup, token rendering, status updates, and audit logging.

Every HTML-capable editor must support managed image insertion by storing `data-avondale-image-key` in the saved HTML. That attribute is the stable bridge between browser preview and final CID embedding.

Revision note: created this plan after inspecting the checked-in editor, preview, image-storage, and send workflows and after confirming that the existing `public.images` table is sufficient to serve as the canonical image store for CID-embedded email images.
