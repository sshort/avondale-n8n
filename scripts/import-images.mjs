import fs from 'node:fs/promises';
import path from 'node:path';

const rootDir = process.argv[2] ?? '/mnt/c/dev/avondale-n8n/site/images';

const normalizeRelativePath = (relativePath) => relativePath.replace(/\\/g, '/');

const slugify = (value) =>
  value
    .normalize('NFKD')
    .replace(/[^\w\s/-]+/g, '')
    .trim()
    .replace(/\s+/g, '_')
    .replace(/[/-]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toLowerCase();

const sqlLiteral = (value) => {
  if (value === null || value === undefined) return 'NULL';
  return `'${String(value).replace(/'/g, "''")}'`;
};

const mimeTypeForExt = (ext) => {
  switch (ext.toLowerCase()) {
    case '.png':
      return 'image/png';
    case '.svg':
      return 'image/svg+xml';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.gif':
      return 'image/gif';
    case '.webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
};

const files = (await fs.readdir(rootDir, { withFileTypes: true }))
  .filter((entry) => entry.isFile())
  .map((entry) => entry.name)
  .sort((a, b) => a.localeCompare(b));

const values = [];

for (const fileName of files) {
  const fullPath = path.join(rootDir, fileName);
  const fileBuffer = await fs.readFile(fullPath);
  const ext = path.extname(fileName);
  const stem = path.basename(fileName, ext);
  const imageKey = slugify(stem);
  const relativePath = normalizeRelativePath(path.relative('/mnt/c/dev/avondale-n8n', fullPath));
  const base64 = fileBuffer.toString('base64');

  values.push(`(
    ${sqlLiteral(imageKey)},
    ${sqlLiteral(fileName)},
    ${sqlLiteral(ext.replace(/^\./, '').toLowerCase())},
    ${sqlLiteral(mimeTypeForExt(ext))},
    ${fileBuffer.length},
    ${sqlLiteral(relativePath)},
    decode(${sqlLiteral(base64)}, 'base64'),
    TRUE
  )`);
}

const sql = `BEGIN;
INSERT INTO public.images (
  image_key,
  file_name,
  file_ext,
  content_type,
  byte_size,
  source_path,
  data,
  is_active
)
VALUES
${values.join(',\n')}
ON CONFLICT (image_key) DO UPDATE SET
  file_name = EXCLUDED.file_name,
  file_ext = EXCLUDED.file_ext,
  content_type = EXCLUDED.content_type,
  byte_size = EXCLUDED.byte_size,
  source_path = EXCLUDED.source_path,
  data = EXCLUDED.data,
  is_active = EXCLUDED.is_active,
  updated_at = now();
COMMIT;
`;

process.stdout.write(sql);
