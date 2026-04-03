# Avondale n8n Batch Processing Design

## Purpose

This document turns the project plan in [PLAN.md](/mnt/c/dev/avondale-n8n/docs/PLAN.md) into an implementation design for batching newly parsed Gmail signups in n8n. The design covers the data model, workflow behavior, query structure, error handling, and validation strategy.

## Scope

The solution must support:

- Ingesting new signups from the existing `New Member Email Parser` workflow.
- Marking each new `member_signups` row as `New` when created.
- Preserving the original ClubSpark membership status separately from workflow processing status.
- Creating a batch manually from all current `New` signups.
- Marking selected signups as `Processing` and attaching a `batch_id`.
- Returning batch output enriched with `raw_members` and `raw_contacts` data.
- Completing a batch manually and marking all batched signups as `Complete`.
- Tracking batch state independently from signup state.

Out of scope for this iteration:

- Creation or ingestion of `raw_contacts` and `raw_members`.
- Automatic scheduling of batch creation or completion.
- Redesign of the existing email parsing logic beyond the required status defaults.

## Functional Requirements

### Signup lifecycle

Each `member_signups` row moves through these states:

- `New`: parsed and awaiting inclusion in a batch.
- `Processing`: assigned to an active batch.
- `Complete`: finished by the completion workflow.
- `Error`: parsing or downstream processing failed.

Rules:

- New signups must be created with `status = 'New'`.
- New signups must be created with `batch_id = NULL`.
- A signup can belong to at most one batch.
- Once moved to `Processing`, a signup must not be included in later batch-creation runs.

### Batch lifecycle

Each batch moves through these states:

- `Processing`: created and currently active.
- `Complete`: batch has been closed.

Rules:

- A batch is created only when at least one `New` signup exists.
- A batch records its creation timestamp.
- A completed batch records its completion timestamp.
- Batch completion updates both the batch record and all related signups.

## Proposed Data Model

### Existing table assumptions

The design assumes `member_signups` already exists with at least:

- `id`
- `signup_date`
- `member`
- `payer`
- `product`
- `status`
- `clubspark_status`
- `batch_id`

If `status` or `batch_id` do not exist, they must be added before workflow rollout.

### New table: `signup_batches`

```sql
create table if not exists signup_batches (
    id bigserial primary key,
    status text not null check (status in ('Processing', 'Complete')),
    created_at timestamptz not null default now(),
    completed_at timestamptz null
);
```

Recommended indexes:

```sql
create index if not exists idx_signup_batches_status
    on signup_batches (status);

create index if not exists idx_member_signups_status
    on member_signups (status);

create index if not exists idx_member_signups_batch_id
    on member_signups (batch_id);
```

Recommended constraint on `member_signups.batch_id`:

```sql
alter table member_signups
    add constraint fk_member_signups_batch
    foreign key (batch_id) references signup_batches (id);
```

## Workflow Design

### 1. New Member Email Parser update

The existing workflow must continue creating rows in `member_signups`, with these guarantees:

- `status` is set to `New`.
- `clubspark_status` stores the membership status parsed from the ClubSpark email.
- `batch_id` is set to `NULL`.
- Parsing failures set `status` to `Error` if the row is persisted.

This workflow remains the source of truth for new signup creation.

### 2. Batch Creation workflow

This is a manually triggered n8n workflow.

#### Objective

Create one batch from all current `New` signups, move those signups to `Processing`, and return the enriched export dataset for the user to act on.

#### Recommended workflow steps

1. Trigger manually.
2. Run a single SQL operation that:
   - checks whether any `New` rows exist,
   - creates a `signup_batches` row,
   - updates all `New` signups to `Processing`,
   - assigns the new `batch_id`.
3. If no rows were updated, stop cleanly with a user-facing message such as `No new signups available`.
4. Query the full enriched batch dataset using the returned `batch_id`.
5. Return the dataset to the user or downstream export node.

#### Atomicity requirement

Batch creation must be atomic. Without that, two manual runs could create overlapping batches or miss rows. The safest design is to perform batch creation and signup assignment in one SQL statement using CTEs.

#### Example batch-creation SQL pattern

```sql
with candidate_rows as (
    select id
    from member_signups
    where status = 'New'
),
new_batch as (
    insert into signup_batches (status)
    select 'Processing'
    where exists (select 1 from candidate_rows)
    returning id
),
updated_signups as (
    update member_signups s
    set status = 'Processing',
        batch_id = (select id from new_batch)
    where s.id in (select id from candidate_rows)
      and exists (select 1 from new_batch)
    returning s.id, s.batch_id
)
select batch_id, count(*) as signup_count
from updated_signups
group by batch_id;
```

This pattern avoids creating empty batches and ensures every selected row gets the same batch id.

