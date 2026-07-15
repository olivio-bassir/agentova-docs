# Veille technique — Enregistrement & transcription de visios pour Agentova
**Date : 2026-07-15 · Méthode : recherche multi-sources (23 sources, 115 affirmations extraites, 25 vérifiées par vote adversarial 3 juges → 21 confirmées / 4 réfutées) · Mission 3 réunion Samy 2026-07-13**

## Critère n°1 (imposé) : zéro friction d'invitation
Pas d'invitation email/agenda pour démarrer. L'idéal : coller l'URL du meeting dans Agentova → capture démarre. Nuance incompressible : sur Google Meet, un participant externe non invité doit être **admis d'un clic par l'hôte** (sécurité Meet, aucun vendor ne la contourne). Le "zéro clic" absolu n'existe qu'en capture sans bot (desktop/extension) ou via le domaine Workspace du client.

---

## Verdict en une ligne
**Seule la famille des APIs de meeting-bots coche toutes les cases** (envoi du bot par URL programmatique, marque blanche "Agentova", temps réel + post-call, résidence UE). Recommandation : **Recall.ai (+ Gladia pour le français)** en socle, **Vexa** en plan B économique/souverain, APIs natives Meet/Graph en enrichissement optionnel.

---

## Famille 1 — APIs de meeting-bots ✅ (la bonne famille)

| | Recall.ai | Vexa | MeetingBaaS | Skribby | Attendee |
|---|---|---|---|---|---|
| Prix bot | **0,50 $/h** (facturé à la seconde, 5 h gratuites) | 0,30 $/h | ~0,69 $/h (transcription incluse) | 0,35 $/h | open source |
| Transcription | +0,15 $/h native OU STT tiers au choix | +0,20 $/h (Whisper) | incluse | pass-through | bring-your-own |
| Plateformes | **Meet + Teams + Zoom** + Webex + GoTo (beta) | Meet + Teams (Zoom à confirmer — claim contradictoire) | Meet/Teams/Zoom | Meet/Teams/Zoom | Meet/Teams/Zoom |
| Join par URL (sans invitation) | ✅ `POST /bot {meeting_url}` | ✅ | ✅ | ✅ | ✅ |
| Marque blanche | ✅ `bot_name` = "Agentova" (défaut neutre, zéro branding Recall) | ✅ | ✅ | ✅ | ✅ (self-host) |
| Temps réel | ✅ websocket/webhook (transcripts, audio, participants) | ✅ | ✅ | ? | ? |
| Résidence UE | ✅ **Francfort** (`eu-central-1.recall.ai`, déploiement séparé) | ✅ self-host = souveraineté totale | ? (FR-based co.) | ? | self-host |
| Self-host | ❌ | ✅ **Apache 2.0** (Docker/Helm/K8s) | ❌ | ❌ | ✅ |
| Maturité | Leader (alimente une grande partie du marché) | jeune | moyenne | jeune | jeune |
| Coût ~1000 meetings×1 h/mois | **~500-650 $/mois** | ~500 $/mois cloud, ~0 $ self-host (+GPU) | ~690 $/mois | ~350-400 $ + STT | infra seule |

Notes vérifiées (sources primaires, fetch live 15/07/2026) :
- Recall : prix baissé de 0,70→0,50 $/h début 2026, stockage >7 j +0,05 $/h, remises volume négociables. Zoom exige une app OAuth à créer. Calendriers Google/Microsoft intégrés sur tous les tiers.
- Recall × Gladia : intégration **officielle** (`transcription_options.provider="gladia"`), docs des deux côtés. Gladia (pricing officiel) : ~0,20 $/h batch, ~0,25 $/h streaming, **diarisation incluse**, optimisé multilingue/français → ~200-250 $/mois pour 1000 h, facturé chez Gladia.
- Vexa : 12 mois de stockage inclus, self-host = « full platform, no limits », Whisper auto-hébergé (l'audio ne quitte pas l'infra) — déployable sur le GCP d'Agentova (prévoir GPU pour un français de qualité).

## Famille 2 — Note-takers avec API ❌ (disqualifiés comme socle)

