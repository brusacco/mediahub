---
type: Reference
title: Rails and dependency Rake tasks
description: Standard tasks contributed by Rails and installed gems.
tags: [rake, rails, framework]
generated: { by: process:codex, at: 2026-10-27T12:00:00-03:00 }
resource: Rakefile
---

# Current complete listing

The installed framework and gem versions determine this part of the catalog. Always query the current environment rather than relying on a stale copied list:

```bash
RAILS_ENV=production bundle exec rake -T
RAILS_ENV=production bundle exec rake -T db
RAILS_ENV=production bundle exec rake -T assets
```

# Families currently available

| Family | Purpose | Important caution |
| --- | --- | --- |
| `db:*` | Create, migrate, seed, inspect, reset, and manage schema cache. | `db:drop`, `db:reset`, `db:setup`, and `db:seed:replant` can destroy/recreate production data. |
| `assets:*`, `tailwindcss:*` | Compile or remove compiled frontend assets. | `assets:clobber` removes compiled assets. |
| `tmp:*`, `log:clear`, `cache_digests:*` | Clear transient files/logs or inspect view cache dependencies. | `tmp:clear` and `log:clear` remove diagnostic data. |
| `test`, `zeitwerk:check`, `stats` | Validate tests, autoloading, and code statistics. | Read-only aside from normal test database setup. |
| `action_mailbox:*`, `action_text:*`, `active_storage:*` | Install Rails feature migrations and integration configuration. | Installation tasks change the application and should not be run casually in production. |
| `stimulus:*`, `turbo:*`, `importmap:*`, `yarn:*` | Install or regenerate frontend integration files/dependencies. | Setup tasks can overwrite generated frontend files. |
| `acts_as_taggable_on*` | Install migrations or change tag-name collation. | Collation tasks mutate database data. |
| `app:*`, `time:zones` | Rails app template/update utilities and time-zone lookup. | `app:update` changes generated configuration. |

Use `bundle exec rake -T <prefix>` to see every task within a family, including the description supplied by the installed Rails version.
