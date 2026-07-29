# Agent support qui DIAGNOSTIQUE (pas qui énumère) — cadrage

**Date** : 2026-07-29 · **Porteur** : Olivio · **Statut** : **V1 IMPLÉMENTÉE ET VALIDÉE E2E EN LOCAL (2026-07-30)** — branche api-agent `feat/support-diagnostic-v1` ; reste les prérequis équipe (§8)

## 0. V1 livrée — faits validés

- **Outil `diagnose_workspace`** (agrégateur 3 sources, dégradation gracieuse par source, workspace verrouillé en closure serveur) + protocole anti-listes + règles de langage + `page_context` + trace d'audit des outils. 5 fichiers, +331 lignes.
- **Org Sentry = `agentovaai` ; le tag recherchable est `workspace_id`** (snake_case — PAS `workspaceId`, qui ne rend rien). Vérifié sur les issues réelles : le tag est posé par le client, core-api ET agent-api.
- Logs GCP : les deux conventions `jsonPayload.workspaceId` (Node) et `jsonPayload.workspace_id` (Python) sont couvertes par le filtre.
- **Preuve E2E** (workspace local sans Instagram connecté, question « mes publications instagram ne partent plus ») : *« En regardant ton espace, je vois que ton compte Instagram n'apparaît pas du tout parmi tes connexions actives — c'est pour ça que tes publications ne partent plus. 1. Va dans les paramètres d'intégrations… »* — constat vérifié, 3 temps, zéro jargon.

## 1. Le problème

Aujourd'hui, face à « mes posts Instagram ne partent plus », un bot SAV classique répond
une **liste de causes possibles** (« vérifiez votre compte, votre automation, vos
quotas… »). Le client fait le travail de diagnostic lui-même. Objectif : l'agent
**vérifie l'état réel du compte** et répond avec **la** cause et **le** geste.

## 2. Principe de langage client (non négociable)

> **L'agent vérifie en technicien, mais parle en humain.** La réponse doit être
> comprise par un enfant.

- Structure en 3 temps : **ce qui se passe** (mots du quotidien) → **le symptôme
  que le client voit** → **quoi faire** (UNE action + lien).
- **Vocabulaire interdit côté client** : Sentry, GCP, token, API, webhook, SQL,
  quota technique, noms de services internes. Traductions imposées : « ta
  connexion Instagram » (token OAuth), « l'envoi automatique » (automation/
  webhook), « ton espace de travail » (workspace).
- Exemple cible :
  *« J'ai regardé ton compte : ta connexion Instagram a expiré mardi, c'est pour
  ça que tes posts ne partent plus. Reconnecte-toi ici → [lien] et tout
  repartira. »*
- Le **détail technique n'est jamais perdu** : il alimente le brief d'escalade
  du conseiller humain (§6), pas la bulle du client.

## 3. Ce qui existe déjà (socle ~70 %)

| Brique | Où | Rôle |
|---|---|---|
| Cerveau API Messages (boucle agentique contrôlée, tool use multi-étapes) | api-agent PR #193, `feat/support-messages-brain` | Peut enchaîner interroger → corréler → conclure |
| Couche 1 `agent_ro` (vues read-only workspace-scoped, fail-closed) | migrations saas #1204 (`20260727120000/130000`) + `scripts/db/agent_ro_layer1.sql` (#193) | Organe de perception : `v_integrations` (avec `expires_at`), `v_automations` (statuts), `v_workspace`, etc. |
| Registre de lecture verrouillé | `support_read_registry.py` / `support_read_repository.py` (#193) | Tuyauterie outil ↔ DB |
| Brief d'escalade | `supportBriefGenerator.ts` (saas #1204) | Réceptacle du détail technique |
| Tags `workspaceId` sur chaque erreur Sentry backend | conventions logger du monorepo | Rend possible « les erreurs récentes de CE client » |

## 4. À construire (v1)

1. **Outils de vérification** branchés sur la couche 1 (registre existant) :
   `check_integrations` (connexions + expirations), `check_automations`
   (statuts/erreurs), `check_subscription` (plan, quotas, blocages),
   `check_recent_activity` (dernières exécutions).
2. **`get_recent_errors(workspace_id)`** via l'API Sentry (recherche par tag
   `workspaceId`, fenêtre 24-72 h) — l'agent lit les vraies erreurs du client.
   Différenciateur majeur ; aucun bot SAV du marché ne le fait.
3. **Protocole de diagnostic dans le prompt système** :
   hypothèse → vérification outillée → réponse UNIQUEMENT si constat vérifié,
   sinon escalade franche. **Interdiction formelle de répondre par une liste de
   causes possibles.** + règles de langage du §2.
4. **Contexte de page** : le client envoie son `pathname` avec chaque message
   (3 lignes côté `HelpCenterChatView`) — l'agent sait où il se trouve.
5. **Deep-links** : carte des écrans (builders `buildHubTabPath` & co) dans le
   prompt pour que chaque réponse se termine par le lien exact.
   ℹ️ `navigate_tool.py` (branche `v3-dev` api-agent) outille déjà la
   navigation pour les agents du chat — réutiliser plutôt que réinventer.

## 5. Ce qui reste v2 (hors périmètre immédiat)

- **SQL libre read-only** (`agent_reader`) — prévu par la spec Samy, la couche 1
  en était le prérequis. Questions analytiques (« combien de leads ce mois ? »).
- **Proactif** (l'agent signale une erreur avant que le client s'en plaigne).
- **Sync Intercom → base d'articles** (aujourd'hui : 38 articles embarqués en dur).
- **Mesure de résolution** (👍/👎 par réponse, taux d'escalade par sujet).

## 6. Escalade enrichie

Le brief conseiller reçoit TOUT ce que l'agent a vérifié : états lus, erreurs
Sentry (IDs, volumes), hypothèses écartées. Le conseiller arrive avec le dossier
complet, zéro question redondante au client.

## 7. Sécurité (inchangée, non négociable)

Lecture seule via `agent_reader` (NOBYPASSRLS, `default_transaction_read_only`),
isolation par `current_setting('app.workspace_id')` fail-closed, jamais de PII
de tiers (pattern `v_leads_count` : volumes, pas de coordonnées). L'outil Sentry
filtre par tag `workspaceId` côté SERVEUR de l'outil — le modèle ne choisit pas
le workspace.

## 8. Prérequis / arbitrages équipe

1. **Token API Sentry** (scope lecture issues/events, org agentova) → Secret
   Manager (`SENTRY_READ_TOKEN`), monté sur api-agent. Qui le crée ?
2. **⚠️ Prompts Langfuse absents** constatés le 29/07 (label production,
   projet test) : `v2/agents/support/sdk_system`,
   `v2/tools/support/{workspace_overview,connected_integrations,escalate}` →
   si absents aussi en test/prod, le cerveau tourne sur des fallbacks. À
   vérifier/créer AVANT toute itération prompt.
3. Fenêtre et budget de l'outil Sentry (rate limit API).

## 9. Estimation

- Outils couche 1 + protocole + contexte page + deep-links : **2-3 jours**
- Outil Sentry : **+1 jour**
- Total v1 : **~4 jours dev**, aucune migration DB nouvelle (la couche 1 est déjà versionnée).

— Olivio (généré avec l'assistance de Claude), 2026-07-29
