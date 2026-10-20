import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export async function transcribe(filePath, config) {
  if (!config?.python || !config?.modelPath) throw new Error('Transcrição não configurada. Configure Python e um modelo faster-whisper local; o áudio pode ser baixado ou retornado inline.');
  const script = fileURLToPath(new URL('../scripts/transcribe.py', import.meta.url));
  return new Promise((resolve, reject) => {
    const child = spawn(config.python, [script, filePath, config.modelPath, config.packagesPath || ''], {
      windowsHide: true, shell: false, stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, PYTHONUTF8: '1', HF_HUB_OFFLINE: '1', TRANSFORMERS_OFFLINE: '1' },
    });
    let output = ''; let finished = false;
    const finish = (error, value) => { if (finished) return; finished = true; clearTimeout(timer); error ? reject(error) : resolve(value); };
    const timer = setTimeout(() => { child.kill(); finish(new Error('Transcrição excedeu 180 segundos.')); }, 180_000);
    child.stdout.on('data', data => { output += data; if (output.length > 1_000_000) { child.kill(); finish(new Error('Transcrição excedeu o limite de saída.')); } });
    // Do not forward third-party stderr: it can contain filenames, URLs or customer content.
    child.stderr.resume();
    child.on('error', () => finish(new Error('Não foi possível iniciar o transcritor local.')));
    child.on('close', code => {
      if (code !== 0) return finish(new Error('Transcrição local falhou. Verifique Python, bibliotecas e modelo em disco.'));
      try { finish(null, JSON.parse(output)); } catch { finish(new Error('Resposta do transcritor inválida.')); }
    });
  });
}
