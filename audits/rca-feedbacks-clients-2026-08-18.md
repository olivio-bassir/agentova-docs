# Rapport RCA — Feedbacks clients Sentry (2026-08-18)

**Périmètre** : 91 feedbacks non résolus (90 j) du projet `client-agentova-ai`, regroupés en 12 familles.
**Méthode** : env prod tiré à jour (worktrees `wt-prod-saas` @ `b4c8f538c`, `wt-prod-api-agent` @ `5523ffe`) ; 12 enquêteurs RCA en parallèle + 11 contre-experts adversariaux (workflow 23 agents, ~1 100 outils, harnais mocks exécutés) ; chaque preuve = fichier:ligne du worktree prod, commit daté ou requête Sentry vérifiée.
**Résultat global** : les 12 causes racines ont survécu à la contre-attaque (`rc_survit=true` partout) ; 9 fixes sur 11 ont été durcis par les contre-experts (failles réelles trouvées et corrigées dans la version finale). **Aucun fix n'a encore été pushé** — les PRs partiront après validation.

**Voir aussi** : [triage-erreurs-prod-2026-08-17-18.md](./triage-erreurs-prod-2026-08-17-18.md) — le triage des erreurs Sentry de la même fenêtre (32 issues, dont le bug systémique `defineSecret` cité en M1).

---

## 1. Les trois maladies systémiques (la « maladie », pas les symptômes)

### M1 — Échecs silencieux généralisés (l'angle mort)
La grande majorité des familles partage le même défaut structurel : **l'erreur meurt sans témoin**, ni pour l'utilisateur ni pour Sentry.
- Client : `failStream`/`onError` = `console.error` seulement ; « Une erreur est survenue » générique (UserBubble) ; erreurs pré-stream V2 à code ≠ 429 **100 % silencieuses** (branche `removeTurn`) ; `InputMicrophone` n'affiche jamais `userError` ; no-op muets (`if (!file) return;` image-gen) ; player Wistia sans handler d'erreur.
- Serveur : runtime V2 (`ClaudeAgentRuntime`, 5 521 lignes) = **zéro** `captureException` ; drops de pièces jointes en `logger.warning` (3 chemins distincts) ; pattern `defineSecret` non lié (4 cas connus) ; 403 SEOptimer retenté à l'infini.
- **Aggravant majeur découvert : blackout Sentry org du 29/07 au 17/08** (quota épuisé) — zéro erreur ingérée sur les 4 projets pendant 3 semaines. Toute conclusion « pas d'erreur Sentry » sur cette fenêtre est non-informative.
- Garde-fous à instituer : règle « zéro échec muet » (toute erreur terminale ⇒ capture Sentry + message utilisateur actionnable), alerte de consommation de quota Sentry, check CI defineSecret (déjà recommandé au CTO).

### M2 — Contrats et champs introduits sans migration ni filet
- `agent_channel` introduit sans backfill → tous les agents pré-17/08 tombent dans la branche par défaut fausse (famille A).
- Route `/run_sse/employee_agent` supprimée d'api-agent (en prod le 17/08 13:07) alors que le client prod l'appelle **encore** : fils legacy, `meetingService.ts:525`, `SeoAnalysisView` → 404 déterministes (familles B/E/J).
- ID Wistia remplacé par un ID inexistant (29/05) sans validation → onboarding mort 11 semaines (famille O).
- Divergence `instagram` vs `instagram_page` (avril) → builder d'automatisations sans issue (famille I).
- Scopes OAuth custom (sans `r_basicprofile`) × outils registry partner-gated → LinkedIn 403 par construction (famille L).
- Garde-fous : règle « champ discriminant ⇒ backfill dans la même PR », test de contrat CI routes client↔api-agent (2 listes : atteignables / legacy-tolérées), check CI IDs Wistia, check CI slugs MCP Pipedream.

### M3 — Process de release inter-repos
Le 17/08 : api-agent casse à 13:07 (merge d'un commit portant l'avertissement **« A NE PAS MERGER avant que V2 ait pris le relais en production »**), le gate client n'arrive qu'à 17:33 → 4h30 de casse dure pour tous. 8 releases dev→main le même jour. Le contrat de release inter-repos (ordre, gates, avertissements bloquants) est la faille de fond.

---

## 2. Vue d'ensemble des 12 familles

