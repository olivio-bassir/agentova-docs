# Coût du support IA — notre agent (Claude) vs Intercom Fin

*Prix vérifiés le 30 juillet 2026 sur les pages officielles. Sources en fin de document.*

---

## Résumé

**En usage réel, notre agent coûte environ 8 à 10 fois moins cher que Fin.** Le risque n'est pas le prix à l'unité : c'est l'absence de plafond mensuel. Un seul utilisateur qui sature le quota horaire actuel coûte plus cher que toute la base clients réunie.

Trois mesures ramènent la facture sous 20 $/mois **et** la bornent par construction, sans dégrader la qualité des réponses : routage Haiku/Sonnet, plafond mensuel en euros, troncature des retours d'outils.

⚠️ **Un chiffre à retenir** : Sonnet 5 est en tarif d'introduction jusqu'au **31 août 2026**. Au 1er septembre, son prix augmente de 50 %.

---

## 1. Les prix officiels

### Claude (API Anthropic)

| Modèle | Entrée | Sortie | Écriture cache 1 h | Lecture cache |
|---|---|---|---|---|
| **Sonnet 5** *(promo jusqu'au 31/08/2026)* | 2 $/M | 10 $/M | 4 $/M | 0,20 $/M |
| **Sonnet 5** *(à partir du 01/09/2026)* | 3 $/M | 15 $/M | 6 $/M | 0,30 $/M |
| **Haiku 4.5** | 1 $/M | 5 $/M | 2 $/M | 0,10 $/M |

Le tarif d'introduction de Sonnet 5 (2 $/10 $) se termine le 31 août 2026 ; le tarif standard (3 $/15 $) s'applique ensuite. Haiku 4.5 n'est pas concerné.

À titre de repère, Anthropic documente un cas d'usage support client à **37 $ pour 10 000 tickets** en Haiku 4.5 (~3 700 tokens par conversation).

### Intercom Fin

**0,99 $ par « outcome »** (résolution). Un outcome est compté quand :

- le client confirme que son problème est résolu, **ou**
- il ne redemande pas d'aide après la réponse de Fin, **ou**
- Fin termine une procédure — **transferts vers un humain inclus**.

Deux points importants :

1. **Une seule facturation par conversation**, quel que soit le nombre de questions posées. C'est la protection structurelle de Fin : son pire cas est borné.
2. Le silence du client compte comme une résolution. Un utilisateur qui abandonne, agacé, est facturé comme satisfait.

En usage autonome (branché sur un helpdesk existant) : pas de coût de siège, mais un engagement minimum mensuel (~50 outcomes).

---

## 2. Ce que fait notre implémentation aujourd'hui

Relevé dans le code, branche `feat/support-messages-brain` (api-agent) :

| Paramètre | Valeur | Fichier |
|---|---|---|
| Modèle | `claude-sonnet-5` | `ai/support_messages/brain.py` |
| Tours d'outils max par message | 16 | idem |
| Cache du prompt système | 1 h | idem |
| Cache de fin de contexte | 5 min | idem |
| Quota | 30 messages / 60 min **par utilisateur** | `server/src/services/helpSupportService.ts` |

Les articles d'aide ne sont **pas** injectés dans le contexte : l'agent les lit à la demande via un outil. C'est déjà une bonne décision de coût, à conserver.

---

## 3. Pourquoi deux tables en base

Le centre d'aide ajoute deux modèles au schéma Prisma. Les deux existent pour la même raison, et ce n'est pas du confort : **le backend tourne sur plusieurs instances Cloud Run**. Rien de ce qui doit survivre à un changement d'instance ne peut vivre en mémoire.

### `support_chat_sessions` — l'historique des conversations

Deux messages d'une même conversation n'atterrissent pas forcément sur la même instance. Un historique en mémoire serait perdu dès le deuxième message, ou dépendrait de l'instance touchée par la requête — l'agent répondrait alors sans contexte, ou avec le contexte de quelqu'un d'autre selon le routage.

- Historique stocké au format Anthropic Messages (`[{role, content:[blocs]}]`).
- Rétention 30 jours via `expires_at`, repoussée à chaque message, purge par job planifié.
- Isolation par `workspace_id`, suppression en cascade avec le workspace.

### `support_chat_rate_limits` — le compteur d'usage

30 messages par heure et par utilisateur. Même contrainte : un compteur local donnerait *N* fois la limite avec *N* instances, c'est-à-dire aucune limite réelle.

- Une ligne par utilisateur, réutilisée à chaque fenêtre : la table reste de la taille du nombre d'utilisateurs ayant déjà écrit au support.
- `window_start` n'est jamais rafraîchi par les appels suivants, pour qu'un usage régulier ne s'accumule pas jusqu'au blocage.

**Cette seconde table est directement le sujet de ce document** : c'est le garde-fou de coût. Sans elle, un compte qui boucle génère des milliers d'appels facturés par jour, sans que rien ne l'arrête. Sa limite actuelle est cependant insuffisante — elle borne le débit, pas la facture mensuelle (voir §5 et le levier 2 du §6).

### Alternatives écartées

| Option | Pourquoi non |
|---|---|
| Historique en mémoire | Perdu au changement d'instance ; le multi-instance est déjà en production |
| Historique dans Redis | Ajoute une dépendance d'infrastructure pour une donnée qu'on veut de toute façon pouvoir auditer et purger avec rétention |
| Compteur en mémoire | Donne *N* fois la limite avec *N* instances — pas une limite |
| Historique côté client | Non fiable pour un quota (contournable) et perdu au changement d'appareil |

---

## 4. Méthode de calcul

**Hypothèse de travail** : ~0,02 $ par message utilisateur en Sonnet 5 (tarif promo), décomposé ainsi :

- prompt système en cache 1 h (~8 000 tokens), relu à chaque appel modèle : 8 000 × 0,20 $/M ≈ 0,0016 $
- ~3 appels modèle par message (une réponse + deux tours d'outils) : ≈ 0,005 $
- historique et retours d'outils non cachés (~4 000 tokens cumulés) : ≈ 0,008 $
- sortie (~600 tokens) : ≈ 0,006 $

> ⚠️ **Ce sont des estimations, pas des mesures.** Le volume de tokens par message n'a pas été relevé en conditions réelles. Langfuse trace déjà chaque appel (modèle, tokens, coût) : une semaine d'usage sur l'environnement de test remplace toutes ces hypothèses par des chiffres réels. **À faire avant tout arbitrage définitif.**

---

## 5. Scénarios chiffrés

### Usage normal — 100 workspaces, ~20 questions/mois chacun (~500 conversations)

| Solution | Coût mensuel |
|---|---|
| Notre agent (Sonnet 5, promo) | **~40 $** |
| Notre agent (Sonnet 5, après le 01/09) | **~60 $** |
| Notre agent (Haiku 4.5) | **~20 $** |
| Fin (500 résolutions × 0,99 $) | **~495 $** |

### Pire cas — un utilisateur qui sature le quota

30 messages/heure × 24 h × 30 jours = **21 600 messages/mois** pour une seule personne.

| Solution | Coût mensuel |
|---|---|
| Notre agent (Sonnet 5, promo) | **~430 $** |
| Notre agent (Sonnet 5, après le 01/09) | **~650 $** |
| Notre agent (Haiku 4.5) | ~215 $ |
| Fin | **~1 $** (une seule conversation facturée) |

**Sur ce scénario, Fin gagne largement.** Notre coût est proportionnel aux tokens, sans plafond ; celui de Fin est borné par conversation. C'est le point de fond, et il est réel.

### Point de bascule

Notre agent devient plus cher que Fin à partir de **~50 messages dans une même conversation** (0,99 $ ÷ 0,02 $). En deçà, nous sommes moins chers ; au-delà, Fin l'est.

Le quota actuel (30 messages/heure) borne le **débit**, pas la **facture** : il autorise 21 600 messages par mois.

---

## 6. Trois leviers, sans perte de qualité

### Levier 1 — Routage par difficulté *(gain : −60 %)*

Haiku 4.5 traite le message en premier, avec le même prompt et les mêmes outils, plus un outil d'escalade. Il répond aux questions documentaires (lire un article, reformuler) ; il passe la main à Sonnet 5 dès qu'il faut croiser plusieurs requêtes en base ou raisonner sur un état incohérent.

- Haiku coûte **un tiers** de Sonnet 5 après septembre.
- Quand Haiku escalade, son appel est perdu : ~0,003 $, négligeable.
- Qualité intacte sur les cas difficiles, qui finissent chez Sonnet.

*Effort estimé : 1 jour.*

### Levier 2 — Plafond mensuel en euros par workspace *(gain : borne le pire cas)*

C'est la seule mesure qui règle vraiment le problème. Compter des messages ne borne pas une facture : un message simple et un diagnostic à 16 tours n'ont pas le même coût.

L'infrastructure existe déjà dans le schéma : `credit_budgets` (avec `monthly_limit`, alerte e-mail, mois de dernière notification) et `credit_transactions` (idempotent par `reference_type`/`reference_id`). Il manque un `CreditProduct` support et le débit du coût réel remonté par l'API à chaque appel.

- Coût **borné par construction**, quels que soient le nombre de tours et la taille du contexte.
- Aucun impact en usage normal : seuls les abus sont coupés.

*Effort estimé : 1 à 2 jours.*

### Levier 3 — Borner la taille des retours d'outils *(gain : significatif sur les conversations longues)*

`MAX_TURNS = 16` n'est pas le problème. Le problème est qu'un tour peut réinjecter des centaines de lignes de base ou un article entier dans le contexte — puis les retraîner à chaque tour suivant.

Tronquer les résultats (N premières lignes, article résumé) coûte moins cher **et** répond mieux : un modèle noyé sous 20 000 tokens de SQL raisonne moins bien qu'avec les 30 lignes pertinentes.

*Effort estimé : une demi-journée.*

### Effet cumulé (500 conversations/mois, tarifs post-01/09)

| Configuration | Coût mensuel |
|---|---|
| Aujourd'hui (Sonnet 5 partout) | ~60 $ |
| + routage Haiku/Sonnet | **~25 $** |
| + troncature des retours d'outils | **~20 $** |
| + plafond mensuel | ~20 $, **et pire cas borné** |
| *Fin, même volume* | *~495 $* |

---

## 7. Ce que nous ne recommandons pas

- **Remplacer l'agent par Fin.** Plus cher en usage normal, et surtout : Fin répond à partir d'articles, il ne lit pas la base du workspace. « Pourquoi ma campagne n'est pas partie », « où en est mon import » sont hors de sa portée. Ce ne sont pas deux prix pour le même service.
- **Réduire `MAX_TURNS` brutalement.** Cela coupe les diagnostics en cours de route : on dégrade la résolution pour économiser des centimes.
- **Mettre en cache les réponses aux questions fréquentes.** Tentant, car le support est répétitif — mais nos réponses dépendent de l'état du workspace. Le risque de servir une réponse fausse dépasse le gain. À réserver, éventuellement, aux questions purement documentaires sans contexte.

---

## 8. Recommandation

1. **Mesurer une semaine** via Langfuse (déjà branché) : part documentaire vs diagnostic, tokens réels par message.
2. **Routage Haiku/Sonnet** — 1 jour, −60 %, aucun risque produit.
3. **Plafond mensuel en euros** — 1 à 2 jours, borne le pire cas, réutilise le ledger de crédits existant.
4. **Troncature des retours d'outils** — une demi-journée, gain de coût *et* de qualité.

Le passage à Haiku annule à lui seul la hausse de 50 % du 1er septembre : la facture *baisse* de 40 à 20 $ au lieu de monter à 60 $.

---

## Sources

- [Anthropic — tarifs API](https://platform.claude.com/docs/en/about-claude/pricing) *(consulté le 30/07/2026)*
- [Intercom — tarifs Fin](https://www.intercom.com/pricing) *(consulté le 30/07/2026)*
- Code : `ai/support_messages/brain.py` (api-agent, branche `feat/support-messages-brain`), `server/src/services/helpSupportService.ts` (saas, PR #1204)
