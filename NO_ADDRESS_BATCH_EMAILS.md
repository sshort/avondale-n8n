# No-Address Batch Emails

This documents the local workflow that emails batch recipients who have an email address but do not have a valid postal address in ClubSpark.

Workflow:

- `Send No-Address Batch Emails`
- local n8n workflow id: `otOxMsooAQde1Erj`

Purpose:

- find recipients in a signup batch who should not receive printed post because their postal address is incomplete
- send them the `shoe_tag_pigeon_hole` email instead

## Address rule

A postal address is considered valid only if both are present:

- `Address 1`
- `postcode`

If either is missing, the recipient is treated as `no address` and is eligible for this email workflow.

## Data source

The workflow uses the local source-of-truth database.

It reads from:

- `public.member_signups`
- `public.raw_contacts`
- `public.raw_members`
- `public.email_templates`

It prefers the best matching contact row for a payer, then falls back to member email data if needed.

## Template

Template key:

- `shoe_tag_pigeon_hole`

Template syntax should use n8n-style placeholders:

- `{{$json.first_name}}`
- `{{$json.last_name}}`
- `{{$json.email_address}}`
- `{{$json.address_1}}`
- `{{$json.address_2}}`
- `{{$json.town}}`
- `{{$json.postcode}}`

The current template begins:

```text
Dear {{$json.first_name}} {{$json.last_name}},
```

The workflow still contains backward-compatibility replacements for older token styles, but new templates should use the n8n-style form above.

## Webhook

Default webhook:

- `http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=<batch_id>`

Metabase card:

- `Signup Batches`
- column: `No Address Emails`

Clicking the card link calls the webhook for that batch.

The Metabase card only shows the `No Address Emails` link when both are true:

- batch `status = 'Complete'`
- `no_address_email_sent = false`

For `Processing` batches, or batches already marked as sent, the link cell is blank.

The webhook also accepts an override flag:

- `override=true`

Example:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5&override=true
```

## Batch sent flag

`public.signup_batches` now has:

- `no_address_email_sent boolean not null default false`

Rules:

- batch `4` is marked `true`
- the workflow refuses to send if this flag is already `true`
- the webhook override parameter can bypass that guard for a one-off rerun
- after a successful production send, the workflow sets the flag to `true`
- test-mode sends do not change the flag

## Delivery modes

The workflow supports two modes:

- `production`
- `test`

Global defaults are set through local n8n environment variables in `docker-compose.yml`.

Current settings:

- `AVONDALE_EMAIL_DELIVERY_MODE=production`
- `AVONDALE_EMAIL_TEST_RECIPIENT=steve.short@gmail.com`

### Production mode

In production mode:

- emails are sent to the real recipient email address

Example:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5
```

### Test mode

In test mode:

- the message is still personalized for the real recipient
- but delivery goes to the fixed test inbox instead of the real recipient

Default test inbox:

- `steve.short@gmail.com`

In test mode the message footer also includes:

- original recipient email
- payer name

Example:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5&delivery_mode=test
```

Override the test inbox for one run:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5&delivery_mode=test&test_recipient=you@example.com
```

Force production for one run:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5&delivery_mode=production
```

Force a resend for a batch already marked as sent:

```text
http://n8n:5678/webhook/send-no-address-batch-emails?batch_id=5&delivery_mode=production&override=true
```

## Error handling

Missing batch:

```json
{"message":"Batch 2 does not exist"}
```

Already sent and no override:

```json
{"message":"No-address emails have already been sent for batch <batch_id>"}
```

No recipients found for the batch:

```json
{
  "message": "No recipients without postal addresses for batch <batch_id>",
  "batch_id": <batch_id>,
  "sent_count": 0,
  "recipients": []
}
```

## Implementation notes

- placeholder Postgres success rows are ignored
- if first/last name are missing in the contact/member record, the workflow falls back to splitting the `payer` name
- Gmail sending uses the local `Avondale Gmail OAuth2` credential