| Famille | Verdict | Cause racine (1 ligne) | Confiance finale | Priorité |
|---|---|---|---|---|
| A — Historique + résumé vides (17/08) | Régression release | `agent_channel` sans backfill → défaut EMAIL faux pour tout chatbot pré-17/08 → onglet Site Web jamais injecté ; stats email-only → `null` | 90 % | **P0** |
| E — Chat « réessayer » (chronique) | Bug architecture | Tous les modes d'échec du runtime V2 écrasés en un écran générique, zéro télémétrie aux deux bouts ; + **404 actif sur fils legacy** (route supprimée 17/08) | 80 % | **P0/P1** |
| O — Vidéo onboarding morte | Régression (29/05 !) | ID Wistia `9nd1m8ucjilk39d` inexistant ; gate fail-closed sans issue → mission 1 incomplétable → **toutes les missions LOCKED** pour les self-serve | 96 % | **P0** |
| B — SEO en échec | Régression + produit | 17/08 : producteur supprimé (api-agent) avant le gate client (4h30 de casse) ; juillet : crawler bloqué par le site, motif jamais affiché ; résidu : boucle 403 PDF | 93 % | **P0** (résidus) |
| F — Fichiers invisibles Cerveau IA | Bug jamais branché | Liste plafonnée à la page 1 (20 docs) : pagination serveur + hook existants, jamais consommés par la page ; recherche/tri/favoris = filtres client sur 20 | 95 % | P1 |
| G — « Première plateforme » | Bug (06/05) | Événement `PROVIDER_CONNECTED` émis avant l'abonnement du bus (ordre des effets React) et jamais réconcilié avec l'état réel → task jamais complétée depuis 3 mois | 90 % | P1 |
| I — Automatisations sans déclencheurs | Bug entonnoir (avril) | Onboarding Arthur connecte `instagram` (personnel) que le builder ne reconnaît pas (`instagram_page` requis) → boucle silencieuse builder↔Cerveau IA | 85 % | P2 |
| L — LinkedIn 403 | Bug par construction (mai) | Outils registry Pipedream appellent `/rest/me` (partner-gated) avec un client OAuth sans `r_basicprofile` → 403 éternel, « reconnectez-vous » ne peut jamais réussir | 92 % | P2 |
| J — Pièces jointes | Bugs multiples V1 | Crash déterministe par session (`pending_delta=None` ADK), 3 chemins de drop silencieux, + 404 legacy depuis le 17/08 ; carrousel = produit manquant | 88 % | P2 |
| N — Micro / transcription | Bug + limite modèle | Safari ≤18.3 : `webm/opus` exigé en dur → échec muet ; « finnois » : hallucination STT sur capture faible, aucun garde (énergie, prompt, logprobs) | 85 % | P2 |
| H — Image-gen figée | Bug état absorbant | Outil actif survivant à la disparition de sa source → input+outils désactivés + clic « Demander » no-op muet ; issue (croix du chip) non découvrable | 72 % | P2 |
| T — Triage transverse (27 items) | Mixte | Billing/Stripe, WhatsApp coexistence, Trustpilot, qualité agent, ops CSM — 4 lots d'actions | 70 % | lots |

---

## 3. Détail par famille (cause démontrée → fix final durci)

### A — Historique conversations + résumé d'activité vides depuis le 17/08 (CLIENT-112/111/110) — P0
- **Commit fautif** : `302acf42b` (refonte mailing : gating `isChatbotAgent`) + `bb5acc34d` (résumé d'activité email-only). Fenêtre `bf132718f..b4c8f538c`.
- **Mécanisme prouvé** : l'onglet « Site Web » n'est injecté que si `resolveAgentChannel()`=CHATBOT ; or `agent_channel` n'existe pour aucun agent pré-17/08 (grep serveur = 0, aucun backfill) et la dérivation legacy retombe sur le défaut EMAIL (un chatbot n'a jamais de ligne `automations`). **Les données sont intactes** (`vertex.sessions` non touché) — c'est l'UI qui ne demande plus. Résumé vide : `getSavAgentDailyStats` ne résout que des comptes email → `stats: null`.
- **Fix final (durci par contre-attaque, harnais 17/17 PASS)** :
  1. `agentChannel.ts` : 3 états — `undefined` tant que la query automations charge (pattern déjà en prod `layout.tsx:826-830`), EMAIL si automation email (tout statut), sinon CHATBOT. Appliquer la garde de chargement aux **5 sites d'appel** (ConversationsView, AgentHomeView, HubIntegrationView, AgentPersonalizationPage, layout).
  2. Backfill serveur versionné (paquet complet) avec croisement **obligatoire** : discussions email historiques ⇒ EMAIL (rattrape les déconnexions pré-03/08) ; sessions `vertex` `child_{ws}_{agent}` ⇒ CHATBOT.
  3. Résumé d'activité : router le canal chatbot vers `getCustomAgentDailyStats` (pipeline prospects existant) au lieu d'un `null` indiscernable d'un jour vide.
  4. Garde-fous : tests d'intégration (legacy sans automations ⇒ onglet web + fetch émis ; email en cours de chargement ⇒ pas d'écriture `?provider=web`), règle « champ discriminant ⇒ backfill même PR ».
