# Série d'articles d'aide « Lily — Téléphonie » (8 articles) — relecture CTO

**Destination après validation** : `api-agent/ai/support_messages/articles/` (la base du chat support Margot) — les numéros 39-46 suivent le dernier article existant (38). Dépôt tel quel + ajout à l'index des articles.

**Provenance des faits** : exclusivement le code des branches `origin/v3` (saas) et `v3-dev` (api-agent) — onglets du hub Téléphonie (`hub-config.ts`), modèles `Lily*` (`schema.prisma`), barèmes **actés** de `shared/credits.ts` (0,29 crédit/min — 0,24 Pro, débit à la seconde, non-décroché = 0 ; 0,02/message widget ; 0,08/segment + 0,03 par SMS), plafond budget + alerte email (`sendCreditBudgetLimitEmail`), kill-switch `credits_locked`, balises expressives (commits v3-dev, plafond 15).

**⚠️ À confirmer avant embarquement** :
1. Disponibilité de Lily **par plan** (aucun gating par plan trouvé dans le code — si un plan ne l'a pas, l'article 39 doit le dire) ;
2. Les libellés définitifs des onglets si l'UI bouge d'ici le merge v3 ;
3. Les liens croisés `https://help.agentova.ai/articles/…` supposent les slugs ci-dessous — à ajuster si la numérotation change.

| # | Fichier | Sujet |
|---|---|---|
| 39 | `39-lily-decouvrir-telephonie.md` | Vue d'ensemble : qui est Lily, ce qu'elle fait |
| 40 | `40-lily-numeros-telephone.md` | Numéros : fourni, Twilio perso, renvoi personnel |
| 41 | `41-lily-personnaliser-voix.md` | Voix, test vocal, expressivité, connaissances |
| 42 | `42-lily-campagnes-appels.md` | Campagnes d'appels sortants |
| 43 | `43-lily-envoyer-sms.md` | SMS pendant et après les appels |
| 44 | `44-lily-widget-site-web.md` | Le widget de discussion écrit |
| 45 | `45-lily-tarifs-credits.md` | Coûts, plafond budget, crédits épuisés |
| 46 | `46-lily-suivre-activite.md` | Conversations, campagnes, résumé d'activités |