#### Enriched batch dataset query

After the batch is created, fetch the output dataset by `batch_id`.

```sql
select
    to_char(s.signup_date, 'dd-MM-yyyy hh24:mi') as signup_date,
    s.member,
    s.payer,
    s.product,
    x."First name" as "First name",
    x."Last name" as "Last name",
    m."Age" as "Age",
    m."Email address" as email_address,
    x."Address 1" as address_1,
    x."Address 2" as address_2,
    x."Address 3" as address_3,
    x."town" as town,
    x."postcode" as postcode,
    'Y' as "Tags provided",
    '' as "Key pin number"
from member_signups s
left join raw_members m
    on s.member = concat(m."First name", ' ', m."Last name")
   and m."Membership" = s.product
left join raw_contacts x
    on s.payer = concat(x."First name", ' ', x."Last name")
where s.batch_id = $1
order by s.signup_date;
```

Notes:

- Use explicit `left join` syntax for both joined tables.
- Use `hh24:mi` rather than `hh:mm` to avoid ambiguous 12-hour output.
- Query by `batch_id`, not by `status`, so the result is stable even if later batches are created.

### 3. Batch Completion workflow

This is a manually triggered n8n workflow that accepts a `batch_id`.

#### Objective

Mark all signups in the batch as `Complete` and close the batch.

#### Recommended workflow steps

1. Trigger manually with `batch_id`.
2. Validate that the batch exists and is currently `Processing`.
3. Update the related `member_signups` rows to `Complete`.
4. Update the `signup_batches` row to `Complete` and set `completed_at = now()`.
5. Return counts for auditability.

#### Example completion SQL pattern

```sql
with updated_signups as (
    update member_signups
    set status = 'Complete'
    where batch_id = $1
      and status = 'Processing'
    returning id
),
updated_batch as (
    update signup_batches
    set status = 'Complete',
        completed_at = now()
    where id = $1
      and status = 'Processing'
    returning id
)
select
    (select id from updated_batch) as batch_id,
    (select count(*) from updated_signups) as completed_signup_count;
```

If no batch row is updated, the workflow should fail with a clear message such as `Batch not found or already complete`.

## Error Handling

### Parser workflow

- If parsing fails before insert, no row is created.
- If parsing fails after insert, set the signup status to `Error` and capture diagnostic detail if that column already exists or is later added.

### Batch creation workflow

- If there are no `New` signups, do not create a batch.
- If the enrichment query returns partial data because joins do not match, still return the signup row with `NULL` joined fields.
- If the SQL node fails, the workflow should stop and surface the database error to the operator.

### Batch completion workflow

- Reject attempts to complete a nonexistent batch.
- Reject attempts to complete an already completed batch.
- Surface the count of updated rows so the operator can verify the result.

## Concurrency and Consistency

The main risk is duplicate or overlapping batch creation from multiple manual runs. The design reduces this risk by:

- updating all eligible rows in one SQL statement,
- creating the batch only if candidate rows exist,
- selecting output by `batch_id`,
- keeping batch state separate from signup state.

If concurrent operators are expected, the SQL can be hardened further with transaction-level locking or `select ... for update skip locked`. That is not the first recommendation unless concurrency becomes a real operational issue.

## Observability

The workflows should return:

- `batch_id`
- number of signups assigned or completed
- batch status
- timestamps when useful for the operator

This is sufficient for the first iteration. A later iteration could add an audit table or workflow execution log links.

## Validation Plan

Validation should cover:

1. Parser creates signups with `status = 'New'` and `batch_id = NULL`.
2. Batch creation with multiple `New` rows creates one batch and assigns all rows to it.
3. Batch creation with zero `New` rows creates no batch.
4. Enrichment query returns expected address and member fields when source data matches.
5. Batch completion marks all related `Processing` rows as `Complete`.
6. Completing the same batch twice fails safely.
7. Signups already in `Processing` or `Complete` are never included in a new batch.

Test payloads referenced in the plan are available at `/mnt/c/dev/avondale-data/emailstore`.

## Implementation Notes

- Use PostgreSQL nodes for the core state transitions rather than splitting state changes across many n8n nodes.
- Keep batch creation and completion SQL centralized so the workflow logic stays simple and reviewable.
- Return `batch_id` from the creation workflow and require it as input for the completion workflow.
- Prefer id-based joins and source-system keys in the future if available; name concatenation is acceptable for this iteration but is inherently fragile.

## Open Questions

- Does `member_signups` already contain `status` and `batch_id`, or should migrations add them?
- Should batch completion mark every row in the batch as complete regardless of current signup status, or only rows still marked `Processing`?
- Is there a requirement to store export snapshots, or is regenerating the dataset by `batch_id` sufficient?
