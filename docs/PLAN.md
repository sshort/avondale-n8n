# Project: n8n Batch Creation Process
**Objective:** Create a batch processing workflow that based on emails that have been read from Gmail.  The overall flow is N8N reads emails from Gmail and marks them as New.  An N8N workflow is triggered manually to create a batch consisting of all New emails and set's their status to Processing.  The user then carries out some manual tasks using the batch information.  When the user is ready, they invoke another N8N workflow to mark all the batched items as Complete.  The batch creation should join the memeber_signups table to the raw_contacts table to include address information for each member_signup.

**Key points**
 - emails read from Gmail are converted to member_signups using the N8N workflow "New Member Email Parser", which already exists
 - the status of any member_signup can be New, Processing, Complete or Error. This is initially New.
 - the each member_signup is assigned a batch_id when it is created.  This is initially null.
 - create of the raw_contacts and raw_members tables is current;y outside the scope of this plan, but may be added later.
 - track batch status independently of the status of the member_signups - Processing or Complete. Add creation and completion dates for the batch

## 🟢 Phase 1: Environment Setup
- [ ] Verify Codex access to n8n using the MCP (for workflow injection).
- [ ] Verify Codex access to postgres using the MCP (for workflow injection).
- [ ] Batch size includes all New signups.
- [ ] Test email payloads can be found at /mnt/c/dev/avondale-data/emailstore
- [ ] Create the postgres tables necessary to manage batch processing

## 🟡 Phase 2: Workflow Architecture
- [ ] **Step 1: The Triggers/Sources**
    - The workflow "New Member Email Parser" already exists - update it to make sure new signups are marked as New.
    - Create a node to fetch the full dataset.
- [ ] **Step 2: Batch Creation Workflow**
    - Create a workflow to create the batch
    - information sources are the member_signups table, the raw_members table and the raw_contacts table
    - here is an example query - use this as a basis for the workflow
        select TO_CHAR (s.signup_date, 'dd-MM-yyyy hh:mm') as signup_date, s.member, s.payer, s.product as product, x."First name" as "First name", x."Last name", m."Age", m."Email address" as email_address,
            x."Address 1" as address_1, x."Address 2" as address_2, x."Address 3" as address_3, x."town" as "town", x."postcode" as "postcode",
            'Y' as "Tags provided", '' as "Key pin number"
            from member_signups as s 
                left join raw_members as m on s.member = concat(m."First name", ' ', m."Last name") and m."Membership" = s.product,
                raw_contacts as x
            where s.payer = concat(x."First name", ' ', x."Last name")
            order by s.signup_date    

- [ ] **Step 3: Batch Completion Workflow**
    - Create a workflow to mark all items in the batch as Complete.
    - Ensure the batch completion date is up to date.
