import fs from 'node:fs/promises';
import path from 'node:path';

const rootDir = process.argv[2] ?? '/mnt/c/dev/avondale-data/Email Templates';

const excludedNames = new Set(['images.txt', 'To Do.txt']);
const subjectOverrides = new Map([
  ['shoe_tag_pigeon_hole', 'Message from Avondale about your tags'],
]);

const sqlLiteral = (value) => {
  if (value === null || value === undefined) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
};

const slugify = (value) =>
  value
    .normalize('NFKD')
    .replace(/[^\w\s/-]+/g, '')
    .replace(/[\\/]+/g, '/')
    .trim()
    .replace(/\s+/g, '_')
    .replace(/\//g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();

const titleize = (value) =>
  value
    .split(/[\\/]/)
    .map((part) => part.replace(/\.[^.]+$/, ''))
    .join(' / ');

const normalizeRelativePath = (relativePath) => relativePath.replace(/\\/g, '/');

const isTemplateFile = (relativePath) => {
  const normalized = normalizeRelativePath(relativePath);
  const basename = path.basename(normalized);
  if (normalized.includes('/images/')) return false;
  if (excludedNames.has(basename)) return false;
  if (basename === 'signature html') return true;
  return /\.(txt|html)$/i.test(basename);
};

const logicalStem = (relativePath) => {
  const normalized = normalizeRelativePath(relativePath);
  if (normalized.endsWith('/signature html')) {
    return normalized.replace(/\/signature html$/, '/signature');
  }
  return normalized.replace(/\.(txt|html)$/i, '');
};

const sourceGroupFromPath = (relativePath) => {
  const normalized = normalizeRelativePath(relativePath);
  const firstSegment = normalized.split('/')[0] ?? '';
  return firstSegment || 'root';
};

const stripSubjectLine = (content) => {
  const normalized = content
    .replace(/^\uFEFF?"/, '')
    .replace(/"\s*$/, '')
    .replace(/\r\n/g, '\n');
  const match = normalized.match(/^Subject:\s*(.+?)\n\n?/i);
  if (!match) return { subject: null, body: normalized };
  return {
    subject: match[1].trim(),
    body: normalized.slice(match[0].length),
  };
};

const walk = async (dir) => {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(fullPath)));
    } else {
      files.push(fullPath);
    }
  }
  return files;
};

const files = (await walk(rootDir))
  .map((fullPath) => ({
    fullPath,
    relativePath: normalizeRelativePath(path.relative(rootDir, fullPath)),
  }))
  .filter(({ relativePath }) => isTemplateFile(relativePath));

const grouped = new Map();

for (const file of files) {
  const stem = logicalStem(file.relativePath);
  const key = slugify(stem);
  const group = grouped.get(key) ?? {
    template_key: key,
    template_name: titleize(stem),
    subject_template: null,
    text_template: null,
    html_template: null,
    source_group: sourceGroupFromPath(file.relativePath),
    source_txt_path: null,
    source_html_path: null,
    is_active: !normalizeRelativePath(file.relativePath).includes('Not Used/'),
  };

  const rawContent = await fs.readFile(file.fullPath, 'utf8');
  const { subject, body } = stripSubjectLine(rawContent);
  if (!group.subject_template && subject) {
    group.subject_template = subject;
  }

  if (file.relativePath.endsWith('.html') || file.relativePath.endsWith('signature html')) {
    group.html_template = body;
    group.source_html_path = file.relativePath;
  } else {
    group.text_template = body;
    group.source_txt_path = file.relativePath;
  }

  if (!group.subject_template && subjectOverrides.has(key)) {
    group.subject_template = subjectOverrides.get(key);
  }

  grouped.set(key, group);
}

const values = Array.from(grouped.values())
  .sort((a, b) => a.template_key.localeCompare(b.template_key))
  .map((row) => `(
    ${sqlLiteral(row.template_key)},
    ${sqlLiteral(row.template_name)},
    ${sqlLiteral(row.subject_template)},
    ${sqlLiteral(row.text_template)},
    ${sqlLiteral(row.html_template)},
    ${sqlLiteral(row.source_group)},
    ${sqlLiteral(row.source_txt_path)},
    ${sqlLiteral(row.source_html_path)},
    ${row.is_active ? 'TRUE' : 'FALSE'}
  )`)
  .join(',\n');

const sql = `BEGIN;
INSERT INTO public.email_templates (
  template_key,
  template_name,
  subject_template,
  text_template,
  html_template,
  source_group,
  source_txt_path,
  source_html_path,
  is_active
)
VALUES
${values}
ON CONFLICT (template_key) DO UPDATE SET
  template_name = EXCLUDED.template_name,
  subject_template = EXCLUDED.subject_template,
  text_template = EXCLUDED.text_template,
  html_template = EXCLUDED.html_template,
  source_group = EXCLUDED.source_group,
  source_txt_path = EXCLUDED.source_txt_path,
  source_html_path = EXCLUDED.source_html_path,
  is_active = EXCLUDED.is_active,
  updated_at = now();
COMMIT;
`;

process.stdout.write(sql);
