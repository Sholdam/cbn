ARG BASE_IMAGE
FROM ${BASE_IMAGE} AS baseline
FROM node:24-alpine AS assets
WORKDIR /app
COPY --from=baseline /app /app
RUN apk add --no-cache python3 git && corepack enable && corepack prepare pnpm@10.2.0 --activate
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY CbnRealtimeRecovery.js CbnMessageSync.js /app/app/javascript/dashboard/helper/
COPY CbnRealtimeRecovery.spec.js CbnMessageSync.spec.js /app/app/javascript/dashboard/helper/specs/
COPY patch_frontend.cjs /tmp/patch_frontend.cjs
RUN node /tmp/patch_frontend.cjs /app
ENV NODE_OPTIONS=--max-old-space-size=2560 RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1
RUN pnpm exec vitest run app/javascript/dashboard/helper/specs/CbnRealtimeRecovery.spec.js app/javascript/dashboard/helper/specs/CbnMessageSync.spec.js app/javascript/dashboard/helper/specs/ReconnectService.spec.js app/javascript/dashboard/helper/specs/actionCable.spec.js app/javascript/widget/helpers/specs/actionCable.spec.js --maxWorkers=1 --minWorkers=1 --no-coverage
RUN pnpm exec vite build --mode production
FROM baseline
COPY --from=assets /app/public/vite /app/public/vite
COPY --from=assets /app/app/javascript/dashboard/App.vue /app/app/javascript/dashboard/App.vue
COPY --from=assets /app/app/javascript/shared/helpers/BaseActionCableConnector.js /app/app/javascript/shared/helpers/BaseActionCableConnector.js
COPY --from=assets /app/app/javascript/dashboard/store/modules/conversations/actions.js /app/app/javascript/dashboard/store/modules/conversations/actions.js
COPY CbnRealtimeRecovery.js CbnMessageSync.js /app/app/javascript/dashboard/helper/
COPY --from=baseline /app/public/vite /tmp/cbn-old-vite
RUN ruby -rjson -e 'm=JSON.parse(File.read("/tmp/cbn-old-vite/.vite/manifest.json")); old=m.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; n=JSON.parse(File.read("/app/public/vite/.vite/manifest.json")); cur=n.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; File.open("/app/public/vite/"+cur["css"].first,"a"){|f|f.write("\n"+File.read("/tmp/cbn-old-vite/"+old["css"].first))}'
