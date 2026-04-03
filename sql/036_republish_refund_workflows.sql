BEGIN;

WITH target AS (
  SELECT
    we.id AS workflow_id,
    we.name,
    we.nodes,
    we.connections,
    we.description,
    COALESCE(
      (
        SELECT wh.authors
        FROM n8n.workflow_history wh
        WHERE wh."workflowId" = we.id
        ORDER BY wh."createdAt" DESC
        LIMIT 1
      ),
      'Steve Short'
    ) AS authors,
    gen_random_uuid() AS new_version_id
  FROM n8n.workflow_entity we
  WHERE we.id IN (
    'FmFGVKMxZLcPv6d7', -- Add Refund
    'KJ7Ys7oAxo0yGYhi', -- Preview Refund Request Email
    'Xs8KENEX5n7KKJsD', -- Refund Form
    'u7bO4JKVEaqtn2hl', -- Refund Status Form
    'ovfzjVKGfC2dt8qw', -- Send Refund Request Email
    'ouYD0m2No7IBTYH4'  -- Update Refund Status
  )
),
ins_history AS (
  INSERT INTO n8n.workflow_history (
    "versionId",
    "workflowId",
    authors,
    "createdAt",
    "updatedAt",
    nodes,
    connections,
    name,
    autosaved,
    description
  )
  SELECT
    new_version_id,
    workflow_id,
    authors,
    NOW(),
    NOW(),
    nodes,
    connections,
    name,
    FALSE,
    description
  FROM target
  RETURNING "workflowId", "versionId"
),
upd_workflow AS (
  UPDATE n8n.workflow_entity we
  SET
    active = TRUE,
    "activeVersionId" = ih."versionId",
    "updatedAt" = NOW()
  FROM ins_history ih
  WHERE we.id = ih."workflowId"
  RETURNING we.id
)
INSERT INTO n8n.workflow_publish_history (
  "workflowId",
  "versionId",
  event,
  "userId",
  "createdAt"
)
SELECT
  "workflowId",
  "versionId",
  'activated',
  '1aa25644-d384-4810-beaa-f58314d3e70c',
  NOW()
FROM ins_history;

DELETE FROM n8n.webhook_entity
WHERE ("webhookPath", method) IN (
  WITH target_hooks AS (
    SELECT
      n->'parameters'->>'path' AS webhook_path,
      UPPER(n->'parameters'->>'httpMethod') AS method
    FROM n8n.workflow_entity we
    CROSS JOIN LATERAL jsonb_array_elements(we.nodes::jsonb) n
    WHERE we.id IN (
      'FmFGVKMxZLcPv6d7',
      'KJ7Ys7oAxo0yGYhi',
      'Xs8KENEX5n7KKJsD',
      'u7bO4JKVEaqtn2hl',
      'ovfzjVKGfC2dt8qw',
      'ouYD0m2No7IBTYH4'
    )
      AND n->>'type' = 'n8n-nodes-base.webhook'
  )
  SELECT webhook_path, method
  FROM target_hooks
);

INSERT INTO n8n.webhook_entity (
  "webhookPath",
  method,
  node,
  "webhookId",
  "pathLength",
  "workflowId"
)
SELECT
  n->'parameters'->>'path' AS webhook_path,
  UPPER(n->'parameters'->>'httpMethod') AS method,
  n->>'name' AS node,
  COALESCE(n->>'webhookId', n->'parameters'->>'path') AS webhook_id,
  CHAR_LENGTH(n->'parameters'->>'path') AS path_length,
  we.id AS workflow_id
FROM n8n.workflow_entity we
CROSS JOIN LATERAL jsonb_array_elements(we.nodes::jsonb) n
WHERE we.id IN (
  'FmFGVKMxZLcPv6d7',
  'KJ7Ys7oAxo0yGYhi',
  'Xs8KENEX5n7KKJsD',
  'u7bO4JKVEaqtn2hl',
  'ovfzjVKGfC2dt8qw',
  'ouYD0m2No7IBTYH4'
)
  AND n->>'type' = 'n8n-nodes-base.webhook';

COMMIT;
