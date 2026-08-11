import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const html = await readFile(new URL("../public/index.html", import.meta.url), "utf8");
const visibleSource = html.replace(/data:image\/[a-z+.-]+;base64,[A-Za-z0-9+/=]+/g, "");

test("site identifica a CBN e não mistura a marca Help", () => {
  assert.match(visibleSource, /CBN CRÉDITO/);
  assert.doesNotMatch(visibleSource, /Help|BMG/i);
});

test("WhatsApp e Instagram estão configurados", () => {
  assert.match(html, /wa\.me\/5527998812153/);
  assert.match(html, /instagram\.com\/cbncredito/);
});

test("página tem metadados e acessibilidade essenciais", () => {
  assert.match(html, /<meta name="description"/);
  assert.match(html, /lang="pt-BR"/);
  assert.match(html, /aria-label=/);
});
