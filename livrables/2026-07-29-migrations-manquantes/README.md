# Migrations « en base mais absentes du dossier » — paquet de résolution

**Contexte** : le checker local signale 5 migrations présentes dans `_prisma_migrations`
mais sans fichier dans `server/db/prisma/migrations/`. Voici l'origine de chacune et
les fichiers prêts à déposer.

## Origine des 5 entrées

| Migration | Origine | Source canonique |
|---|---|---|
| `20260725143000_support_chat_sessions` | **Olivio — Centre d'aide** | PR saas **#1204** (`feat/help-center-panel`) — fichier committé dans la PR |
| `20260725190000_support_chat_rate_limits` | **Olivio — Centre d'aide** | PR saas **#1204** — idem |
| `20260727120000_add_agent_readonly_views` | **Olivio — couche 1 isolation agent support** | PR api-agent **#193** (`feat/support-messages-brain`) → `scripts/db/agent_ro_layer1.sql` (idempotent) |
| `20260727130000_harden_agent_readonly_views` | **Olivio — durcissement post smoke-test** (vues definer + `security_barrier`, cf. #193) | même script (l'état final durci est inclus dans `agent_ro_layer1.sql`) |
| `20260729130000_expose_agent_campaign_content` | **PAS de notre chantier** (datée 29/07 13h00 — aucune migration créée côté Olivio ce jour-là) | à récupérer auprès de celui qui l'a appliquée — voir § « Reconstituer la 5ᵉ » |

## Résolution immédiate

Le dossier `migrations/` ci-contre contient les **4 premiers** dossiers prêts à
copier dans `server/db/prisma/migrations/` :

- Les **2 support** sont des copies **byte-exactes** de la PR #1204 → le checksum
  `_prisma_migrations` correspondra. (Dès que #1204 est mergée dans dev, un simple
  pull les apporte — ces copies ne servent qu'en attendant.)
- Les **2 agent_ro** sont reconstruites depuis la source canonique
  (`agent_ro_layer1.sql`, idempotente : `CREATE OR REPLACE`, gardes d'existence).
  Elles sont **sûres à rejouer** sur une base fraîche. ⚠️ Si elles avaient été
  enregistrées via `prisma migrate deploy` à l'époque, le checksum stocké différera :
  `migrate deploy` signalera une « modified migration ». Dans ce cas, soit ignorer
  (les entrées sont déjà applied, deploy saute par nom), soit resynchroniser le
  checksum :

  ```sql
  UPDATE _prisma_migrations
  SET checksum = '<sha256 du nouveau fichier>'
  WHERE migration_name = '20260727120000_add_agent_readonly_views';
  ```

## Reconstituer la 5ᵉ (`expose_agent_campaign_content`)

Elle étend vraisemblablement `agent_ro.v_campaigns` (qui n'expose que
`id/type/created_at/updated_at` dans la couche 1) avec le contenu des campagnes.
Pour régénérer le fichier depuis la base où elle est appliquée :

```sql
SELECT pg_get_viewdef('agent_ro.v_campaigns'::regclass, true);
```

…et si d'autres objets ont été ajoutés ce jour-là :

```sql
SELECT viewname FROM pg_views WHERE schemaname = 'agent_ro' ORDER BY viewname;
```

## Rappel de l'ordre d'application (couche agent_ro)

1. `agent_ro_layer1.sql` (ou la migration `add_…`) — rôle `agent_reader`
   (⚠️ à créer **en SQL**, jamais depuis la console Neon : héritage `BYPASSRLS`),
   schéma `agent_ro`, vues definer `security_barrier`, fail-closed sur
   `current_setting('app.workspace_id', true)`.
2. `agent_ro_smoke_test.sql` (PR #193) — 7 vérifications.
3. Créer l'utilisateur de connexion + poser `DATABASE_URL_AGENT_RO` côté api-agent.

— Olivio (généré avec l'assistance de Claude), 2026-07-29
