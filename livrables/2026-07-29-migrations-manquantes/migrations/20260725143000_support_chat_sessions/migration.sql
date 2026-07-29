-- Conversations du chat support (agent Margot, service api-agent).
-- L'historique passe de la mémoire du process à la base : le service tourne
-- sur plusieurs instances Cloud Run, donc deux messages d'une même
-- conversation n'atterrissent pas forcément sur la même instance.
CREATE TABLE "support_chat_sessions" (
    "id" UUID NOT NULL,
    "workspace_id" UUID NOT NULL,
    "messages" JSONB NOT NULL DEFAULT '[]',
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_chat_sessions_pkey" PRIMARY KEY ("id")
);

-- Lecture d'une session : toujours filtrée par workspace (isolation).
CREATE INDEX "support_chat_sessions_workspace_id_idx"
    ON "support_chat_sessions"("workspace_id");

-- Purge des sessions expirées (job planifié) : évite un scan complet.
CREATE INDEX "support_chat_sessions_expires_at_idx"
    ON "support_chat_sessions"("expires_at");

-- Suppression d'un workspace = suppression de ses conversations.
ALTER TABLE "support_chat_sessions"
    ADD CONSTRAINT "support_chat_sessions_workspace_id_fkey"
    FOREIGN KEY ("workspace_id") REFERENCES "workspaces"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
