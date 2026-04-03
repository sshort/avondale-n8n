# Refund Process Test Plan

## Prerequisites

1. Deploy the new workflows and migrations to your test environment
2. Run the migration: `sql/033_refunds_add_status_tracking.sql`
3. Insert the email template: `sql/034_refund_calculation_member_template.sql`

## Test Scenarios

### Scenario 1: New Refund Request (Happy Path)

**Steps:**
1. Open: `https://your-n8n/webhook/refund-form`
2. Fill in form:
   - Name: `Test Member`
   - For: `Test Member`
   - Reason: `Injured`
   - Membership: `Full Playing`
   - Amount: `480`
   - From Date: `2026-01-01`
   - To Date: `2026-12-31`
3. Click **Create Refund**
4. Verify: Redirect shows success, refund created with status `Requested`

**Expected:**
- Row created in `public.refunds` with `status = 'Requested'`
- `months` calculated as 12
- `refund` calculated as `480 * (12-1)/12 = 440`

---

### Scenario 2: Send Member Calculation Email

**Steps:**
1. Open: `https://your-n8n/webhook/refund-status-form`
2. Click on the refund row from Scenario 1
3. Verify: "Send Calculation Email to Member" button is visible (green)
4. Click the button
5. Enter test email or leave blank
6. Submit

**Expected:**
- Email sent (check Gmail sent folder)
- Status automatically updated to `Awaiting Bank Details`
- `request_email_message_id` populated with Gmail message ID

---

### Scenario 3: Update Status Manually

**Steps:**
1. With refund selected in status form
2. Change status dropdown to `Bank Details Received`
3. Optionally add notes
4. Click **Update Status**

**Expected:**
- Status updated in database
- `updated_at` timestamp refreshed

---

### Scenario 4: Send Treasury Request

**Steps:**
1. With refund selected, set status to `Ready For Treasury`
2. Click **Update Status**
3. Navigate to: `https://your-n8n/webhook/preview-refund-request-email`
4. Fill in refund details manually
5. Set `template_key = refund_request_treasury`
6. Preview and send

**Note:** This uses the existing treasury workflow. A dedicated treasury send button is not yet implemented.

---

### Scenario 5: Mark as Paid

**Steps:**
1. Select refund in status form
2. Set status to `Paid`
3. Click **Update Status**

**Expected:**
- Status updated to `Paid`
- `paid_at` timestamp set automatically

---

## Status Flow

```
Requested → Awaiting Bank Details → Bank Details Received → Ready For Treasury → Sent To Treasury → Paid
     ↓              ↓                        ↓                       ↓                    ↓
  Rejected      Rejected                 Rejected               Rejected              Rejected
     ↓              ↓                        ↓                       ↓                    ↓
 Cancelled      Cancelled               Cancelled               Cancelled              Cancelled
```

## Database Verification Queries

```sql
-- View all refunds with status
SELECT id, refund_for, membership, refund, status, request_email_message_id, paid_at
FROM public.refunds
ORDER BY created_at DESC;

-- Check specific refund
SELECT * FROM public.refunds WHERE id = <your_id>;

-- Verify email template exists
SELECT template_key, template_name, subject_template
FROM public.email_templates
WHERE template_key IN ('refund_calculation_member', 'refund_request_treasury');
```

## Known Limitations

- Member email lookup joins on `members.name` - ensure member name matches exactly
- Treasury send still uses existing workflow, not integrated into status form
- No automatic email tracking - message IDs must be recorded manually
