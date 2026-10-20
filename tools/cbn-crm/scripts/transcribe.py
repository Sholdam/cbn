"""Offline transcription adapter; no credentials, network downloads or shell commands."""
import sys
import json
import os

os.environ['HF_HUB_OFFLINE'] = '1'
if len(sys.argv) > 3 and sys.argv[3]:
    sys.path.insert(0, sys.argv[3])
from faster_whisper import WhisperModel

model = WhisperModel(sys.argv[2], device='cpu', compute_type='int8', cpu_threads=3, local_files_only=True)
segments, info = model.transcribe(sys.argv[1], language='pt', beam_size=5, vad_filter=True)
rows = [{'start': round(s.start, 2), 'end': round(s.end, 2), 'text': s.text.strip()} for s in segments]
print(json.dumps({'language': info.language, 'text': ' '.join(s['text'] for s in rows), 'segments': rows,
                  'note': 'Transcrição automática; confirme números e informações críticas no áudio.'}, ensure_ascii=False))
