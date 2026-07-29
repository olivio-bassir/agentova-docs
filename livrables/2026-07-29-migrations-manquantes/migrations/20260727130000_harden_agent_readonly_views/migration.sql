-- Migration reconstruite : durcissement des vues agent_ro (spec smoke test 26-27/07).
-- Constat du smoke test : agent_reader n'a AUCUN droit sur les tables de base,
-- une vue security_invoker lui est donc illisible (permission denied). Les vues
-- doivent etre DEFINER + security_barrier ; l'isolation est portee par le WHERE
-- (fail-closed via current_setting('app.workspace_id', true)).
-- Idempotent : re-applique security_barrier sur toutes les vues du schema agent_ro
-- et re-verrouille les acces directs aux schemas applicatifs.

DO $$
DECLARE
  v record;
BEGIN
  FOR v IN
    SELECT schemaname, viewname FROM pg_views WHERE schemaname = 'agent_ro'
  LOOP
    EXECUTE format('ALTER VIEW %I.%I SET (security_barrier = true)', v.schemaname, v.viewname);
    EXECUTE format('ALTER VIEW %I.%I RESET (security_invoker)', v.schemaname, v.viewname);
  END LOOP;
END
$$;

REVOKE ALL ON SCHEMA public FROM agent_reader;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM agent_reader;
GRANT USAGE ON SCHEMA agent_ro TO agent_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA agent_ro TO agent_reader;
