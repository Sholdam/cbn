import { InputRule, inputRules } from '@chatwoot/prosemirror-schema';

export function whatsappInputRules(schema) {
  const definitions = [
    ['strong', /(?:^|[\s([{])(\*([^\s*\n](?:[^*\n]*[^\s*\n])?)\*)$/u],
    ['em', /(?:^|[\s([{])(_([^\s_\n](?:[^_\n]*[^\s_\n])?)_)$/u],
    ['strike', /(?:^|[\s([{])(~([^\s~\n](?:[^~\n]*[^\s~\n])?)~)$/u],
  ];
  const rules = definitions.filter(([name]) => schema.marks[name]).map(([name, pattern]) =>
    new InputRule(pattern, (state, match, start, end) => {
      if (state.selection.$from.parent.type.spec.code ||
          state.selection.$from.marks().some(mark => mark.type.name === 'code')) return null;
      const from = start + match[0].length - match[1].length;
      const text = match[2];
      // The closing character is not inserted yet. Remove only the opening
      // delimiter, preserving any existing nested marks in the selected text.
      return state.tr.delete(from, from + 1)
        .addMark(from, from + text.length, schema.marks[name].create())
        .removeStoredMark(schema.marks[name]);
    })
  );
  return inputRules({ rules });
}

// Only external plain-text paste uses WhatsApp syntax. Saved drafts and rich
// clipboard content retain the editor's CommonMark format.
export function whatsappPasteToMarkdown(text) {
  const parts = [];
  let prefix = '\uE000CBNPASTE';
  while (text.includes(prefix)) prefix += 'X';
  const protect = value => `${prefix}${parts.push(value) - 1}\uE001`;
  let source = text.replace(/```[\s\S]*?```|`[^`\n]+`|https?:\/\/[^\s<>]+|\*\*[^\n]+?\*\*|~~[^\n]+?~~/g, protect);
  source = source.replace(/(^|[^\p{L}\p{N}*])\*(?=\S)([^*\n]*?\S)\*(?![\p{L}\p{N}*])/gu,
    (_, before, body) => before + protect(`**${body}**`));
  source = source.replace(/(^|[^\p{L}\p{N}_])_(?=\S)([^_\n]*?\S)_(?![\p{L}\p{N}_])/gu,
    (_, before, body) => before + protect(`*${body}*`));
  source = source.replace(/(^|[^\p{L}\p{N}_~])~(?=\S)([^~\n]*?\S)~(?![\p{L}\p{N}_~])/gu,
    (_, before, body) => before + protect(`~~${body}~~`));
  for (let index = parts.length - 1; index >= 0; index -= 1) {
    source = source.replace(`${prefix}${index}\uE001`, () => parts[index]);
  }
  return source;
}
