# Attendee : pourquoi le self-host coûte 4× moins cher (et quand basculer)
**2026-07-17 · Complément à [`systeme-visio-recorder-agentova.md`](systeme-visio-recorder-agentova.md) (§5-bis, recherche coût minimum)**

## Le même logiciel, deux factures

[Attendee](https://github.com/attendee-labs/attendee) est un moteur de bots de réunion (Meet/Teams/Zoom) **source-available** (licence Elastic 2.0 — l'auto-hébergement pour son propre SaaS est explicitement permis). Il existe donc en deux modes :

| | Attendee **hébergé** (leur cloud) | Attendee **self-host** (notre GCP) |
|---|---|---|
| Qui opère les bots | Eux | Nous |
| Prix | **0,50 $/h** (5 h d'essai gratuites, remises volume → 0,35 $) | **~0,13 $/h** de coût réel |
| Composition du prix | Infra + équipe ops + support + stockage + **marge** | Compute GCP ~0,09 $/h (pod Chrome **4 vCPU / 4 Gi** par bot — specs vérifiées dans `bots/bot_pod_creator.py`) + STT externe (Groq whisper-large-v3-turbo : 0,04 $/h) |

Les 0,50 $/h du cloud = ~0,13 $ de machines + ~0,37 $ de service. En self-host, on garde les machines et on supprime le reste → **÷ 4 (≈ 3,8× exactement)**.

## Le coût caché du self-host : l'ops

Ce qu'on supprime de la facture, quelqu'un doit le faire — nous :
- surveillance des bots, scaling, upgrades quand Google change l'UI de Meet (dépendance aux mises à jour du projet open source)
- estimation : **150-300 $/mois de temps d'ops**

### Le point de bascule : ~400-800 h de réunion/mois

Économie brute = 0,37 $/h. Elle doit d'abord absorber l'ops :

| Volume mensuel | Recall (baseline prouvée) | Attendee self-host (infra+STT+ops ~200 $) | Gagnant |
|---|---|---|---|
| 100 h | 50 $ | ~213 $ | **Recall** |
| 500 h | 250 $ | ~265 $ | ≈ égalité (zone de bascule) |
| 1000 h | 500 $ | ~380 $ | **Self-host** (et l'écart grandit) |

> Analogie : louer une voiture avec chauffeur et garage inclus (0,50) vs acheter la même voiture (0,13) et faire l'entretien soi-même. Rentable seulement si on roule beaucoup.

## Les 3 conditions avant de basculer (issues de la recherche du 17/07)

1. **Fiabilité de join à prouver** — LE critère éliminatoire (notre test terrain du 16/07 : Recall 2/2 joins en 6-7 s ; Vexa cloud 1/4, disqualifié — pannes confirmées par leurs propres issues GitHub). Celle d'Attendee n'est mesurée nulle part.
   → **Pilote à 0 €** : les 5 h gratuites du cloud Attendee font tourner le MÊME code de bot que le self-host — tester le join sur l'hébergé = valider la voie self-host sans monter d'infra. (Script prêt : `poc-recorder/poc-attendee.js`.)
2. **Diarisation à trancher** — la voie STT low-cost (Groq) n'a aucune diarisation (vérifié API-wide) ; il faut soit les flux/événements par participant du bot, soit pyannote/WhisperX self-host, soit un STT avec diarisation incluse (Gladia 0,20-0,25 $/h).
3. **Stack GCP à adapter** — Attendee attend un stockage S3 (adaptation GCS/S3-compat) ; modèle « un pod k8s par bot » → GKE plutôt que Cloud Run.

## Décision recommandée

- **Aujourd'hui (< 400 h/mois)** : Recall.ai — le moins cher qui soit 100 % fonctionnel à fiabilité prouvée.
- **Dès maintenant, à 0 €** : pilote de join sur Attendee cloud (5 h gratuites) pour dérisquer l'avenir.
- **À l'approche de ~500 h/mois** : si le pilote est vert, monter le self-host GCP → facture ÷ 4, et souveraineté des données en bonus.

*Sources principales (vérifiées 17/07/2026) : attendee.dev/pricing · github.com/attendee-labs/attendee (serializers.py, bot_pod_creator.py, LICENSE) · console.groq.com (pricing STT) · détail complet et votes de vérification dans le §5-bis du doc de cadrage.*
