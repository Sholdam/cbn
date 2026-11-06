ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS baseline
FROM node:24-alpine AS assets
WORKDIR /app
COPY --from=baseline /app /app
RUN apk add --no-cache python3 git && corepack enable && corepack prepare pnpm@10.2.0 --activate
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY Audio.vue /app/app/javascript/dashboard/components-next/message/chips/Audio.vue
COPY useCbnAudioPlayback.js Audio.spec.js /app/app/javascript/dashboard/components-next/cbn-audio/
COPY CbnAudioTranscription.spec.js /app/app/javascript/dashboard/components-next/cbn-ai/
COPY CbnRealtimeRecovery.spec.js CbnMessageSync.spec.js /app/app/javascript/dashboard/helper/specs/
ENV NODE_OPTIONS=--max-old-space-size=2560 RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1
RUN pnpm exec vitest run app/javascript/dashboard/components-next/cbn-audio/Audio.spec.js app/javascript/dashboard/components-next/cbn-ai/CbnAudioTranscription.spec.js app/javascript/dashboard/helper/specs/CbnRealtimeRecovery.spec.js app/javascript/dashboard/helper/specs/CbnMessageSync.spec.js --maxWorkers=1 --minWorkers=1 --no-coverage
RUN pnpm exec vite build --mode production
FROM baseline
COPY --from=assets /app/public/vite /app/public/vite
COPY Audio.vue /app/app/javascript/dashboard/components-next/message/chips/Audio.vue
COPY useCbnAudioPlayback.js /app/app/javascript/dashboard/components-next/cbn-audio/
COPY --from=baseline /app/public/vite /tmp/cbn-old-vite
RUN ruby -rjson -e 'm=JSON.parse(File.read("/tmp/cbn-old-vite/.vite/manifest.json")); old=m.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; n=JSON.parse(File.read("/app/public/vite/.vite/manifest.json")); cur=n.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; File.open("/app/public/vite/"+cur["css"].first,"a"){|f|f.write("\n"+File.read("/tmp/cbn-old-vite/"+old["css"].first))}'
