# Système d'enregistrement & transcription de visios — Agentova
**Document de référence · 2026-07-15 · Olivio Bassir**
*Synthèse de la veille technique (23 sources, prix vérifiés le 15/07/2026 sur les pages officielles, affirmations passées au vote adversarial 3 juges — détail : [`veille-recorders-visio-2026-07-15.md`](veille-recorders-visio-2026-07-15.md))*

---

## 1. Objectif & contraintes

Intégrer **nativement dans Agentova** un note-taker de réunions (type Sintra/Otter) : enregistrement + transcription, **Google Meet d'abord**, puis Teams/Zoom. On **intègre un service externe via API** — on ne développe pas de zéro.

**Contraintes retenues (réunion 13/07 + arbitrages) :**
| # | Contrainte | Source |
|---|---|---|
| 1 | **Zéro friction d'invitation** — pas d'invitation email/agenda pour démarrer ; coller l'URL du meeting doit suffire | Arbitrage Olivio 15/07 (rédhibitoire) |
| 2 | Marque blanche — le bot doit s'appeler **"Agentova"**, pas "Fireflies" | Réunion |
| 3 | Qualité de transcription **en français** + diarisation (qui-dit-quoi) | Réunion |
| 4 | Coût maîtrisé à l'échelle (~1 000 réunions/mois comme ordre de grandeur) | Réunion |
| 5 | Sécurisé / RGPD — résidence UE | Implicite (clients FR) |
| 6 | **Performant, manipulable, adaptable, maintenable** — pas de dépendance fragile (scraping), composants remplaçables | Arbitrage Olivio |