- **Reste avant réponse client** (lecture DB prod, read-only) : vérifier que « Road to clean » (CLIENT-112) n'est pas un hybride mail+widget — cas que le modèle binaire ne couvre pas (arbitrage produit si oui). Côté mail, l'historique pré-17/08 ne reviendra pas (bascule Weaviate assumée par la refonte) — à assumer dans la réponse.

### E — « Une erreur est survenue / réessayer » (~20 feedbacks depuis le 09/07) — P0/P1
- **Racine (famille)** : le chat principal tourne sur le runtime V2 (`v2-agent-api`, subprocess `claude`/conversation) depuis ~01/07 ; **chaque mode d'échec** (subprocess mort, saturation RAM — watermark d'éviction à 0, session_busy, 400 zod >100k chars, tours sans timeout → « charge 30 min ») est converti en event générique **sans aucune capture Sentry** (1 seule issue en 90 j pour 100 % du chat), et le client écrase tout en un même écran. Vague 09-14/07 : déploiements coupant les tours (blue-green seulement le 19/07) + pool Safari.
- **Découverte de la contre-attaque (cause active non couverte initialement)** : les routes `/run_sse/employee_agent` et `/rewind/employee_agent` ont été **supprimées** d'api-agent (prod 17/08 11:07) alors que le client prod route encore toute session legacy dessus → **404 déterministe sur chaque envoi dans un fil pré-juillet**, aujourd'hui, en prod. `meetingService.ts:525` et `SeoAnalysisView.tsx:101` appellent aussi cette route en dur. Autre trou démontré au harnais : erreur pré-stream V2 à code ≠ 429 = **échec 100 % silencieux** (probable mécanique des « pas de réponse »).
- **Fix final (4 volets)** :
  1. **Gate des sessions legacy** : bannière « conversation archivée — continuez dans une nouvelle conversation » + création V2 explicite (supprimer le bypass `!forceNewSession` de `useChatOrchestration.ts:1210`, sinon le CTA se 404 lui-même) ; arbitrage CTO sur meetingService/SeoAnalysisView.
  2. **Télémétrie bout en bout** : captures Sentry aux points d'émission d'erreur de `ClaudeAgentRuntime` (+ garde-fou CI « toute émission d'erreur terminale ⇒ capture ») ; côté client, corriger là où ça agit vraiment : `from-v2.ts` (applyError pose l'erreur sur le message AGENT — UserBubble V1 n'est jamais déclenchée en V2) + branche `onError` (rendre visible toute erreur pré-stream), tag `schema_version` pour trancher enfin la distribution V1/V2.
  3. **Rendu différencié** : message + code par type (session_busy/server_busy → « patientez », too_big → « message trop long », etc.), retry supprimé sur les codes déterministes ; limite 100 000 caractères au composer (sémantique UTF-16 identique au zod serveur).
  4. **Ensuite, calibré sur 48-72 h de données** : watchdog de tour serveur + backstop client V2 (aucun timeout aujourd'hui) ; poser `MEMORY_WATERMARK_MB` ≈ 80 % de la RAM (défaut actuel 0 = éviction désactivée, cap théorique 100 sessions × ~0,6 Gio > 48 g).

### O — Vidéo d'onboarding « media not found » → missions bloquées (7+ feedbacks, en réalité ~20 depuis le 01/06) — P0
- **Commit fautif** : `916cdf663` (29/05) remplace l'ID Wistia VSL par `9nd1m8ucjilk39d` — **ID inexistant** (Wistia renvoie `{"error":true}`, vérifié le 18/08 ; l'ancien `7rznzgjj9u` est toujours vivant). Le player n'a aucun handler d'erreur → `ctaReady` jamais vrai → bouton physiquement `disabled` → mission 1 (`isFirstRequired`) incomplétable → **toutes les autres missions LOCKED**. Progression piégée en localStorage. Toujours actif en prod (l'équipe a retiré ce même ID du catalogue Académie le 13/08… sans corriger la config mission).
- **Fix final (3 couches, harnais 11/11 PASS, fix_survit=true à 96 %)** :
  1. Restaurer `7rznzgjj9u` (confirmer avec Samy/marketing si une nouvelle VSL existe — sans bloquer la PR).
  2. **Fail-open** : timeout `onReady` 15 s (condition principale ; le fetch metadata = accélération best-effort, jamais condition unique — CSP/adblockers) → `videoFailed` force `ctaReady=true` + capture Sentry ; `onError` optionnel (hook partagé avec l'Académie) ; reset par step ; ne bypass jamais le gate quiz (prouvé T5).
  3. CI : validation des IDs Wistia de toutes les configs + échec sur ID de longueur ≠ 10 (aurait attrapé ce bug sans réseau).
- Une vidéo marketing ne doit plus **jamais** pouvoir verrouiller le produit.

### B — Analyse SEO (10W/V/X/Y, ZA/ZD) — P0 pour les résidus
- **Deux couches distinctes prouvées** : (a) 17/08 13:07→17:33 : le retrait des employee agents (commit portant « NE PAS MERGER avant relève V2 ») supprime le producteur SEOptimer → le client 200c165 poste sur une route morte → « Une erreur est survenue » ; refermé par le gate #1366. (b) 23-24/07 (ZA/ZD, un seul user) : crawler SEOptimer bloqué par le site du client → statut « Impossible » **sans jamais afficher le motif** pourtant stocké en DB. Le lien Pipedream invalide de ZD = dossier custom OAuth Shopify déjà connu (séparé).
- **Résidu actif** : PDF SEOptimer expirés → 403, or `seoReportService.ts:44` ne marque expiré que sur 404 → **boucle de re-téléchargements** (CORE-API-21 : 28 events/5 h) et cartes « Terminé » sur lien mort.
- **Fix final (harnais 11/11 PASS)** : (1) élargir la branche définitive à **[403, 404, 410]** + statut HTTP dans le message ; (2) afficher le motif sous « Impossible » **avec fallback** pour les cartes STALE sans `error_message` ; (3) purge/garde des chemins clients morts (`/rewind/employee_agent` à `sessionService.ts:283`, fallback V1, meetingService, SeoAnalysisView) ; (4) test de contrat CI routes client↔api-agent en **2 listes** (atteignables / legacy-tolérées — tel que proposé initialement il serait rouge dès le jour 1). Réouverture du producteur = **arbitrage CTO** (le schéma DB est déjà prêt pour un producteur `claude` : migration `20260731140000`).

### F — « Vos Fichiers » n'affiche plus les anciens fichiers (10M/10K/10N) — P1
- **Racine prouvée au chiffre près** : la bibliothèque n'affiche que la **page 1 de 20 documents** — la pagination serveur (curseur sain) et le hook (`fetchNextPage`/`hasNextPage`) existent, mais `page.tsx` ne les consomme pas (jamais branché depuis mars, `git log -S` vide ; 2 modals du même codebase les consomment correctement). Les ~20 listes de prospection ont rempli exactement la page 1. Recherche/tri/favoris = filtres client sur ces 20. **Aucune donnée perdue.**
- **Fix final (durci, harnais 10/10 PASS)** : surface **corrigée** = `page.tsx` + `RecentAdditionsSection` uniquement (ne PAS toucher KnowledgeGridView — les FILE n'y transitent jamais ; l'y brancher déclencherait des fetchs parasites depuis les grilles produits/prospects). Grille : `InfiniteScrollTrigger` réel ; liste : fetch en fin de pagination + total honnête (« totalPages+ ») ; **auto-fetch chaîné (garde `isFetchingNextPage`) dès qu'un critère non chronologique est actif** (recherche, tri par nom, favoris, origine) — sinon ils restent silencieusement faux. Test composant anti-récidive. Complément produit ensuite : recherche serveur + `totalCount`.
- Réponse client possible dès maintenant : fichiers intacts, l'agent voit tout, seul l'affichage est plafonné.

### G — « Connectez votre première plateforme » malgré plusieurs connexions (10Q/10P) — P1
- **Commit fautif** : `95408c25e` (06/05). Le message vient du **widget missions** (task `connect_first_provider`), complétée uniquement par un événement client one-shot `PROVIDER_CONNECTED`… émis dans l'effet de mount d'un **enfant** avant l'abonnement du `MissionProvider` (parent) — bus sans queue ni replay → événement jeté. Sur `/dashboard/onboarding/*`, le provider n'est même **jamais monté** (perte 100 % garantie). Aucune réconciliation serveur avec l'état réel. Donc : toute connexion depuis début mai ne complète jamais la task.
- **Fix final (fix_survit=true, 2 harnais dont un en React 19 réel + heal 8/8 PASS)** : **heal-on-read** dans `getMissionState` (si ≥1 compte connecté → `completeTaskUpsert` avec définition reconstruite — la row peut ne pas exister ; idempotent/concurrent prouvé) → répare rétroactivement tous les workspaces bloqués depuis 3 mois, sans action client. + Replay du bus **avec dédup par type** (16 sites d'emit → N doublons sinon) en garde-fou pour tous les triggers de mount (PAGE_VISITED aussi concerné). Décision documentée : les ghosts Pipedream comptent comme connectés pour cette mission.

### I — Automatisations : aucun déclencheur (10C/10B, YM/YK) — P2
- **Racine** : le builder n'accepte qu'`instagram_page` ; l'onboarding d'Arthur (parcours canonique du hub Acquisition) connecte `instagram` **personnel** → aucune app actionnable, sous-titre muet qui éjecte vers le Cerveau IA où la tuile affiche « Connecté » → boucle sans issue ni erreur (divergence née les 02-04/04).
- **Correction de la contre-attaque (bloquant)** : `instagram` n'est **pas** un vestige — c'est le canal DM de l'agent SALES. Le fix final **AJOUTE** `instagram_page` à la liste d'onboarding (ne remplace pas), avec libellés différenciés (« messages privés » vs « commentaires/automatisations ») ; message explicite dans le builder (« compte personnel ≠ Page Instagram ») + CTA OAuth avec `returnUrl` vers le builder ; garde CI en quantificateur « **au moins un** provider automation-capable » (le « tous » initial rejetterait la liste corrigée — démontré au harnais). Ticket séparé : limite « 1 automatisation/compte » vécue comme un bug par les payants. Réserve : l'écran réellement vu par hanen.benrhouma reste à confirmer (jamais passée par `/automations` d'après Sentry).

### L — LinkedIn 403 `partnerApiMe` (ZX, YW) — P2
- **Racine** : les agents publient via les outils du **registry Pipedream** qui commencent par `GET /rest/me` (ressource partenaire, scope `r_basicprofile`) ; notre client OAuth custom `oa_w4iZYE` (depuis le 01/05) n'a que `openid profile email w_member_social` → 403 par construction, **la reconnexion ne peut jamais réussir** (propriété de l'app, pas du token). Le chemin du Hub Créatif (`/v2/userinfo` + `/v2/ugcPosts`) fonctionne avec ces scopes — les agents utilisent simplement le mauvais chemin. `linkedin_page` côté agents : slug inconnu de Pipedream + account composite → inutilisable aussi.
- **Fix final (durci, harnais 8/8 PASS)** : outil maison `linkedin_publish_*` (réutilise la logique du scheduler, éprouvée en prod) + **blocklist étendue** {linkedin, linkedin_page, linkedin_ads} dans le gating — **des DEUX runtimes** (v2-agent-api ET api-agent v1, encore en prod : exiger la preuve écrite que V2 est seul en prod sinon couvrir v1) ; **ordre contractuel** : core-api d'abord, agent-api ensuite ; taxonomie à **3 branches** (401 Pipedream ≠ 401 LinkedIn ≠ 403 ACCESS_DENIED « la reconnexion ne changera rien ») ; check CI slugs MCP réels. En parallèle non bloquant : candidature partenaire LinkedIn (réglerait aussi les 401 à 60 j du scheduler, CORE-API-1R), petite PR upstream Pipedream.

### J — Pièces jointes / photos dans le chat (YG/YC, Z0, 104/105) + carrousel (100) — P2
- **Racines (chemin V1, prouvé par les releases des feedbacks)** : (1) crash déterministe **par session** : `state['…pending_delta'] |= …` sur clé persistée `null` (ADK 1.31.0) → TypeError reproduit avec le **vrai** ADK du venv, retry 3× inutile, tour entier en échec (AGENT-API-SN, 105 events/18 users) ; (2) **trois** chemins de drop silencieux — `resolver.py` (drop inline_data), `lite_llm.py:1057` (xlsx/docx ignorés, **encore en prod** pour les custom agents), et `file_manager/service.py:552/566` (mapping Anthropic absent/périmé → `return None` en warning — candidat n°1 pour l'excel invisible, identifié par la contre-attaque) ; (3) depuis le 17/08 : 404 legacy (cf. E). Nuance d'honnêteté : aucun event Sentry aux dates exactes des 5 feedbacks — l'attribution fine par feedback exige les vérifs prod listées. Carrousel multi-photos : **produit manquant** (le pipeline ne publie que `post.urls[0]`) → arbitrage CTO.
- **Fix final** : bascule V2 des fils legacy (même gate que E, coordonné) ; règle « zéro drop silencieux » appliquée aux **trois** chemins (part texte de substitution + warning Sentry taggé) ; test de contrat CI types client↔`attachmentPreparation.ts` ; **alerte immédiate** sur les 404 `/run_sse/employee_agent` (casse active invisible).

### N — Micro : transcription en finnois / micro muet (ZR/ZQ, Z2) — P2
- **Racines** : (1) Z2 : Safari ≤18.3 ne sait pas enregistrer `webm/opus`, exigé en dur → throw **avalé** (le hook ne rethrow pas, `InputMicrophone` n'affiche jamais `userError`) → échec 100 % muet, déterministe. (2) ZR/ZQ : l'hypothèse « hint de langue manquant » est **réfutée** (`language='fr'` déjà envoyé) — c'est une hallucination de la famille Whisper sur capture faible/silencieuse, `gpt-4o-transcribe` ne respectant pas strictement `language` ; aucun garde (énergie, prompt, logprobs — et le garde `NO_SPEECH_DETECTED` ne couvre que le texte vide).
- **Fix final (durci, harnais 18/18)** : négociation mimeType (webm→mp4→ogg) appliquée **aussi** au retry et à `useVoiceRecorder` ; `validateAudioBlobAsync` tolérant au MP4 fragmenté Safari (sinon notre propre validation re-casse le fallback) ; garde d'énergie client = **défense principale** (`maxVolume<seuil` → pas d'appel API), logprobs = filet + télémétrie seulement (une hallucination fluide passe — démontré) ; gardes **paramétrés et limités au chemin dictée** (`callOpenAITranscription` est partagé avec les voix WhatsApp/Instagram des clients finaux — régression évitée) ; affichage de `userError` dans les 3 variantes d'Input. Valider sur vrais Safari avant de déclarer Z2 corrigé.

### H — Image-gen « tout est figé » (10G/10F) — P2 (confiance 72 %)
- **Racine (la plus probable des deux démontrées)** : **état absorbant** — un outil sélectionné (ex. « Supprimer le fond ») survit à la disparition de son image source : input désactivé, outils désactivés, clic « Demander » = `if (!file) return;` **muet**. Seule issue : la croix du chip, non découvrable. Persiste en prod (le fix du 16/08 n'a couvert qu'un chemin sur trois). Variante secondaire : verrou in-flight sans Annuler ni watchdog (9-10 min). Blackout Sentry sur la fenêtre → pas de replay pour trancher.
- **Fix final (harnais 18/18)** : (a) remplacer le silent-return par `cancel + toast` — **obligatoire**, seul volet couvrant le cas 2+ fichiers ; (b) effet d'invariant « outil actif ⇒ source présente » ; (c) hint visible sous l'input ; (d) Annuler + watchdog **purement UI** — **ne PAS réduire le timeout client sous les 540 s serveur** (l'inverser consommerait le crédit avec un Media orphelin) ; coordonner avec la PR #1369 (même fichier, bug distinct).

### T — Triage transverse (27 items) — lots
- **Lot support/CSM immédiat** : ZN (client 2 ans, risque churn — en tête), Z3 (rappel), XR/ZG (gestes), YJ/YH (débloquer la récompense Trustpilot puis auditer le mécanisme), Z9/YA (procédure WhatsApp coexistence/migration), YT/YV (workaround Outlook, rattacher au chantier custom OAuth), 10Z (indiquer le nouveau chemin FAQ post-v3 + tooltip « nouveauté »), YY (appel de cadrage), 109/108 (tests internes, fermer).
- **Mini-fixes code à reproduire d'abord** : ZT/ZS (boucle « moyen de paiement » — payment_method niveau customer vs subscription), YZ (flux cancel), Y0 (drag-and-drop des cartes dans le chat), 10R/YX (invalidation cache contexte agent après édition brain-ai — à corréler).
- **Tickets produit** : champs ADN de marque + contraintes géo/secteur (Y5, résout Y7/Y4/XS), vue admin des bibliothèques (10T), facturation négociée visible (ZW/ZV), coexistence WhatsApp (Z9), multi-images carrousel (100).
- **Qualité agent** (conforme décision Fin : réglages, jamais de refonte) : prix uniquement depuis la KB (ZC), outils xlsx/pdf (ZE/ZP), prompt négatif images (YB).
- Déjà couverts : 10A Gmail secondaire (PRs #1302/#209 en attente CTO), Shopify/Pipedream custom OAuth (dossier existant).

---

## 4. Plan de livraison proposé (après ton GO — rien n'est pushé)

Ordre recommandé (impact client × dépendances) :
1. **PR saas `fix/onboarding-video-wistia`** (O) — 1 constante + fail-open + CI ; débloque l'onboarding de tous les self-serve. Quasi zéro risque.
2. **PR saas `fix/agent-channel-backfill`** (A) — restaure l'historique chatbot ; inclut le backfill (paquet complet livraison).
3. **PR saas `fix/sessions-legacy-gate`** (E/J volet 404) — stoppe la casse active des fils pré-juillet ; + alerte Sentry 404 immédiate ; arbitrage CTO meetingService/SEO.
4. **PR saas `fix/seo-residus`** (B) — 403/404/410 + motifs + contrat routes CI.
5. **PR saas `fix/brain-files-pagination`** (F) + **PR saas `fix/mission-heal-on-read`** (G) — indépendantes, parallélisables.
6. **PRs observabilité chat** (E) — v2-agent-api (captures + garde CI) puis saas (from-v2/onError + rendu différencié + composer 100k) ; watchdog après 48-72 h de données.
7. **PRs L** (core-api d'abord, puis v2-agent-api/api-agent : outil maison + blocklist), **PR I** (instagram_page en AJOUT), **PR N** (micro), **PR H** (états absorbants), **PR api-agent J** (drops silencieux).
8. Lots T en parallèle (support/CSM ne dépend pas du code).

**Arbitrages CTO requis** : réouverture du producteur SEO (le schéma DB est prêt) ; agents hybrides mail+chatbot (A) ; meetingService/SeoAnalysisView sur route morte ; partenariat LinkedIn ; coexistence WhatsApp ; multi-images carrousel ; limite 1 automatisation/compte ; historique email pré-17/08 non migré (réponse client A/112).

**Vérifications prod restantes (lecture seule, avant de clore certains feedbacks)** : config des agents `036c5a62…` et « Road to clean » (A) ; state session `952d3b54…` + logs Cloud Run 07/08 (J) ; logs netcup/Langfuse pour classer les causes chat (E) ; `MEMORY_WATERMARK_MB`/`SESSION_MAX_LIVE` effectifs (E) ; volumétrie `oauth_tokens` instagram vs instagram_page (I) ; `seo_reports` du workspace ZD (B) ; workspace de Florian (F/G).

---

*Généré le 2026-08-18. Sources : workflow `feedback-rca-sweep` (23 agents, 0 erreur), digests et harnais sous `d:\AGENTOVA\SAMY\tmp\feeds-2026-08-18\`. MCP Sentry/customer-io non authentifiés dans cette session (sans impact : API REST utilisée) — à réautoriser via `/mcp` si besoin des outils MCP.*
