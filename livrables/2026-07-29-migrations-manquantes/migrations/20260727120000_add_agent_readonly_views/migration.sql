-- Migration reconstruite depuis la source canonique :
--   api-agent PR #193, scripts/db/agent_ro_layer1.sql (idempotent)
-- BEGIN/COMMIT retires : Prisma execute chaque migration dans sa propre transaction.

-- =====================================================================
-- Couche 1 — LA garantie d'isolation de l'agent support (spec Samy)
-- =====================================================================
--
-- ⚠️ À EXÉCUTER PAR LE DÉVELOPPEUR / DBA, JAMAIS PAR L'AGENT.
--    Ce script crée un rôle, un schéma et des politiques RLS. Il ne
--    modifie aucune donnée et n'altère aucune table applicative.
--
-- POURQUOI
-- --------
-- Aujourd'hui l'isolation workspace de l'agent repose ENTIÈREMENT sur du
-- Python (registre `support_read_registry.py` + requêtes assemblées). Ça
-- tient, c'est testé, mais une seule erreur de revue suffirait à ouvrir
-- une fuite entre clients.
--
-- Ce script déplace la garantie dans Postgres : même si le code applicatif
-- était contourné, la base elle-même refuserait de rendre une ligne d'un
-- autre workspace, ou d'écrire quoi que ce soit.
--
-- C'EST AUSSI LE PRÉ-REQUIS DU SQL LIBRE. Tant que ce script n'est pas
-- appliqué, laisser un modèle écrire ses propres requêtes est indéfendable :
-- `schema_config.py:44-45` documente qu'un préfixe de schéma explicite
-- (`vertex.sessions`, `pg_catalog…`) contourne le schema_translate_map —
-- `custom_agent_repository.py:131` en fait déjà usage. Une requête libre
-- pourrait donc atteindre n'importe quel schéma. Après ce script, le rôle
-- `agent_reader` n'a matériellement plus accès à `public` ni `vertex`.
--
-- ORDRE D'APPLICATION : 1) ce script, 2) agent_ro_smoke_test.sql pour
-- vérifier, 3) créer l'utilisateur de connexion et poser
-- DATABASE_URL_AGENT_RO côté api-agent.
-- =====================================================================


-- ── 1. Rôle de lecture, sans droit d'écrire ni de contourner la RLS ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'agent_reader') THEN
    -- NOSUPERUSER + NOBYPASSRLS sont l'essentiel : un rôle créé depuis la
    -- console Neon hériterait de BYPASSRLS et annulerait toute la couche.
    CREATE ROLE agent_reader NOLOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE;
  END IF;
END
$$;

ALTER ROLE agent_reader SET default_transaction_read_only = on;
ALTER ROLE agent_reader SET statement_timeout = '5s';
ALTER ROLE agent_reader SET idle_in_transaction_session_timeout = '10s';

-- ── 2. Aucun accès direct aux schémas applicatifs ────────────────────
REVOKE ALL ON SCHEMA public FROM agent_reader;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM agent_reader;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'vertex') THEN
    EXECUTE 'REVOKE ALL ON SCHEMA vertex FROM agent_reader';
    EXECUTE 'REVOKE ALL ON ALL TABLES IN SCHEMA vertex FROM agent_reader';
  END IF;
END
$$;

-- ── 3. Schéma dédié : la seule surface visible par l'agent ───────────
CREATE SCHEMA IF NOT EXISTS agent_ro;
GRANT USAGE ON SCHEMA agent_ro TO agent_reader;

-- Les vues filtrent sur le workspace de la session. Elles s'exécutent avec
-- les droits de leur PROPRIÉTAIRE (vues « definer ») : c'est indispensable,
-- `agent_reader` n'ayant aucun droit sur les tables de base, une vue
-- `security_invoker` lui serait illisible (permission denied — constaté au
-- smoke test). L'isolation est portée par le WHERE, fail-closed ; le
-- `security_barrier` empêche une fonction fuyante de lire des lignes avant
-- le filtre. `security_invoker` ne redevient pertinent qu'à l'étape 2,
-- quand les politiques RLS existeront sur les tables de base.
-- NOTE : `app.workspace_id` est positionné par transaction côté Python via
--   SELECT set_config('app.workspace_id', :workspace_id, true)
-- (`SET LOCAL` n'accepte pas de paramètre lié — set_config, si.)
-- Sans valeur positionnée, `current_setting(..., true)` rend NULL et les
-- vues ne rendent AUCUNE ligne : fail-closed, jamais « toutes les lignes ».

CREATE OR REPLACE VIEW agent_ro.v_workspace WITH (security_barrier = true) AS
  SELECT w.id, w.name, w.created_at, w.updated_at, w.video_credits_extra
  FROM public.workspaces w
  WHERE w.id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_agents WITH (security_barrier = true) AS
  SELECT a.id, a.name, a.type, a.welcome_message, a.updated_at
  FROM public.custom_agents a
  WHERE a.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_documents WITH (security_barrier = true) AS
  SELECT d.id, d.type, d.name, d.description, d.url, d.is_in_brain, d.updated_at
  FROM public.workspace_documents d
  WHERE d.workspace_id = current_setting('app.workspace_id', true)::uuid;

-- `meetings` arrive avec la migration Elisa Réunions, pas encore passée
-- partout. Une table absente ferait échouer TOUT le script (une seule
-- transaction) : la vue n'est créée que si la table existe. Relancer le
-- script après la migration crée la vue — il est idempotent de bout en bout.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'meetings') THEN
    EXECUTE $view$
      CREATE OR REPLACE VIEW agent_ro.v_meetings WITH (security_barrier = true) AS
        SELECT m.id, m.title, m.provider, m.status, m.started_at, m.ended_at,
               m.duration_seconds, m.language, m.created_at
        FROM public.meetings m
        WHERE m.workspace_id = current_setting('app.workspace_id', true)::uuid
    $view$;
  END IF;
