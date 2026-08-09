FROM chatwoot/chatwoot:v4.16.2

USER root

# Backend patch loaded by both Rails web and Sidekiq.
COPY patches/cbn_whatsapp_agent_name.rb /app/config/initializers/cbn_whatsapp_agent_name.rb

# Patch the existing Chatwoot settings source, then rebuild production assets so
# WhatsApp inboxes get a real on/off switch in the dashboard.
COPY patches/patch_settings.rb /tmp/cbn_patch_settings.rb

RUN ruby /tmp/cbn_patch_settings.rb \
  && ln -sf /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -sf /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@10.2.0 \
  && cd /app \
  && pnpm install --frozen-lockfile --prod=false \
  && SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile \
  && rm -rf /app/node_modules /app/tmp/cache /tmp/cbn_patch_settings.rb

WORKDIR /app
EXPOSE 3000
