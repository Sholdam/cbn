ARG BASE_IMAGE=cbn/chatwoot:4.16.2-cbn-inss-resume-20261030
FROM ${BASE_IMAGE} AS baseline
FROM node:24-alpine AS assets
WORKDIR /app
COPY --from=baseline /app /app
RUN apk add --no-cache python3 git && corepack enable && corepack prepare pnpm@10.2.0 --activate
RUN pnpm install --frozen-lockfile --ignore-scripts
COPY ResolveAction.vue /app/app/javascript/dashboard/components/buttons/ResolveAction.vue
COPY CbnResolveClassification.vue /app/app/javascript/dashboard/components-next/cbn-resolution/CbnResolveClassification.vue
COPY CbnResolveClassification.spec.js /app/app/javascript/dashboard/components-next/cbn-resolution/CbnResolveClassification.spec.js
ENV NODE_OPTIONS=--max-old-space-size=2560 RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1
RUN pnpm exec vitest run app/javascript/dashboard/components-next/cbn-resolution/CbnResolveClassification.spec.js --maxWorkers=1 --minWorkers=1 --no-coverage
RUN pnpm exec vite build --mode production
FROM baseline
COPY cbn_resolution_classification.rb /app/config/initializers/cbn_resolution_classification.rb
COPY resolution_classifications_controller.rb /app/app/controllers/api/v1/accounts/conversations/resolution_classifications_controller.rb
COPY --from=assets /app/public/vite /app/public/vite
COPY --from=assets /app/app/javascript/dashboard/components/buttons/ResolveAction.vue /app/app/javascript/dashboard/components/buttons/ResolveAction.vue
COPY CbnResolveClassification.vue /app/app/javascript/dashboard/components-next/cbn-resolution/CbnResolveClassification.vue
# Retain the existing CBN theme overrides appended by earlier releases.
COPY --from=baseline /app/public/vite /tmp/cbn-old-vite
RUN ruby -rjson -e 'm=JSON.parse(File.read("/tmp/cbn-old-vite/.vite/manifest.json")); old=m.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; n=JSON.parse(File.read("/app/public/vite/.vite/manifest.json")); cur=n.values.find{|e|e["isEntry"] && e["file"].start_with?("assets/dashboard-")}; File.open("/app/public/vite/"+cur["css"].first,"a"){|f|f.write("\n"+File.read("/tmp/cbn-old-vite/"+old["css"].first))}'
RUN ruby -c /app/config/initializers/cbn_resolution_classification.rb && ruby -c /app/app/controllers/api/v1/accounts/conversations/resolution_classifications_controller.rb
