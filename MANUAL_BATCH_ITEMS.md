# Manual Batch Items

This process lets you add a member to a batch with one or more shoe tags, parent tags, or keys **without** creating a fake row in `public.member_signups`.

Manual items are stored separately and are marked with:

- `source = 'manual'`

They still flow through the batch exports, labels, and envelopes.

## What It Creates

Database objects:

- `public.signup_batch_manual_items`
- `public.vw_signup_batch_items`
- `public.vw_signup_batch_consolidated`
- `public.vw_signup_batches_summary`

Key point:

- `member_signups` remains reserved for real captured signup events.
- `signup_batch_manual_items` holds operator-added tag/key items.

## How The Manual Workflow Resolves Data

Workflow:

- `Add Manual Batch Item`
- file: [workflows/add-manual-batch-item.json](/mnt/c/dev/avondale-n8n/workflows/add-manual-batch-item.json)
- webhook: `http://n8n:5678/webhook/add-manual-batch-item`
- form workflow: [workflows/manual-batch-item-form.json](/mnt/c/dev/avondale-n8n/workflows/manual-batch-item-form.json)
- form webhook: `http://n8n:5678/webhook/manual-batch-item-form`

Lookup rules:

1. Resolve the member from `raw_members` using one of:
   - `member`
   - `venue_id`
   - `btn`
2. If `batch_id` is omitted, use the latest batch with `status = 'Processing'`.
3. Try to resolve the best matching `raw_contacts` row for that member.
4. Prefer a contact row with a usable address over a sparse one.
5. Allow explicit overrides from the webhook for payer, email, and address fields.

The inserted row is marked:

- `source = 'manual'`

## What Downstream Processes Use

These now read the combined batch views instead of only `member_signups`:

- batch CSV export in [workflows/create-signup-batch.json](/mnt/c/dev/avondale-n8n/workflows/create-signup-batch.json)
- J8160 labels in [workflows/print-j8160-labels-from-cloud.json](/mnt/c/dev/avondale-n8n/workflows/print-j8160-labels-from-cloud.json)
- DL envelopes in [workflows/print-dl-envelopes-from-cloud.json](/mnt/c/dev/avondale-n8n/workflows/print-dl-envelopes-from-cloud.json)

That means manual items:

- appear in batch exports
- contribute to payer-address consolidation
- contribute to shoe tag / parent tag / key counts
- can be printed on labels and envelopes

## Command-Line Wrapper

Wrapper script:

- [scripts/add-manual-batch-item.sh](/mnt/c/dev/avondale-n8n/scripts/add-manual-batch-item.sh)

Run it with:

```bash
bash /mnt/c/dev/avondale-n8n/scripts/add-manual-batch-item.sh \
  --member "Hamish Graham" \
  --regular-tags 2 \
  --key-tags 1 \
  --notes "Manual replacement items"
```

Required:

- one member identifier:
  - `--member`
  - `--venue-id`
  - `--btn`
- at least one positive count:
  - `--regular-tags`
  - `--parent-tags`
  - `--key-tags`

Optional:

- `--batch-id`
- `--payer`
- `--email`
- `--address-1`
- `--address-2`
- `--address-3`
- `--town`
- `--postcode`
- `--notes`
- `--created-by`
- `--base-url`

The script defaults to:

- `N8N_BASE_URL=http://n8n:5678`
- `created_by=manual_cli`

## Direct Webhook Usage

Example:

```text
http://n8n:5678/webhook/add-manual-batch-item?member=Hamish%20Graham&regular_tags=2&key_tags=1&notes=Manual%20replacement%20items
```

Example with an explicit batch and address override:

```text
http://n8n:5678/webhook/add-manual-batch-item?batch_id=5&member=Hamish%20Graham&regular_tags=1&payer=Hamish%20Graham&address_1=9%20Polmear%20Close&town=Church%20Crookham&postcode=GU52%208UH
```

Successful response shape:

```json
{
  "ok": true,
  "response_code": 200,
  "message": "Added manual batch item 12 to batch 5",
  "id": 12,
  "batch_id": 5,
  "member": "Hamish Graham",
  "payer": "Hamish Graham",
  "regular_tags": 2,
  "parent_tags": 0,
  "key_tags": 1,
  "source": "manual"
}
```

Validation failures return JSON with:

```json
{
  "ok": false,
  "response_code": 400,
  "message": "..."
}
```

Typical failure messages:

- `Provide member, venue_id, or btn.`
- `At least one of regular_tags, parent_tags, or key_tags must be greater than zero.`
- `Batch <id> does not exist`
- `No processing batch available and no batch_id was provided.`
- `Member could not be resolved.`

## Two-Step Metabase Flow

The intended Metabase path is:

1. Open the `Member Search` page.
2. Click the selected member on the search-results card.
3. That opens the manual-item form webhook.
4. Enter shoe tag / parent tag / key counts.
5. Submit the form.

The form webhook pre-fills:

- `member`

The submitted form then calls the real add-manual webhook in a new tab.

## Metabase

Batch reporting should use the batch views rather than raw `member_signups`:

- summary: `public.vw_signup_batches_summary`
- consolidated address output: `public.vw_signup_batch_consolidated`
- row-level combined items: `public.vw_signup_batch_items`

That ensures manual rows are counted alongside real captured signups without pretending they were email signups.

## Sync To Cloud

The sync workflow now includes:

- `signup_batch_manual_items`

File:

- [workflows/sync-raw-tables-to-cloud.json](/mnt/c/dev/avondale-n8n/workflows/sync-raw-tables-to-cloud.json)

So the cloud reporting copy can stay aligned with the local source of truth.