| | Verdict | Raison (vérifiée) |
|---|---|---|
| Fireflies | ❌ | Webhooks à l'échelle équipe = plan **Enterprise + rôle Super Admin + avenant contractuel**. Pas de dispatch de bot en marque blanche. |
| tl;dv | ❌ | API **sans aucun endpoint d'envoi de bot** (seul write = import de média). Bot "tl;dv Notetaker" non renommable. Droits d'export liés au plan de l'organisateur. |
| Otter | ❌ | API réservée **Enterprise via account manager**, lecture/export uniquement. |

Ces produits sont des concurrents finis, pas des briques : on ne construit pas "Arthur qui prend des notes" dessus.

## Famille 3 — Extension navigateur / sans bot ⚠️ (non conclusif)
Aucune affirmation n'a survécu à la vérification sur cette famille (Tactiq-style scraping de captions, Recall Desktop SDK — au même prix 0,50 $/h que le bot). À creuser seulement si le clic "Admettre" du bot s'avère rédhibitoire en pratique. Risque structurel : le scraping de captions casse à chaque refonte de l'UI Meet = maintenance subie.

## Famille 4 — APIs natives (sans bot) 🟡 (complément, pas socle)
- **Google Meet REST API v2** : récupération **post-call** des artefacts (MP4 dans le Drive de l'organisateur, transcript Google Docs, entries purgées à 30 j) — seulement si l'enregistrement a été activé dans la réunion ET édition Workspace éligible. Notifications push via **Workspace Events API** (Pub/Sub, `recording.v2.fileGenerated`). Le claim "l'API ne peut pas déclencher l'enregistrement" a été RÉFUTÉ → un déclenchement via `spaces.artifactConfig` existe peut-être, à vérifier en POC.
- **Microsoft Graph (Teams)** : transcripts .vtt + recordings .mp4 **après la réunion** (notify-then-fetch), 4 portées de webhooks, mais dépendance totale à l'admin du tenant CLIENT (2 réglages peuvent tout couper, erreur `GraphAccessToTranscriptsDisabled`) et ⚠️ **enforcement du réglage tenant le 29 juillet 2026** (désactivé par défaut). APIs de fetch probablement metered.
- Conclusion : impossible d'en faire le mécanisme principal d'un SaaS multi-tenant (dépend de la config Workspace/tenant de CHAQUE client, pas de marque blanche, pas de temps réel). Bon canal d'enrichissement opportuniste plus tard.

## Famille 5 — Briques STT (complété le 15/07 après passe ciblée)

**Podium "meilleure transcription FR" (juillet 2026)** — en distinguant le papier et le terrain :

| Modèle | Force | Chiffres (⚠️ sources vendeur sauf mention) | Intégré Recall ? |
|---|---|---|---|
| **Microsoft MAI-Transcribe-1.5** (Azure Foundry) | Meilleur WER brut annoncé, 43 langues, bat Whisper-v3/GPT-Transcribe/**Scribe v2**/Gemini 3.1 Flash sur FLEURS ; v1 = 3,8 % WER moyen 25 langues (repris par Coval, indépendant) | SOTA « sur le papier », FR dans les langues fortes | ❌ (Azure only → post-process manuel) |
| **ElevenLabs Scribe v2** | FR = **3,1 % WER FLEURS** (v1, vendeur) ; v2 Realtime sub-150 ms, ~93,5 % accuracy multilingue temps réel ; diarisation 32 locuteurs | Leader accuracy brute accessible via API | ✅ officiel |
| **Gladia Solaria-3** | #1 revendiqué sur **enregistrements de PRODUCTION** EN/FR/DE/ES/IT (vs studio) ; 29 % WER et **3× DER** (diarisation) de mieux que la concurrence sur du conversationnel ; code-switching ; société FRANÇAISE, résidence UE | 0,20 $/h batch / 0,25 $/h realtime, diarisation incluse | ✅ officiel |
| Speechmatics Ursa 2 | -18 % WER vs Ursa 1 sur 55 langues, réputé sur les accents | solide outsider | ✅ officiel |
| Deepgram Nova-3 | latence/prix imbattables, anglais d'abord | pas le choix FR | ✅ officiel |

**Mise en garde de la source indépendante (Coval)** : « les benchmarks vendeurs sont du marketing avec des mesures » — audio studio, langue unique, comparaisons datées. FLEURS = lecture propre en studio ; une réunion = bruit, chevauchements, jargon → **la diarisation (DER) compte autant que le WER**, et c'est là que Gladia revendique son avance sur du réel.

**Décision recommandée** : Gladia par défaut (FR-first, diarisation incluse, UE, prix, 1 paramètre via Recall) ; **bench interne** sur 3-4 vraies réunions Agentova : Gladia vs Scribe v2 vs native Recall (+ MAI-Transcribe-1.5 hors ligne comme référence d'accuracy). Le switch entre providers = changer `transcription_options.provider`, donc décision réversible à tout moment — c'est l'atout maintenabilité de l'archi Recall.

Sources : elevenlabs.io/blog/meet-scribe · venturebeat.com (Scribe) · microsoft.ai/news (MAI-Transcribe-1.5) · artificialanalysis.ai (MAI-Transcribe-1) · coval.ai/blog (benchmarks indépendants) + benchmarks.coval.ai/stt (leaderboard live) · gladia.io (Solaria-3, pricing)

---

## Shortlist d'architectures

### A. Recall.ai + Gladia — **recommandée** 
`client colle l'URL Meet → core-api POST /bot (bot_name:"Agentova", région EU) → bot toque → hôte admet → transcript FR temps réel via websocket → webhook post-call (MP4 + transcript final)`
- ~500 $/mois bot + ~200-250 $/mois Gladia à 1000 meetings×1 h. Une seule API pour Meet/Teams/Zoom. Marque blanche totale. UE = Francfort. Maintenabilité portée par le leader du marché (c'est leur unique métier).
- Risques : vendor US (CLOUD Act) malgré la résidence UE ; localisation du traitement Gladia à confirmer (société française, résidence EU documentée) ; prix catalogue.

### B. Vexa (cloud puis self-host) — plan B économique/souverain
- Cloud : 0,50 $/h tout compris (~500 $/mois). Self-host Apache 2.0 sur notre GCP : coût marginal ≈ infra+GPU, souveraineté totale (argument commercial RGPD fort).
- Risques : maturité moindre, couverture Zoom à confirmer, qualité FR = Whisper (bon mais à valider), ops à notre charge en self-host.

### C. APIs natives Meet/Graph — complément différé
- Coût quasi nul mais post-call only, dépendant du Workspace/tenant du client, sans marque blanche. À brancher plus tard comme canal bonus pour les clients Workspace/Teams bien configurés.

## Questions ouvertes (à traiter en POC)
1. **UX exacte d'admission du bot dans Meet** selon provider (knocking, taux d'échec de join) → testable avec les **5 h gratuites de Recall** dès aujourd'hui.
2. Benchmark FR réel Gladia vs Deepgram vs native Recall sur nos réunions.
3. MeetingBaaS/Skribby/Attendee : vérification primaire (pricing/UE/fiabilité) si le budget devient le critère dominant.
4. Meet `spaces.artifactConfig` : déclenchement programmatique d'enregistrement natif possible ?

## Sources principales (fetch live 15/07/2026)
recall.ai/pricing · docs.recall.ai (bot-overview, transcription, regions, real-time-endpoints, bot_create) · recall.ai/blog/new-recall-ai-pricing-for-2026 · vexa.ai/pricing · github.com/Vexa-ai/vexa · docs.gladia.io/chapters/integrations/recall · gladia.io/pricing · docs.fireflies.ai (webhooks, super-admin) · doc.tldv.io · help.otter.ai (Public API) · developers.google.com/workspace/meet/api (overview, artifacts) · developers.google.com/workspace/events · learn.microsoft.com (transcripts overview, change notifications) · skribby.io/blog/meeting-bot-api-comparison-2026 · news.ycombinator.com/item?id=45199648