**Limite incompressible à connaître** : sur Google Meet, un participant externe non invité (donc notre bot) doit être **admis d'un clic par l'hôte** ("Admettre") — c'est une sécurité de Google, aucun vendor ne la contourne. Le "zéro clic" absolu n'existe qu'en capture sans bot (desktop/extension, non retenu — cf. §3) ou si le bot est invité via l'agenda (friction qu'on refuse).

---

## 2. La solution retenue : **Recall.ai + Gladia**

### Architecture cible

```
Utilisateur Agentova                    core-api                      Recall.ai (région EU)
      │                                     │                                │
      │ colle l'URL Meet / clic bouton      │                                │
      ├────────────────────────────────────►│  POST /api/v1/bot              │
      │                                     ├───────────────────────────────►│
      │                                     │   { meeting_url,               │
      │                                     │     bot_name: "Agentova",      │
      │                                     │     transcription_options:     │
      │                                     │       { provider: "gladia" } } │
      │                                     │                                │
      │        le bot "Agentova" toque → l'hôte clique "Admettre"            │
      │                                     │                                │
      │                                     │◄─── websocket temps réel ──────┤
      │   transcript live dans l'UI  ◄──────┤     (transcript, participants) │
      │                                     │◄─── webhook post-call ─────────┤
      │   compte-rendu par l'agent IA ◄─────┤     (MP4, transcript final)    │
```

- **Recall.ai** = la couche "bot de réunion" : rejoint la visio, capte l'audio/vidéo, pousse les données. Une **seule API pour Meet + Teams + Zoom** (+ Webex, GoTo beta).
- **Gladia** (Solaria-3) = le moteur de transcription branché DANS Recall (`transcription_options.provider: "gladia"`), streaming + diarisation.
- Côté Agentova : un endpoint core-api qui crée le bot, un webhook receiver, et l'UI (transcript live + artefacts en fin de réunion, matière première pour les agents IA — comptes-rendus, actions, mémoire workspace).

### Pourquoi ce choix (critère par critère)

| Contrainte | Réponse Recall.ai + Gladia |
|---|---|
| **1. Zéro friction** | Join **à la volée par URL** via API — pas d'invitation email/agenda. L'utilisateur colle son lien, point. (Reste le clic "Admettre" de l'hôte, incompressible.) L'intégration calendrier Google/Microsoft existe en option pour l'auto-join des réunions planifiées — un plus futur, pas une obligation. |
| **2. Marque blanche** | Champ `bot_name` → le bot apparaît comme **"Agentova"**. Défaut neutre, zéro branding Recall. Vérifié docs officielles. |
| **3. Français + diarisation** | Gladia Solaria-3 : #1 revendiqué sur **enregistrements de production** FR/EN/DE/ES/IT, **3× moins d'erreurs de diarisation** sur du conversationnel, code-switching. Société française. |
| **4. Coût** | Recall : **0,50 $/h** facturé à la seconde (5 premières heures gratuites) + Gladia ~0,20-0,25 $/h diarisation incluse → **~700-750 $/mois pour 1 000 réunions d'1 h** (catalogue, remises volume négociables). |
| **5. RGPD** | Résidence **UE = Francfort** (`eu-central-1.recall.ai`, déploiement séparé). Gladia : résidence EU documentée. ⚠️ Recall reste une société US (CLOUD Act) — à mentionner au DPO. |
| **6. Manipulable/maintenable** | Le moteur STT est **interchangeable en 1 paramètre** (Gladia ↔ ElevenLabs Scribe ↔ Speechmatics ↔ AssemblyAI ↔ Deepgram ↔ native Recall) → toute décision de transcription est réversible sans toucher l'archi. Les bots = le cœur de métier de Recall (leader du marché, alimente une grande partie des produits existants) → le risque de casse des plateformes visio est porté par eux, pas par nous. Temps réel (websocket) ET post-call (webhook MP4/transcript). |

### Plan B : **Vexa** (levier de négociation + option souveraineté)
- Cloud managé : **0,50 $/h tout compris** (~500 $/mois pour 1 000 réunions) — le moins cher du marché.
- **Self-host gratuit (Apache 2.0, Docker/Helm/K8s)** avec Whisper auto-hébergé → l'audio ne quitte JAMAIS notre infra GCP. Argument commercial RGPD massue si un client l'exige.
- Contreparties : maturité moindre, couverture Zoom à confirmer (claim contradictoire), qualité FR = Whisper (bon, à valider), ops à notre charge en self-host (GPU).
- Usage recommandé : garder Vexa comme alternative crédible dans la négociation Recall, et comme trajectoire souveraineté si le besoin client émerge.

---

## 3. Ce qu'on a écarté — et pourquoi

| Option | Verdict | Raison (vérifiée sur sources primaires) |
|---|---|---|
| **Fireflies** | ❌ | Webhooks à l'échelle équipe = plan Enterprise + rôle Super Admin + avenant contractuel. Pas d'envoi de bot en marque blanche. |
| **tl;dv** | ❌ | API sans AUCUN endpoint d'envoi de bot (seul write = import de média). Bot "tl;dv Notetaker" non renommable. |
| **Otter** | ❌ | API réservée Enterprise via account manager, lecture/export uniquement. |
| → conclusion | | Ce sont des **concurrents finis**, pas des briques d'infrastructure. On ne construit pas notre note-taker dessus. |
| **Google Meet REST API** (sans bot) | 🟡 complément futur | Post-réunion uniquement, artefacts dans le Drive de l'organisateur, exige que l'enregistrement soit activé dans Meet + édition Workspace éligible chez CHAQUE client. Pas de temps réel, pas de marque blanche. (Piste à vérifier : déclenchement programmatique via `spaces.artifactConfig`.) |
| **Microsoft Graph** (Teams sans bot) | 🟡 complément futur | Transcripts/recordings post-call, dépend de 2 réglages admin du tenant CLIENT (`GraphAccessToTranscriptsDisabled`), ⚠️ verrouillage par défaut le **29/07/2026**. |
| **Extensions navigateur / scraping captions** | ❌ | Casse à chaque refonte de l'UI Meet = maintenance subie — contraire au critère 6. (Le Desktop SDK Recall, même prix que le bot, reste une carte si le clic "Admettre" devenait rédhibitoire.) |

---

## 4. Transcription : le podium et la stratégie

**"La meilleure" dépend de ce qu'on mesure** (source indépendante Coval : « les benchmarks vendeurs sont du marketing avec des mesures ») :

| Podium | Modèle | Chiffres | Verdict pour nous |
|---|---|---|---|
| 🏆 papier (WER brut) | **Microsoft MAI-Transcribe-1.5** (Azure) | bat Whisper-v3/Scribe v2/Gemini 3.1 Flash sur FLEURS ; v1 = 3,8 % WER moyen 25 langues | Pas intégré Recall → post-process manuel seulement. Référence de bench. |
| 🥈 papier | **ElevenLabs Scribe v2** | FR = 3,1 % WER FLEURS (v1) ; v2 Realtime sub-150 ms | ✅ intégré Recall → challenger n°1 au bench |
| 🏆 terrain (réunions) | **Gladia Solaria-3** | #1 revendiqué sur enregistrements de production FR, 3× moins d'erreurs de diarisation, code-switching | ✅ intégré Recall, société FR, UE, 0,20-0,25 $/h diarisation incluse → **choix par défaut** |

**Stratégie** : Gladia par défaut → **bench interne** sur 3-4 vraies réunions Agentova (même audio dans Gladia vs Scribe v2 vs native Recall, + MAI-Transcribe hors ligne comme référence) → on garde le gagnant. Le switch = 1 paramètre, décision réversible à tout moment. FLEURS = lecture studio ; nos réunions = bruit, chevauchements, jargon → **la diarisation (DER) pèse autant que le WER** dans la qualité perçue d'un compte-rendu.

---

## 5-bis. Recherche « coût minimum » (17/07/2026 — 23 sources primaires, prix vérifiés en direct, votes adversariaux 3 juges)

**Verdict : aucune architecture vérifiée ne bat Recall 0,50 $/h en restant 100 % fonctionnelle aujourd'hui.**

| Rang | Architecture | 100 h/mois | 500 h | 1000 h | Ce qui manque |
|---|---|---|---|---|---|
| 1 | **Attendee self-host GCP** (~0,09 $/h infra 4vCPU/4Gi + 0,04 $/h Groq) | 13 $ | 65 $ | 130 $ | + ops (150-300 $/mois) + diarisation + fiabilité de join NON prouvée. Licence Elastic 2.0 (self-host pour son propre SaaS = permis) |
| 2 | **Skribby + Groq** (0,35+0,05 vidéo + 0,04 STT = 0,44 $/h) | 44 $ | 220 $ | 440 $ | Diarisation absente de Groq (API-wide, vérifié) ; vendor early-stage sans certif, join non mesuré |
| 3 | **Recall + captions** (baseline) | 50 $ | 250 $ | 500 $ | ✅ Rien — seul stack 100 % fonctionnel à fiabilité PROUVÉE (notre 2/2 en 6-7 s) |
| 4 | MeetingBaaS (tokens : 1,25/h avec Gladia = 0,44-0,63 $/h + frais concurrence 199 $/mois dès ~6 bots simultanés) | 62 $ | 480 $ | 700 $ | Jamais sous le baseline tout compris. Le « 0,69 $/h flat » du marché est OBSOLÈTE (remplacé fin 2025). Diarisation incluse = réfuté |
| — | Vexa (cloud ET self-host) | — | — | — | ❌ **DISQUALIFIÉ critère fiabilité** : issues GitHub primaires — classe de panne join/callback « never diagnosed » (la nôtre du 16/07), bug de join #556 encore ouvert, Helm cassé sur tout déploiement stock jusqu'au 15/07 |

**Chiffres clés vérifiés** : Groq whisper-large-v3-turbo = **0,04 $/h** (12,5× moins cher que le baseline… mais zéro diarisation dans toute l'API) ; specs réelles d'un bot Attendee = 4 vCPU / 4 Gi par pod (exhumées du code `bot_pod_creator.py`) ; **point de bascule self-host ≈ 400-800 h/mois** (l'économie de 0,37 $/h doit d'abord absorber l'ops).

**Recommandation coût** : Recall reste « le moins cher qui marche » → à ~500 h/mois, lancer le **pilote Attendee self-host** (test de join type 16/07 + solution diarisation) ; Skribby+Groq = pilote optionnel pour gagner ~12 % avant ça. Questions restées ouvertes : `spaces.artifactConfig` Google (aucun claim survivant), remises volume Recall, diarisation low-cost (pyannote ou flux par participant).

## 5. Coûts à l'échelle (catalogue, juillet 2026)

| Volume mensuel | Recall.ai (bot) | Gladia (STT) | Total |
|---|---|---|---|
| 100 réunions × 1 h (POC/beta) | 50 $ | ~20-25 $ | **~75 $/mois** |
| 1 000 réunions × 1 h | 500 $ | ~200-250 $ | **~700-750 $/mois** |
| Comparaison Vexa cloud | — | — | ~500 $/mois tout compris |
| Comparaison MeetingBaaS | — | — | ~690 $/mois (transcription incluse) |

Facturation Recall à la seconde ; stockage >7 j : +0,05 $/h ; remises volume négociables ; **5 premières heures gratuites** (= POC à 0 €).

---

## 6. Risques & mitigations

| Risque | Mitigation |
|---|---|
| Clic "Admettre" de l'hôte vécu comme friction | UX claire ("Agentova demande à rejoindre…") ; option future : intégration calendrier pour auto-join des réunions planifiées ; carte Desktop SDK en dernier recours |
| Vendor lock-in Recall | L'API des bots est standard (URL in → webhooks out) ; Vexa/MeetingBaaS comme alternatives chaudes ; nos données (MP4/transcripts) stockées chez nous |
| Recall = société US (CLOUD Act) malgré la résidence Francfort | À documenter côté DPO ; trajectoire Vexa self-host si un client l'exige |
| Qualité FR réelle ≠ benchmarks | Bench interne avant tout engagement (cf. §4) |
| Taux d'échec de join du bot (non documenté) | À mesurer pendant le POC (question ouverte de la veille) |
| Verrouillage Graph Teams au 29/07/2026 | Sans impact sur l'archi bot (le bot est un participant, pas une API tenant) — c'est un argument DE PLUS pour les bots vs APIs natives |

---

## 7. Plan de mise en œuvre

1. **POC (0 €, ~1 journée)** — 5 h gratuites Recall : endpoint core-api `POST /startMeetingRecorder` + webhook receiver → coller un lien Meet → bot "Agentova" rejoint → transcript FR en direct. Valide l'UX d'admission ET la qualité Gladia d'un coup.
2. **Bench STT (~½ journée)** — 3-4 vraies réunions, Gladia vs Scribe v2 vs native Recall → chiffres à nous.
3. **Cadrage produit** — brief à Margot pour le design Figma (états : bot en attente d'admission, live transcript, compte-rendu) — la réunion du 13/07 prévoyait design APRÈS cadrage technique : ce doc + POC = le cadrage.
4. **MVP** — stockage des artefacts (workspace), génération du compte-rendu par les agents IA, permissions RBAC.
5. **Plus tard** — intégration calendrier (auto-join), Teams/Zoom (déjà couverts par la même API), canal natif Meet/Graph en enrichissement opportuniste.

## Questions encore ouvertes
1. UX exacte d'admission + taux d'échec de join (→ POC)
2. Benchmark FR réel (→ bench interne)
3. Prix négociés Recall à notre volume réel (→ contact commercial une fois le POC validé)
4. `spaces.artifactConfig` Meet : déclenchement natif programmatique possible ? (curiosité, non bloquant)
