FROM cbn/chatwoot:4.16.2-cbn-local AS assets
WORKDIR /app
COPY scripts/fix-chatwoot-relative-media.rb /tmp/fix-relative-media.rb
RUN ruby /tmp/fix-relative-media.rb
RUN --mount=type=tmpfs,target=/app/node_modules pnpm install --offline --frozen-lockfile --ignore-scripts --package-import-method=copy && \
    NODE_OPTIONS=--max-old-space-size=4096 RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 pnpm exec vite build --mode production

FROM cbn/chatwoot:4.16.2-cbn-local
COPY --from=assets /app/public/vite /app/public/vite
COPY --from=assets /app/app/javascript/dashboard/helper/URLHelper.js /app/app/javascript/dashboard/helper/URLHelper.js
COPY --from=assets /app/app/javascript/shared/helpers/MessageFormatter.js /app/app/javascript/shared/helpers/MessageFormatter.js
