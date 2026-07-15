// Tiny, dependency-free, XSS-safe markdown renderer for KB articles.
// Everything is HTML-escaped FIRST, then a small set of markdown constructs is
// applied — so even though articles are admin-authored, a stray <script> (or a
// javascript: link) can never execute. Supports: #..###### headings, **bold**,
// *italic*, `inline code`, ``` fenced code ```, - / * bullet lists, and
// [text](http(s)://url) links. Anything else renders as plain paragraphs.
function escapeHtml(s) {
  return String(s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
}

function inline(text) {
  // text is already HTML-escaped by the caller.
  return text
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^*])\*([^*\n]+)\*/g, '$1<em>$2</em>')
    // Only http(s) links — blocks javascript:/data: URIs by construction.
    .replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)/g,
      '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');
}

export function renderMarkdown(src) {
  if (!src) return '';
  const lines = String(src).replace(/\r\n/g, '\n').split('\n');
  const out = [];
  let inList = false, inCode = false, code = [];
  const closeList = () => { if (inList) { out.push('</ul>'); inList = false; } };

  for (const line of lines) {
    if (line.trim() === '```') {
      if (inCode) { out.push(`<pre class="kb-code">${escapeHtml(code.join('\n'))}</pre>`); code = []; inCode = false; }
      else { closeList(); inCode = true; }
      continue;
    }
    if (inCode) { code.push(line); continue; }

    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) { closeList(); const lvl = h[1].length; out.push(`<h${lvl}>${inline(escapeHtml(h[2]))}</h${lvl}>`); continue; }

    const li = line.match(/^\s*[-*]\s+(.*)$/);
    if (li) { if (!inList) { out.push('<ul>'); inList = true; } out.push(`<li>${inline(escapeHtml(li[1]))}</li>`); continue; }

    if (line.trim() === '') { closeList(); continue; }

    closeList();
    out.push(`<p>${inline(escapeHtml(line))}</p>`);
  }
  if (inCode) out.push(`<pre class="kb-code">${escapeHtml(code.join('\n'))}</pre>`);
  closeList();
  return out.join('\n');
}
