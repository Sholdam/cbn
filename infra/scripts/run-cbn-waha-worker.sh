#!/bin/sh
set -eu
ruby -ruri -e 'abort "WAHA worker requires isolated Redis DB 1" unless URI(ENV.fetch("REDIS_URL")).path == "/1"'
ruby -e 'abort "WAHA inbox must be provisioned before starting its worker" if ENV.fetch("CBN_WAHA_WEBHOOK_URL", "").empty?'
exec bundle exec sidekiq "$@"
