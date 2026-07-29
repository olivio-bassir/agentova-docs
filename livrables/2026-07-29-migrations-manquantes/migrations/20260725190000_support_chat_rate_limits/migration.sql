-- Plafond d'usage du chat d'assistance, par utilisateur et par heure.
--
-- Le chat déclenche des appels à un modèle facturé. Sans plafond, un compte
-- qui boucle génère des dizaines de milliers d'appels par jour. Le compteur
-- vit en base et non en mémoire du process : le service tourne sur plusieurs
-- instances Cloud Run, et un compteur local accorderait N fois la limite.
CREATE TABLE "support_chat_rate_limits" (
    "user_id" VARCHAR(128) NOT NULL,
    "window_start" TIMESTAMPTZ(6) NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_chat_rate_limits_pkey" PRIMARY KEY ("user_id")
);

-- Sert la purge des fenêtres périmées (les lignes sont réutilisées, mais un
-- utilisateur qui ne revient jamais laisserait la sienne derrière lui).
CREATE INDEX "support_chat_rate_limits_window_start_idx"
    ON "support_chat_rate_limits"("window_start");
