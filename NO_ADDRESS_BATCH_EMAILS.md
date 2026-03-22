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

## Error handling

Missing batch:

```json
{"message":"Batch 2 does not exist"}
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
