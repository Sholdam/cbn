import { readFile, stat, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { Resvg } from '@resvg/resvg-js';

export const SVG_PATH = resolve(
  import.meta.dirname,
  '../../assets/whatsapp/cbn-ctps-simulacao-header.svg',
);
export const PNG_PATH = resolve(
  import.meta.dirname,
  '../../assets/whatsapp/cbn-ctps-simulacao-header.png',
);

export async function renderCtpsHeader({
  svgPath = SVG_PATH,
  pngPath = PNG_PATH,
} = {}) {
  const svg = await readFile(svgPath, 'utf8');
  const renderer = new Resvg(svg, {
    fitTo: { mode: 'width', value: 800 },
    font: {
      loadSystemFonts: true,
      defaultFontFamily: 'Arial',
    },
  });
  const png = renderer.render().asPng();
  await writeFile(pngPath, png);

  const metadata = await stat(pngPath);
  if (metadata.size >= 300 * 1024) {
    throw new Error(
      `PNG gerado com ${metadata.size} bytes; reduza a complexidade para ficar abaixo de 300 KB.`,
    );
  }
  return { svgPath, pngPath, bytes: metadata.size, width: 800, height: 418 };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  renderCtpsHeader()
    .then((result) => console.log(JSON.stringify(result, null, 2)))
    .catch((error) => {
      console.error(`Falha ao renderizar o cabeçalho CTPS: ${error.message}`);
      process.exitCode = 1;
    });
}
