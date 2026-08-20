# Triage erreurs production — 17-18 août 2026

> Balayage complet post-déploiement (prod saas `b4c8f538c`, deploy du 17/08 17:33) :
> Sentry (org `agentovaai`, fenêtre 17/08 06:00 → 18/08 08:50 Paris) + Cloud Logging GCP (projet `agentova-ai`).
> 32 issues Sentry analysées avec cause racine vérifiée dans le code au commit de release, statut de correctif croisé avec les branches/PRs des repos.
> Auteur : Olivio Bassir — 2026-08-18.
>
> **🔄 Mise à jour 2026-08-20** : statuts re-vérifiés issue par issue (balayage Sentry 48h + Cloud Logging + état des PRs/déploiements). Une colonne « Statut 20/08 » est ajoutée à chaque table — **aucune entrée n'est supprimée**. Convention : ✅ résolue (fix livré en prod + preuve) · 🟢 éteinte (plus d'events, mais aucun fix codé — peut revenir) · ⚠️ éteinte avec récidive ou cousine · ❌ non résolue.
> Bilan express du 20/08 : **8 résolues** (dont la purge RGPD — premier run fonctionnel depuis le 20/07 dans la nuit du 20/08 : 3 suppressions, 0 échec), 9 éteintes sans fix, 11 non résolues. PRs en attente de merge : [#1399](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1399) (fenêtre de purge : 47/50 candidats de cette nuit étaient des convertis — la fenêtre sature), [#1400](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1400) (secret Intercom core-api).

## Synthèse express

- **1 seule issue a un correctif en cours** : [PR #1364](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1364) (KB fichiers ElevenLabs) — non mergée au moment de l'écriture.
- **3 régressions/lacunes liées au déploiement du 17/08** (téléphonie arrivée en prod pour la première fois).
- **Le pattern transversal n°1** : secrets `defineSecret()` utilisés mais absents du tableau `secrets` des functions — **4 occurrences** (`INTERCOM_IDENTITY_SECRET`, `ELEVENLABS_API_KEY`, `JWT_WORKSPACE_SECRET`, `SERVER_API_AGENT_TOKEN`), dont une qui fait échouer la **purge RGPD chaque nuit depuis le 20/07**.
- Les angles morts hors Sentry (canal d'alertes Slack mort, scraping-api sans projet Sentry, pertes de données silencieuses) sont en annexe.

---

## 📞 Téléphonie (core-api)

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [CORE-API-22](https://agentovaai.sentry.io/issues/141203447/) | Création de connaissances « fichier » → 400 ElevenLabs `invalid_file_type` : le multipart part sans type MIME (`new Blob([...])` sans `type` → `application/octet-stream`). 100 % des KB fichiers échouent depuis le deploy (bug démasqué par le fix du téléchargement GCS). | ⏳ [PR #1364](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1364) ouverte (A. Labsi), validée en local (4 tests + preuve avant/après) — **à merger** | 🔴 Haute | ✅ **RÉSOLUE** — PR #1364 mergée + déployée ; zéro event depuis le 17/08 17:43Z, issue marquée `resolved` dans Sentry |
| [CORE-API-1Y](https://agentovaai.sentry.io/issues/141197974/) | Renvoi vers numéro personnel **suisse** impossible : `purchasePhoneNumberCore` n'attache bundle/adresse réglementaires Twilio que si `countryCode === 'FR'` → 400 Twilio systématique. L'utilisateur réessaie depuis 2 jours. | Rien | 🟠 Moyenne | ⚠️ Éteinte (dernier event 18/08 05:40Z) mais **récidive le 20/08** sous [CORE-API-3G](https://agentovaai.de.sentry.io/issues/141792624) (AddressSid vide) et [3H](https://agentovaai.de.sentry.io/issues/141883511) (« SMS not enabled for region ») — le cas suisse n'est toujours pas couvert |
| [CORE-API-1X](https://agentovaai.sentry.io/issues/141195333/) | Saisie du numéro au format national (`07 81…`) : le modal de création d'agent n'applique pas `normalizeToE164` (contrairement au modal d'ajout de numéro) → la garde serveur throw → l'utilisateur reçoit « Une erreur interne est survenue ». Reproduit en local à l'identique. | Rien | 🟠 Moyenne | ⚠️ Éteinte (18/08 14:38Z, `resolved`) ; cousine apparue le 19/08 : [CORE-API-3D](https://agentovaai.de.sentry.io/issues/141655047) — `+33 3 88…` avec espaces refusé sur `setupPersonalNumberForwarding` (même famille de normalisation, autre endpoint) |
| [CORE-API-1Z](https://agentovaai.sentry.io/issues/141198463/) | Écoute d'un enregistrement inexistant : le 404 ElevenLabs est catché générique → **500 « Erreur serveur »** au lieu d'un « enregistrement indisponible ». Reproduit en local E2E. | Rien | 🟡 Basse | 🟢 Éteinte (zéro event depuis le 17/08) — aucun fix codé, peut réapparaître |
| [CORE-API-28](https://agentovaai.sentry.io/issues/141273711/) | Sync addon numéros non convergé : un client **sans moyen de paiement Stripe** a obtenu un numéro plateforme (renvoi configuré le 18/08 05:53) → `subscription_items.create` rejeté 400 par Stripe, retenté chaque heure. Sous-facturation active (Agentova paie le numéro). Gate `ensurePhoneNumberBillable` ne vérifie pas le moyen de paiement. | Rien | 🟠 Moyenne | ❌ **NON RÉSOLUE** — `regressed`, 48 ev / 39 users sur 48h, retry horaire toujours actif, sous-facturation continue (dernier event 20/08 19:15Z) |
| [CORE-API-29](https://agentovaai.sentry.io/issues/141277023/) | Mismatch facturation addon numéros (`phone_numbers_count=0` vs 1 numéro réel) — détection automatique du même cas que CORE-API-28. | Rien | 🟠 Moyenne | ❌ **NON RÉSOLUE** — jumelle de 28, mêmes volumes (48 ev / 39 u) |

## 📧 IMAP / Email

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [IMAP-SERVER-2](https://agentovaai.sentry.io/issues/122056717/) | Boucle d'échec de connexion IMAP d'un compte client — cause : certificat OVH `ssl0.ovh.net` ne couvrant pas le host vanity du client. ~168 lignes/h en continu. | Rien (action support : corriger le host IMAP) | 🟠 Moyenne | ❌ **NON RÉSOLUE** — 2 019 ev sur 48h (~42/h), boucle intacte au 20/08 19:45Z |
| [IMAP-SERVER-3](https://agentovaai.sentry.io/issues/122568884/) | Même boucle, même compte (2ᵉ signature du même échec). ⚠️ Les logs GCP montrent **un 2ᵉ compte client** dans la même boucle, invisible dans Sentry (dédup). | Rien | 🟠 Moyenne | ❌ **NON RÉSOLUE** — 2 017 ev sur 48h, idem |
| [IMAP-SERVER-5](https://agentovaai.sentry.io/issues/123676785/) | « Abandon après max tentatives » — fin de chaque cycle de 20 essais, relancé toutes les 30 min par le cron de réactivation. | Rien (dégrader les tentatives en `warn`) | 🟡 Basse | ❌ **NON RÉSOLUE** — 191 ev sur 48h (~4/h), inchangé |
| [IMAP-SERVER-4](https://agentovaai.sentry.io/issues/122568887/) | « Erreur non-récupérable — arrêt reconnexion » : environnement de **test** (compte interne), comportement d'abandon propre voulu. | Comportement attendu | ⚪ Bruit | 🟢 Éteinte depuis le 18/08 01:14Z (et comportement voulu de toute façon) |

## 🧹 Crons & secrets non liés (pattern `defineSecret` ×4)

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [CORE-API-24](https://agentovaai.sentry.io/issues/141248897/) | `secretOrPrivateKey must have a value` : `cleanupAnonymousZombies` utilise `JWT_WORKSPACE_SECRET` (et `SERVER_API_AGENT_TOKEN`) sans les déclarer dans `secrets: [...]` → **la purge des corpus RAG / tenants email-mémoire des workspaces supprimés échoue chaque nuit depuis le 20/07** (rétention de données, enjeu RGPD). Purge rejouable après fix (les zombies rebouclent). | Rien | 🔴 Haute | ✅ **RÉSOLUE** — [PR #1381](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1381) (superset `TRIGGER_COMMON_SECRETS` + verrou CI `check-secrets-graph`) mergée le 19/08, en prod via #1398. Dernier échec : nuit du 19/08 ; **nuit du 20/08 01:00Z = premier run fonctionnel depuis le 20/07** (3 workspaces purgés, 0 échec, 0 warning secret). Bémols : étape corpus Weaviate en 500 ×3 (non bloquant, re-tenté) ; la fenêtre de scan sature (47/50 candidats = convertis) → [PR #1399](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1399) (scan 500 / quota 50 + garde `updated_at`) **en attente de merge** |
| [CORE-API-25](https://agentovaai.sentry.io/issues/141253728/) | TLS disconnect vers `api-eu.mixpanel.com` pendant le run du cron usage properties — effet de bord de son **premier run réussi en 30 jours** (OOM réparé par le bump 512 MiB → 1 GiB du 17/08). 9 548 requêtes simultanées sans limitation de concurrence ; le bilan du job affiche `failed=0` à tort. | Rien (batcher la concurrence) | 🟡 Basse | 🟢 Éteinte — runs des 19 et 20/08 silencieux : l'orage était le rattrapage du 1er run post-OOM. Concurrence toujours non batchée → reviendra à gros volume |
| [CORE-API-26](https://agentovaai.sentry.io/issues/141253732/) | `socket hang up` — même run Mixpanel. | Rien | ⚪ Bruit | 🟢 Éteinte (idem 25) |
| [CORE-API-27](https://agentovaai.sentry.io/issues/141254190/) | `connect ETIMEDOUT 34.96.125.79:443` (= Mixpanel EU) — même run. | Rien | ⚪ Bruit | 🟢 Éteinte (idem 25) |

## 📣 Publication sociale

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [CORE-API-13](https://agentovaai.sentry.io/issues/128858931/) | Post LinkedIn programmé **sans texte** : publié sur Instagram/Facebook, rejeté par la garde métier LinkedIn (correcte) — mais rien ne bloque à la programmation côté UI, et le cas géré part en `logger.error`. A encore perdu un post le 17/08 à 22:01. | Rien | 🟡 Basse | ❌ **NON RÉSOLUE** — encore 1 post perdu le 19/08 13:01Z |

## 🔍 SEO & widget public

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [CORE-API-21](https://agentovaai.sentry.io/issues/141202627/) | PDF SEOptimer en 403 : les liens sont **vivants** depuis une IP résidentielle (200, PDF complet) mais bloqués pour nos IP datacenter GCP → retry en boucle sans backoff (310 tentatives le 17/08). Un 2ᵉ workspace touché dans la nuit. Ne PAS marquer les 403 définitifs (rapports récupérables). | Rien | 🟠 Moyenne | ❌ **NON RÉSOLUE** — 247 ev / 10 workspaces sur 48h (~5/h), boucle de retry sans backoff toujours en place |
| [CORE-API-20](https://agentovaai.sentry.io/issues/141201851/) | Widget public appelé avec un id invalide (`frontpage`, storefront Shopify) : 404 propre au visiteur, mais log passé de `console.error` à `logger.error` au deploy du 17/08 → bruit Sentry. + flood de 404 de 2 UUID d'agents supprimés (widget mort chez un client). | Rien | 🟡 Basse | ❌ **NON RÉSOLUE** (et re-qualifiée 🔴 : chatbot invisible + leads perdus chez les clients touchés — une résiliation le 17/08). 26 ev / 14 u sur 48h. Les 2 UUID supprimés ont cessé ; nouveaux motifs : `srcdoc` ×8 (iframes) + slugs de pages (immobilier Cannes/Mandelieu, e-commerce detailing). Cause racine identifiée dans `chat-widget/src/index.ts` (fallback sur le dernier segment d'URL quand `data-bot-id` illisible) ; **correctif prêt en local** (lecture robuste + validation UUID), en attente de GO |

## 🤖 Agents / chat

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [AGENT-API-Y7](https://agentovaai.sentry.io/issues/121976279/) / [Y8](https://agentovaai.sentry.io/issues/121976282/) / [Y9](https://agentovaai.sentry.io/issues/121976284/) | « Session not found » (3 signatures, même incident) : le widget envoie un `session_id` purgé/expiré, le serveur lève une exception au lieu de recréer la session ou renvoyer un code propre → chat bloqué jusqu'au refresh. Récurrent (15:08 → 21:04 le 17/08). | Rien | 🟠 Moyenne | 🟢 Éteintes (dernier event 17/08 19:04Z) — aucun fix codé ; NB : le feedback BISIAU MEDICAL du 19/08 (« pas de retour du chatbot ») a la même signature UX, à surveiller |
| [AGENT-API-15Z](https://agentovaai.sentry.io/issues/141199333/) | OpenAI émet une erreur SSE en toute fin de stream (réponse pourtant générée) → `MidStreamFallbackError` non rattrapé, réponse perdue. Incident fournisseur ponctuel (2 events). | Rien (durcissement optionnel) | 🟡 Basse | 🟢 Éteinte — incident fournisseur clos, zéro event depuis le 17/08 |
| [AGENT-API-160](https://agentovaai.sentry.io/issues/141276612/) | « Blocking Operation » dans `enrich_brand_dna_complete` (event-loop bloquée). | Rien | 🟡 Basse | 🟢 Éteinte (dernier 18/08 06:12Z) — mais nouveau bug distinct dans le même flux le 19/08 : [AGENT-API-16B](https://agentovaai.de.sentry.io/issues/141608881) `'str' object does not support item assignment` |
| [V2-AGENT-API-1](https://agentovaai.sentry.io/issues/141191058/) | Message chat > 100 000 caractères rejeté par le schéma (limite légitime) — mais **échec 100 % silencieux côté client** : pas de toast, pas de compteur ; l'utilisateur a réessayé 7 fois. | Rien | 🟡 Basse | ❌ **NON RÉSOLUE** — le même utilisateur a réessayé 10× le 19/08 matin, toujours zéro feedback UI ; silencieux le 20/08 |

## 🖥️ Client (front Next.js)

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [CLIENT-AGENTOVA-AI-K6](https://agentovaai.sentry.io/issues/121595094/) | `[CLAIM_MISSED]` : signup arrivé du **flux paiement** sans customer Stripe anonyme à rattacher (2 cas dans la nuit) → un paiement anonyme peut être orphelin. Vérification manuelle Stripe requise. | Rien (vérif Stripe côté CTO) | 🟠 Moyenne | ❌ **NON RÉSOLUE** — 3 nouveaux cas le 20/08 (09:00 et 14:23Z) ; le feedback Menuiserietradition du 18/08 (« offre de bienvenue : on me demande de mettre à jour mon mode de règlement pourtant renseigné ») y est vraisemblablement lié — vérif Stripe manuelle à refaire |
| [CLIENT-AGENTOVA-AI-113](https://agentovaai.sentry.io/issues/141248743/) | `Failed to fetch` core-api à 02:58 : coupure réseau côté client (~10 fetchs simultanés vers 2 domaines en échec, zéro 5xx serveur). | Rien à faire | ⚪ Bruit | 🟢 Éteinte — coupure ponctuelle confirmée (dernier event 18/08 00:58Z) |
| [CLIENT-AGENTOVA-AI-9E](https://agentovaai.sentry.io/issues/101637231/) | Timeout Firebase Auth (10 s) sur `/login` — 1 utilisateur, réseau lent probable. | Rien (surveillance) | 🟡 Basse | 🟢 Silencieuse sur la fenêtre 19-20/08 |
| [CLIENT-AGENTOVA-AI-E9](https://agentovaai.sentry.io/issues/117274326/) | `<unknown>` = MediaError du player Wistia (vidéo onboarding) sur iPad — tiers/WebKit, court depuis mai. | Rien (filtre `beforeSend`) | 🟡 Basse | ✅ **TRAITÉE deux fois** — filtre `beforeSend` MediaError scopé livré ([PR #1383](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1383), prod 19/08) **et** la vidéo Wistia morte de l'onboarding repointée ([PR #1412](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1412), prod 20/08 soir). Zéro event depuis le 17/08 |

## 🔌 Websocket

| Issue | Quoi | Fix | Gravité | Statut 20/08 |
|---|---|---|---|---|
| [WEBSOCKET-SERVER-1](https://agentovaai.sentry.io/issues/114720172/) / [2](https://agentovaai.sentry.io/issues/114720176/) | Reconnexion avec token Firebase périmé — bruit récurrent depuis avril (~6 500 events chacune) qui noie le signal. | Rien (dégrader en `warn`/filtrer) | ⚪ Bruit | ✅ **RÉSOLUE** — fix livré (PR websocket #36 → #37, prod 19/08 16:36Z) : codes expiré/révoqué dégradés en `warn`. 3 ev résiduels le 19/08 matin (avant deploy), **0 le 20/08** ; 2 seuls warns « token invalide » sur 24h vs ~6 500 historique |
| [WEBSOCKET-SERVER-C](https://agentovaai.sentry.io/issues/126869125/) | Warning de dépréciation SSL du driver `pg` promu en event Sentry au démarrage du conteneur. | Rien (filtrer) | ⚪ Bruit | ✅ **RÉSOLUE** — extraction `sslmode` hors de la chaîne pg (même PR #36/#37) ; les 2 ev du 19/08 09:18Z sont des redémarrages **antérieurs** au deploy de 16:36Z, zéro depuis |

## 🩺 Moniteurs internes (résolues)

| Issue | Quoi | Statut 20/08 |
|---|---|---|
| [CLIENT-AGENTOVA-AI-E8](https://agentovaai.sentry.io/issues/117262019/) | `#dev-report-user-crash-client` — moniteur interne, resolved | ⚠️ Re-déclenché ×3 (dernier 20/08 15:19Z) — cohérent avec les erreurs de chunks périmés du deploy front du 20/08 midi |
| [AGENT-API-E2](https://agentovaai.sentry.io/issues/93649874/) | `#dev-report-failure-rate-api` — moniteur interne, resolved | ⚠️ Re-déclenché ×8 (dernier 20/08 03:28Z) |

---

## Annexe — angles morts hors Sentry (balayage Cloud Logging, projet `agentova-ai`)

Priorisés par impact :

1. **Canal d'alertes Slack `#error-gcp` mort depuis ≥ 1 mois** (« Slack account is inactive », 26-42 échecs/jour) — seul canal des 3 policies d'alerte GCP : **toutes les alertes infra partent dans le vide**, y compris celles des incidents ci-dessous. → **20/08 : non revérifié lors de ce passage — à re-contrôler.**
2. **scraping-api n'a aucun projet Sentry** (le SDK est embarqué, aucun destinataire) : crédit Jina AI épuisé 3 h le 17/08 (503 clients sur la recherche de pages Facebook, fallback scraping mort, aucune alerte de solde) + régression `AttributeError` du deploy du matin (5 h, amortie par le fallback Gemini, corrigée à 16:48). → **20/08 : ❌ toujours vrai** — les 503 de `/verify` des 19-20/08 ne sont visibles que par ricochet ([CORE-API-3B](https://agentovaai.de.sentry.io/issues/141636602), [AGENT-API-16E](https://agentovaai.de.sentry.io/issues/141636595)).
3. **Pertes de données silencieuses** : 64 emails « indexation Weaviate définitivement perdue » pendant le storm multi-tenancy du 17/08 (11:19→12:22, deploy api-agent rev 00227) — réindexation à faire ; mémoires graphe Neo4j perdues pendant ~11 h de read-only la nuit du 16 au 17 ; 10 workspaces sans tenant `workspacememoryworkbook_prod` (mémoire muette, retour vide best-effort). → **20/08 : ❌ toujours actif** — Neo4j repasse en read-only **par intermittence** ([AGENT-API-10Q](https://agentovaai.de.sentry.io/issues/127858941), 8 ev du 19/08 07:16 au 20/08 16:05) ; séquelles Weaviate `emailmessages_prod` encore visibles ([CORE-API-2H](https://agentovaai.de.sentry.io/issues/141326228)).
4. **Purge RGPD en échec depuis le 20/07** (cf. CORE-API-24) — les corpus/tenants des workspaces supprimés sont conservés. → **20/08 : ✅ RÉSOLU** — premier run fonctionnel la nuit du 20/08 (3 purges, 0 échec) ; voir la ligne CORE-API-24 pour les réserves (fenêtre saturée → PR #1399, corpus Weaviate en 500).
5. **Sécurité** : le JWT `X-Workspace-Token` est loggé **en clair** par Caddy (node v2-agent-api) et le token en query string par websocket-server ; SSH du node v2-agent-api exposé à Internet (brute-force actif, pas d'intrusion constatée) ; 3 fonctions Cloud Run répondent sans blocage IAM au scan externe (`executescheduledpost`, `processdelayeddiscussionreply`, `claimanonymousonsignup`). → **20/08 : ❌ toujours vrai pour websocket** — token JWT complet (décodable, email client visible) revérifié en clair dans `requestUrl` le 20/08 17:04Z.
6. **CD front/back inversée le 17/08 au matin** : 22 min de 404 en masse (280 requêtes, ~12 routes) — le client appelait des routes livrées seulement par le deploy backend de 12:23. → **20/08 : événement clos, mais récidive de la même famille** — chunks front périmés après le deploy de midi le 20/08 ([CLIENT-11C](https://agentovaai.de.sentry.io/issues/141841426)/[11D](https://agentovaai.de.sentry.io/issues/141853814)/[11E](https://agentovaai.de.sentry.io/issues/141853835), 3 signatures en 50 min).
7. **`reconcilecreditledger` sans `ELEVENLABS_API_KEY`** (11 warnings/run horaire) : les verrous de crédits widget ne sont jamais poussés côté ElevenLabs. Une rotation de `ELEVENLABS_WEBHOOK_SECRET` a par ailleurs été refusée par IAM (permission manquante du membre qui l'a tentée). → **20/08 : ✅ RÉSOLU** — 0 warning depuis le deploy du 19/08 16:39Z (293 avant sur la seule journée du 19/08), via PR #1381. ⚠️ Signal neuf à suivre : 2 × **403** sur le webhook `elevenlabs/personalization` le 20/08 (15:57 et 16:06Z).
8. **Deux crons Firebase étaient morts par OOM** : `syncworkspaceusageproperties` (30 j sans succès) — réparé par le bump mémoire du 17/08 ; `monitoroutlooksubscriptionshealth` (256 MiB, 5 échecs consécutifs) — **toujours cassé**, la santé des webhooks Outlook n'est pas surveillée. → **20/08 : non revérifié pour Outlook — à re-contrôler.**
9. **Clients silencieusement pénalisés** : Page Facebook bloquée par checkpoint d'identité Meta (1 post perdu/jour depuis le 14/08) ; token LinkedIn perso expiré (3 posts perdus en 3 jours) ; widget public mort chez un client (764 × 404 de vrais visiteurs) ; 6 × 401 sur `/compressVideo` (appelant interne mal authentifié). → **20/08 : ❌ checkpoint Meta continue** ([CORE-API-4](https://agentovaai.de.sentry.io/issues/126091793)/[30](https://agentovaai.de.sentry.io/issues/141422868), posts perdus les 19 et 20/08) ; **❌ LinkedIn 401 continue** ([CORE-API-1R](https://agentovaai.de.sentry.io/issues/135770907)/[2A](https://agentovaai.de.sentry.io/issues/141284038), 9 ev) ; le flood des 2 UUID supprimés a cessé (remplacé par les slugs/srcdoc, cf. CORE-API-20).
10. **Pipeline** : 2 builds Cloud Build en échec le 17/08 (PAT GitHub Packages expiré/révoqué sur `@agentova-ai-company/auth-server`) — résolu, mais rotation non planifiée.

### Recommandation structurelle n°1

Un **check CI** qui compare, pour chaque entrypoint Firebase/Cloud Run, les secrets réellement consommés (`defineSecret().value()`) au tableau `secrets: [...]` déclaré — le pattern « secret non lié » a causé 4 défaillances distinctes dont une fuite de rétention RGPD d'un mois. Second chantier : poser `SENTRY_RELEASE` sur les functions (elles remontent en `release: local@…`, mal groupées).

→ **20/08 : ✅ FAIT pour le check CI** — livré dans la PR #1381 : `server/scripts/check-secrets-graph.mjs` (graphe d'imports à granularité symbole, 0/13 crons en écart contre 130 avant) + verrou `secrets-trigger-graph.test.ts` qui casse la CI si un futur trigger sort du superset. Reste ouvert : `SENTRY_RELEASE` (les crons remontent toujours en `local@…`), et le pendant **tier Cloud Run** du même pattern — `INTERCOM_IDENTITY_SECRET` non monté sur le service core-api (~295 warnings/24h, a survécu aux 3 deploys du 20/08) → [PR #1400](https://github.com/Agentova-ai-Company/saas-agentova-ai/pull/1400) en attente de merge.
