const fs = require('fs');
const path = 'workflows/preview-case-tracking-email.json';
const data = JSON.parse(fs.readFileSync(path, 'utf8'));
const node = data.nodes.find(n => n.name === 'Build Preview HTML');
if (!node) { console.log('Node not found'); process.exit(1); }

const newCode = `const item = $('Render Preview Data').first()?.json ?? {};
const escapeHtml = (value) => String(value ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\\\"/g, '&quot;').replace(/'/g, '&#39;');
const modeChecked = item.delivery_mode === 'production' ? '' : ' checked';
const previewPanel = item.email_type === 'html' ? '<div class="card bg-base-100 border border-base-300"><div class="card-body"><h2 class="card-title">Rendered preview</h2><div class="prose max-w-none">' + item.combined_preview_html + '</div></div></div>' : '';
const warningHtml = item.missing_recipient ? '<div class="alert alert-warning"><span>' + escapeHtml(item.missing_recipient) + '</span></div>' : '';
const html = [
  '<!doctype html>',
  '<html lang="en">',
  '<head>',
  '  <meta charset="utf-8">',
  '  <meta name="viewport" content="width=device-width, initial-scale=1">',
  '  <title>Email preview</title>',
  '  <link href="https://cdn.jsdelivr.net/npm/daisyui@5" rel="stylesheet" type="text/css" />',
  '  <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>',
  '</head>',
  '<body class="bg-base-200 min-h-screen">',
  '  <main class="max-w-6xl mx-auto p-4 lg:p-6 space-y-6">',
  '    <div class="flex flex-wrap items-center justify-between gap-3">',
  '      <div><div class="text-sm text-base-content/60">Case</div><h1 class="text-3xl font-bold">' + escapeHtml(item.case_title || 'Email preview') + '</h1></div>',
  '      <a class="btn btn-ghost" href="' + escapeHtml(item.return_url) + '">Back to case</a>',
  '    </div>',
  '    ' + warningHtml,
  '    <section class="grid gap-6 xl:grid-cols-[minmax(0,1fr)_380px]">',
  '      <div class="card bg-base-100 shadow-sm border border-base-300">',
  '        <div class="card-body">',
  '          <h2 class="card-title">Compose</h2>',
  '          <form class="space-y-3" method="POST" action="' + escapeHtml(item.send_url) + '">',
  '            <input type="hidden" name="case_id" value="' + escapeHtml(item.case_id) + '">',
  '            <input type="hidden" name="template_key" value="' + escapeHtml(item.template_key) + '">',
  '            <input type="hidden" name="signature_template_key" value="' + escapeHtml(item.signature_template_key) + '">',
  '            <input type="hidden" name="email_type" value="' + escapeHtml(item.email_type) + '">',
  '            <input type="hidden" name="return_url" value="' + escapeHtml(item.return_url) + '">',
  '            <label class="form-control"><span class="label-text">Recipient</span><input class="input input-bordered" type="email" name="to" value="' + escapeHtml(item.intended_recipient) + '" required></label>',
  '            <label class="form-control"><span class="label-text">Subject</span><input class="input input-bordered" type="text" name="rendered_subject" value="' + escapeHtml(item.rendered_subject) + '" required></label>',
  '            <label class="form-control"><span class="label-text">Message ' + (item.email_type === 'html' ? '(HTML)' : '(text)') + '</span><textarea class="textarea textarea-bordered min-h-72" name="rendered_message" required>' + escapeHtml(item.rendered_message) + '</textarea></label>',
  '            <label class="form-control"><span class="label-text">Signature</span><textarea class="textarea textarea-bordered min-h-40" name="rendered_signature">' + escapeHtml(item.rendered_signature) + '</textarea></label>',
  '            <label class="label cursor-pointer justify-start gap-3"><input class="checkbox" type="checkbox" name="test_mode" value="1"' + modeChecked + '><span class="label-text">Send in test mode</span></label>',
  '            <div class="text-sm text-base-content/60">Actual recipient: ' + escapeHtml(item.actual_recipient || item.test_recipient) + '</div>',
  '            <button class="btn btn-primary" type="submit"' + (item.missing_recipient ? ' disabled' : '') + '>Send email</button>',
  '          </form>',
  '        </div>',
  '      </div>',
  '      <div class="space-y-4">',
  '        <div class="card bg-base-100 shadow-sm border border-base-300"><div class="card-body"><h2 class="card-title">Template</h2><div class="text-sm">' + escapeHtml(item.template_name || item.template_key) + '</div><div class="text-sm text-base-content/60">Signature: ' + escapeHtml(item.signature_template_name || item.signature_template_key) + '</div></div></div>',
  '        ' + previewPanel,
  '      </div>',
  '    </section>',
  '  </main>',
  '</body>',
  '</html>'
].join('');
return [{ json: { html } }];`;

node.parameters.jsCode = newCode;
fs.writeFileSync(path, JSON.stringify(data, null, 2) + '\n');
console.log('Updated - reverted to simple textarea');