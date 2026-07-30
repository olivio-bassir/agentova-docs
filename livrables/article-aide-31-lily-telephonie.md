<!-- ============================================================
BROUILLON POUR RELECTURE CTO — article destiné à la base de
connaissance du centre d'aide (api-agent/ai/support_messages/articles/
31-lily-telephonie.md) après validation.

Chaque fait provient du CODE (branches origin/v3 saas + v3-dev api-agent),
notamment shared/credits.ts (barèmes « actés » avec dates). À CONFIRMER
avant embarquement (marqués ⚠️ dans les commentaires) :
- disponibilité de Lily par plan (aucun gating par plan trouvé dans le code)
- le nom exact affiché des 8 onglets si l'UI évolue d'ici le merge v3
============================================================ -->

# Lily — votre standard téléphonique intelligent

**Découvrez Lily, l'agente téléphonique d'Agentova : elle répond à vos appels, en passe pour vous, envoie des SMS et discute sur votre site — 24 h/24.**

---

Lily est l'employée IA « Téléphonie » d'Agentova. Elle décroche vos appels entrants, mène vos campagnes d'appels sortants, répond par SMS et peut aussi discuter par écrit via un widget sur votre site. Vous la retrouvez dans le menu **Téléphonie** de votre espace de travail.

---

## Ce que Lily sait faire

* **Répondre à vos appels entrants** : elle décroche pour votre entreprise, renseigne vos clients à partir de vos documents, et peut transférer l'appel.
* **Passer des appels sortants** : appels un par un, ou **campagnes d'appels** programmées vers une liste de contacts (avec suivi de l'avancement).
* **Envoyer des SMS** pendant ou après un appel (confirmation, lien, récapitulatif).
* **Discuter par écrit** via le **widget** à installer sur votre site.
* **Résumer son activité** : l'onglet « Résumé des activités » retrace ses appels et conversations.

## Votre numéro de téléphone

Deux possibilités, dans l'onglet **Numéros** :

* **Un numéro fourni par Agentova** — prêt à l'emploi, appels et SMS activés.
* **Votre propre numéro** (compte Twilio existant) — vous le connectez et Lily l'utilise.

Vous pouvez aussi configurer un **renvoi vers votre numéro personnel** : si Lily doit passer la main, l'appel arrive sur votre téléphone.

## Personnaliser Lily

Dans l'onglet **Personnalisation** :

* **Sa voix** : choisissez-la, puis écoutez le rendu dans l'onglet **Test Vocal** avant de la mettre en service.
* **Son expressivité** : ajoutez des indications de jeu (marquer une pause, parler plus vite…) pour un rendu plus naturel — jusqu'à 15 indications.
* **Ses connaissances** : Lily s'appuie sur les documents de votre [Cerveau IA](https://help.agentova.ai/) que vous lui confiez — chaque agente a sa propre sélection de documents.

## Combien ça coûte ?

Lily consomme les [crédits de votre workspace](https://help.agentova.ai/articles/30-credits-workspace-agentova) (1 crédit = 1 €) :

* **Appels** : 0,29 crédit par minute (0,24 sur le plan Pro). Le décompte se fait **à la seconde réellement parlée** — un appel qui ne décroche pas ne coûte rien.
* **Messages écrits (widget)** : 0,02 crédit par réponse de Lily.
* **SMS** : 0,08 crédit par segment de SMS, plus 0,03 crédit par envoi. (Un SMS long ou avec certains accents compte plusieurs segments — c'est le fonctionnement standard des SMS.)

### Garder la maîtrise du budget

* Fixez un **plafond mensuel** dédié à la Téléphonie dans vos paramètres de facturation : une fois atteint, vous recevez un **email d'alerte**.
* Si les crédits du workspace sont épuisés, Lily **cesse de prendre des appels** jusqu'à la recharge — aucune mauvaise surprise.

## Suivre son activité

* **Conversations** : la liste de tous les appels et échanges, avec transcription.
* **Campagnes** : l'avancement de chaque campagne d'appels (programmée, en cours, terminée).
* **Résumé des activités** : la synthèse régulière de ce que Lily a fait pour vous.

---

*Un doute, une question sur Lily ? Écrivez-le simplement dans ce chat — et si besoin, un conseiller humain prend le relais.*