END
$$;

CREATE OR REPLACE VIEW agent_ro.v_automations WITH (security_barrier = true) AS
  SELECT au.id, au.provider, au.account_name, au.automation_name, au.status
  FROM public.automations au
  WHERE au.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_campaigns WITH (security_barrier = true) AS
  SELECT c.id, c.type, c.created_at, c.updated_at
  FROM public.campaigns c
  WHERE c.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_media WITH (security_barrier = true) AS
  SELECT m.id, m.type, m.status, m.is_shared_with_workspace, m.created_at
  FROM public.media m
  WHERE m.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_seo_reports WITH (security_barrier = true) AS
  SELECT s.id, s.url_analyzed, s.created_at, s.error_message
  FROM public.seo_reports s
  WHERE s.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_notifications WITH (security_barrier = true) AS
  SELECT n.id, n.type, n.title, n.status, n.created_at, n.read_at
  FROM public.notifications n
  WHERE n.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_products WITH (security_barrier = true) AS
  SELECT p.id, p.name, p.description, p.source_url, p.is_active, p.created_at
  FROM public.product_catalog p
  WHERE p.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_personas WITH (security_barrier = true) AS
  SELECT mp.id, mp.name, mp.description, mp.absolute_desire, mp.created_at
  FROM public.marketing_personas mp
  WHERE mp.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_brand WITH (security_barrier = true) AS
  SELECT b.brand_name, b.website_url, b.emoji_usage, b.updated_at
  FROM public.brand_identity b
  WHERE b.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_missions WITH (security_barrier = true) AS
  SELECT mi.id, mi.key, mi.title, mi.description, mi.source, mi.expires_at, mi.created_at
  FROM public.mission_definitions mi
  WHERE mi.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_social_workflows WITH (security_barrier = true) AS
  SELECT sw.id, sw.platform, sw.created_at, sw.updated_at
  FROM public.social_workflows sw
  WHERE sw.workspace_id = current_setting('app.workspace_id', true)::uuid;

CREATE OR REPLACE VIEW agent_ro.v_agent_notifications WITH (security_barrier = true) AS
  SELECT cn.id, cn.notification_type, cn.updated_at
  FROM public.custom_agent_notifications cn
  WHERE cn.workspace_id = current_setting('app.workspace_id', true)::uuid;

-- Prospects : volume uniquement, jamais les coordonnées (PII de tiers).
CREATE OR REPLACE VIEW agent_ro.v_leads_count WITH (security_barrier = true) AS
  SELECT count(*) AS total
  FROM public.leads l
  WHERE l.workspace_id = current_setting('app.workspace_id', true)::uuid;

-- Intégrations : nom du service et fraîcheur, jamais les jetons.
-- `provider` est un enum ProviderType d'un côté, un varchar de l'autre :
-- l'UNION exige un type commun, tout passe en text.
CREATE OR REPLACE VIEW agent_ro.v_integrations WITH (security_barrier = true) AS
  SELECT o.provider::text AS provider, o.display_name, o.expires_at, o.updated_at,
         'oauth' AS source
  FROM public.oauth_tokens o
  WHERE o.workspace_id = current_setting('app.workspace_id', true)::uuid
  UNION ALL
  SELECT pc.app::text AS provider, pc.display_name, NULL::timestamptz AS expires_at,
         pc.updated_at, 'pipedream' AS source
  FROM public.pipedream_connections pc
  WHERE pc.workspace_id = current_setting('app.workspace_id', true)::uuid;

GRANT SELECT ON ALL TABLES IN SCHEMA agent_ro TO agent_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA agent_ro GRANT SELECT ON TABLES TO agent_reader;


-- =====================================================================
-- ÉTAPE SUIVANTE — RLS sur les tables de base (défense supplémentaire)
-- =====================================================================
-- Volontairement SÉPARÉE : `FORCE ROW LEVEL SECURITY` s'applique aussi au
-- propriétaire des tables. À valider sur un dump AVANT la prod, en
-- vérifiant que les rôles applicatifs (saas, api-agent) ne sont pas
-- soumis à la policy ou disposent de leur propre policy permissive.
--
-- Modèle, à décommenter table par table après validation :
--
--   ALTER TABLE public.custom_agents ENABLE ROW LEVEL SECURITY;
--   CREATE POLICY agent_ro_ws ON public.custom_agents
--     FOR SELECT TO agent_reader
--     USING (workspace_id = current_setting('app.workspace_id', true)::uuid);
--
-- Variante pour `workspaces` (la colonne d'ancrage est `id`) :
--
--   CREATE POLICY agent_ro_ws ON public.workspaces
--     FOR SELECT TO agent_reader
--     USING (id = current_setting('app.workspace_id', true)::uuid);
-- =====================================================================
