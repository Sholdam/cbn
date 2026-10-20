from pathlib import Path

root=Path('/app/app/javascript')
p=root/'dashboard/components/widgets/conversation/ReplyBox.vue'
text=p.read_text()
anchor=':channel-type="channelType"'
assert text.count(anchor)==1, 'ReplyBox channel anchor changed'
text=text.replace(anchor, ':channel-type="inbox.id === 5 ? \'Channel::Whatsapp\' : channelType"')
p.write_text(text)

p=root/'dashboard/components/widgets/WootWriter/Editor.vue'
text=p.read_text()
anchor="import { INBOX_TYPES } from 'dashboard/helper/inbox';"
assert text.count(anchor)==1
text=text.replace(anchor,anchor+"\nimport { whatsappInputRules, whatsappPasteToMarkdown } from 'dashboard/helper/whatsappEditor';")
anchor='const editorSchema = computed(() => {'
assert text.count(anchor)==1
text=text.replace(anchor,"const usesWhatsAppSyntax = computed(() => !props.isPrivate && effectiveChannelType.value === 'Channel::Whatsapp');\n\n"+anchor)
anchor='''      methods,
      plugins,
      enabledMenuOptions: editorMenuOptions.value,'''
assert text.count(anchor)==1, 'Plugin priority anchor changed'
text=text.replace(anchor,'''      methods,
      plugins: usesWhatsAppSyntax.value ? [whatsappInputRules(schema), ...plugins] : plugins,
      enabledMenuOptions: editorMenuOptions.value,''')
anchor='''        if (!files.length) return;
        event.preventDefault();'''
assert text.count(anchor)==1, 'Clipboard anchor changed'
text=text.replace(anchor,'''        if (!files.length) {
          const plain = event.clipboardData.getData('text/plain');
          const html = event.clipboardData.getData('text/html');
          const hasRichMarks = /<(?:strong|b|em|i|s|strike|code|pre|ul|ol|blockquote)\\b/i.test(html);
          const inCode = view.state.selection.$from.parent.type.spec.code || view.state.selection.$from.marks().some(mark => mark.type.name === 'code');
          if (usesWhatsAppSyntax.value && !hasRichMarks && !inCode && /[*_~`]|^\\s*(?:[-+]\\s|\\d+\\.\\s|>\\s)/m.test(plain)) {
            event.preventDefault();
            const node = new MessageMarkdownTransformer(view.state.schema).parse(whatsappPasteToMarkdown(plain));
            const slice = node.slice(0);
            view.dispatch(view.state.tr.replaceSelection(slice).scrollIntoView());
            return;
          }
          return;
        }
        event.preventDefault();''')
p.write_text(text)

p=root/'dashboard/constants/editor.js'
text=p.read_text()
start=text.index("  'Channel::Whatsapp': {")
end=text.index("  'Channel::Line': {", start)
block=text[start:end]
block=block.replace("nodes: ['bulletList', 'orderedList', 'codeBlock']", "nodes: ['bulletList', 'orderedList', 'codeBlock', 'blockquote']")
text=text[:start]+block+text[end:]
p.write_text(text)

p=Path('/app/vite.config.ts')
text=p.read_text()
if 'build: { sourcemap: false }' not in text:
    text=text.replace('export default defineConfig({','export default defineConfig({\n  build: { sourcemap: false },',1)
p.write_text(text)
