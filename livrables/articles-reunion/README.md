# Série d'articles d'aide « Réunion (Elisa) » (8 articles) — relecture CTO

**Destination après validation** : `api-agent/ai/support_messages/articles/` — numéros **47-54**, à la suite de la série Lily (39-46). ⚠️ À embarquer **quand le hub Réunion sort** (il vit sur la branche `feat/elisa-meetings`, pas encore mergée).

**Provenance des faits** : le code de `feat/elisa-meetings` (saas) — hub-config (onglets), meetingService/recallClient (bot, providers, agenda), meeting_agent_settings (identité, sections du résumé, fiche client, email CR, langue/longueur), pipeline résumé (sections + horodatages + responsables d'actions), transcript diarisé aux vrais noms, chat par réunion (timestamps cliquables), capture vidéo (décision produit : capture UTILISATEUR uniquement — toggle workspace, bouton, extension Chrome « Agentova Capture », bannière auto), partage par lien, traductions.

**⚠️ À confirmer avant embarquement** :
1. La disponibilité par plan (aucun gating trouvé — Elisa est dans « les 8 agents » des articles tarifs) ;
2. Le nom público de l'extension Chrome et son mode de distribution (aujourd'hui : installation développeur) ;
3. Les libellés d'onglets définitifs au moment du merge.

## Mises à jour proposées aux articles EXISTANTS (constat de la campagne d'éval du 2026-07-30)

| Article | Problème | Proposition |
|---|---|---|
| `03-plans-et-tarifs` + `22-plans-tarifs-detailles` | « Les 8 agents (Élisa, Benoît, Ethan, Charlotte, Arthur, Margot, Samy, Amandine) » — la liste devient fausse à la sortie de Lily (9ᵉ) ; l'éval a montré que le bot déduit l'inexistence de ce qui manque à ces listes | Passer à « 9 agents » en ajoutant Lily le jour de sa sortie — ou remplacer l'énumération par « tous nos agents IA spécialisés » (plus de liste à maintenir) |
| `25-agentova-bots` | À vérifier : s'il énumère les capacités par agent, ajouter Lily (téléphone) et le rôle note-taker d'Elisa | Mise à jour au fil des sorties |

| # | Fichier | Sujet |
|---|---|---|
| 47 | `47-reunion-decouvrir-elisa.md` | Vue d'ensemble : Elisa prend vos réunions en note |
| 48 | `48-reunion-inviter-elisa.md` | Inviter Elisa à une visio (lien, admission, plateformes) |
| 49 | `49-reunion-connecter-agenda.md` | Agenda Google : Elisa rejoint toute seule |
| 50 | `50-reunion-compte-rendu.md` | Le compte rendu (sections, fiche client, email) |
| 51 | `51-reunion-transcript-chat.md` | Transcript aux vrais noms + poser des questions à Elisa |
| 52 | `52-reunion-capture-video.md` | La capture vidéo de la réunion |
| 53 | `53-reunion-personnaliser-elisa.md` | Nom, photo, annonce, langue et style du compte rendu |
| 54 | `54-reunion-retrouver-partager.md` | Rechercher, partager par lien, télécharger |
