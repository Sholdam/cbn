ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS baseline
FROM node:24-alpine AS assets
WORKDIR /app
COPY --from=baseline /app /app
RUN apk add --no-cache python3 git && corepack enable && corepack prepare pnpm@10.2.0 --activate
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY Audio.vue /app/app/javascript/dashboard/components-next/message/chips/Audio.vue
COPY CbnAudioTranscription.vue CbnAudioTranscription.spec.js /app/app/javascript/dashboard/components-next/cbn-ai/
ENV NODE_OPTIONS=--max-old-space-size=2560 RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1
RUN pnpm exec vitest run app/javascript/dashboard/components-next/cbn-ai/CbnAudioTranscription.spec.js --maxWorkers=1 --minWorkers=1 --no-coverage
RUN pnpm exec vite build --mode production
FROM baseline
COPY cbn_ai.rb /app/config/initializers/cbn_ai.rb
COPY audio_transcription.rb /app/app/services/cbn/audio_transcription.rb
COPY audio_transcription_job.rb /app/app/jobs/cbn/audio_transcription_job.rb
COPY cbn_audio_transcriptions_controller.rb /app/app/controllers/api/v1/accounts/cbn_audio_transcriptions_controller.rb
COPY llm.yml /app/config/llm.yml
COPY llm_models.json /app/config/llm_models.json
COPY --from=assets /app/public/vite /app/public/vite
COPY Audio.vue /app/app/javascript/dashboard/components-next/message/chips/Audio.vue
COPY CbnAudioTranscription.vue /app/app/javascript/dashboard/components-next/cbn-ai/CbnAudioTranscription.vue
COPY --from=baseline /app/public/vite /tmp/cbn-old-vite
RUN ruby -rjson -e 'm=JSON.parse(File.read("/tmp/cbn-old-vite/.vite/manifest.json")); old=m.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; n=JSON.parse(File.read("/app/public/vite/.vite/manifest.json")); cur=n.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; File.open("/app/public/vite/"+cur["css"].first,"a"){|f|f.write("\n"+File.read("/tmp/cbn-old-vite/"+old["css"].first))}'
