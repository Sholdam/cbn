import MarkdownIt from 'markdown-it';

// Stored Chatwoot content remains CommonMark. Convert only once, at delivery.
const markdown = new MarkdownIt({ html: false, linkify: false, typographer: false });

function repairMarkWhitespace(text) {
  const protectedParts = [];
  let prefix = '\uE000CBN';
  while (text.includes(prefix)) prefix += 'X';
  const protect = value => `${prefix}${protectedParts.push(value) - 1}\uE001`;
  let source = text.replace(/```[\s\S]*?```|`[^`\n]+`|https?:\/\/[^\s<>]+/g, protect);
  source = source.replace(/\\\r?\n/g, '\n');
  const normalize = (whole, body, mark) => {
    const value = body.trim();
    if (!value) return body;
    const leading = body.slice(0, body.length - body.trimStart().length);
    const trailing = body.slice(body.trimEnd().length);
    return `${leading}${mark}${value}${mark}${trailing}`;
  };
  source = source.replace(/(?<!\*)\*\*(?!\*)([\s\S]*?)(?<!\*)\*\*(?!\*)/g,
    (whole, body) => normalize(whole, body, '**'));
  source = source.replace(/(?<!~)~~(?!~)([\s\S]*?)(?<!~)~~(?!~)/g,
    (whole, body) => normalize(whole, body, '~~'));
  protectedParts.forEach((part, index) => {
    source = source.replace(`${prefix}${index}\uE001`, () => part);
  });
  return source;
}

function wrap(text, marker) {
  // WhatsApp requires non-space characters beside each delimiter, per line.
  return text.split('\n').map(line => {
    if (!line.trim()) return line;
    const start = line.match(/^\s*/)[0];
    const end = line.match(/\s*$/)[0];
    return `${start}${marker}${line.trim()}${marker}${end}`;
  }).join('\n');
}

function inline(tokens = []) {
  let index = 0;
  const render = closing => {
    let output = '';
    while (index < tokens.length) {
      const token = tokens[index++];
      if (token.type === closing) break;
      if (token.type === 'strong_open') output += wrap(render('strong_close'), '*');
      else if (token.type === 'em_open') output += wrap(render('em_close'), '_');
      else if (token.type === 's_open') output += wrap(render('s_close'), '~');
      else if (token.type === 'link_open') {
        const href = token.attrGet('href') || '';
        const label = render('link_close');
        output += label === href || `mailto:${label}` === href ? label : `${label} (${href})`;
      } else if (token.type === 'code_inline') output += `\`${token.content}\``;
      else if (token.type === 'hardbreak' || token.type === 'softbreak') output += '\n';
      else if (token.type === 'image') output += token.content || token.attrGet('alt') || '';
      else output += token.content || '';
    }
    return output;
  };
  return render(null);
}

function tree(tokens) {
  const root = { children: [] };
  const stack = [root];
  for (const token of tokens) {
    if (token.nesting === -1) { stack.pop(); continue; }
    const node = { token, children: [] };
    stack[stack.length - 1].children.push(node);
    if (token.nesting === 1) stack.push(node);
  }
  return root;
}

function render(node) {
  const token = node.token;
  if (!token) return node.children.map(render).filter(Boolean).join('\n\n');
  if (token.type === 'inline') return inline(token.children);
  if (token.type === 'fence' || token.type === 'code_block') {
    return `\`\`\`\n${token.content.replace(/\n$/, '')}\n\`\`\``;
  }
  if (token.type === 'bullet_list_open' || token.type === 'ordered_list_open') {
    const first = Number(token.attrGet('start') || 1);
    return node.children.map((child, index) => {
      const prefix = token.type === 'bullet_list_open' ? '- ' : `${first + index}. `;
      return render(child).split('\n').map((line, i) => (i ? ' '.repeat(prefix.length) : prefix) + line).join('\n');
    }).join('\n');
  }
  if (token.type === 'blockquote_open') {
    return node.children.map(render).join('\n\n').split('\n').map(line => `> ${line}`).join('\n');
  }
  if (token.type === 'hr') return '---';
  if (node.children.length) {
    const separator = token.type === 'list_item_open' ? '\n' : '';
    return node.children.map(render).join(separator);
  }
  return token.content || '';
}

export function MarkdownToWhatsApp(text) {
  if (!text) return '';
  return render(tree(markdown.parse(repairMarkWhitespace(String(text)), {}))).trimEnd();
}
