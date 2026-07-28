# Cadrage — Capture vidéo des réunions : extension Chromium auto-onglet

**Date** : 2026-07-28 · **Auteur** : Olivio · **Statut** : à arbitrer (Samy)
**Périmètre** : Hub Réunion (Elisa) — saas-agentova-ai

---

## 1. Contexte et existant (livré)

L'enregistrement natif Meet est indisponible sur notre tenant (« Vous n'êtes
pas autorisé » — dépend du plan Workspace) et les URLs galerie Recall sont
périssables et recomposées. **Décision produit du 28/07 : la capture par
l'utilisateur est la SEULE source vidéo du Hub Réunion.**

Ce qui tourne déjà (local, branche `feat/elisa-meetings`) :

- Bouton **Capturer** sur la liste, visible uniquement pendant une réunion en
  direct ; `getDisplayMedia` → l'utilisateur choisit l'onglet Meet (Chromium)
  ou une fenêtre (Safari/Firefox).
- MediaRecorder MP4/H.264 en priorité (WebM en repli), 4 Mbps.
- **Upload multipart à la volée** vers Wasabi (parts 8 Mo pendant
  l'enregistrement, complete serveur via ListParts) ; échelle de secours
  PUT unique → téléchargement local. Sentry sur chaque bascule.
- Vignette/player = capture uniquement ; sinon skeleton (traitement) ou
  cover-titre. Bouton Télécharger.
- Interrupteur workspace « Capture vidéo des réunions » (écran
  Automatisation).
- Capture **muette** (audio d'onglet non partagé) : l'audio bot Recall est
  muxé dessus côté serveur (ffmpeg, alignement par la fin, best-effort).

**Limites du sélecteur manuel** : l'utilisateur peut se tromper d'onglet,
oublier la case « Partager l'audio », ou oublier de cliquer Capturer.

## 2. Proposition : extension Chromium (auto-onglet)

Une extension Chrome/Edge MV3 interne qui supprime le sélecteur :

| Brique | Détail |
|---|---|
| `chrome.tabCapture` | Capture DIRECTE de l'onglet Meet/Teams/Zoom, avec audio, sans sélecteur |
| Détection d'onglet | Par URL (`meet.google.com/xxx` == `meeting_url` de la réunion) — zéro choix utilisateur |
| Déclenchement | Message du saas (externally_connectable) quand le bot passe `in_call_recording`, si le réglage workspace est actif |
| Upload | Même pipeline multipart existant (le service worker de l'extension poste au saas, ou réutilise les onCalls avec le token workspace) |
| Distribution | **Force-install via la console Google Workspace du client** (policy `ExtensionInstallForcelist`) — pas de Chrome Web Store public nécessaire |
| Consentement | La checkbox workspace + bandeau Chrome natif « partage cet onglet » |

**Ce que ça change** : zéro clic pendant la réunion (la capture démarre et
s'arrête avec le bot), audio d'onglet toujours présent (plus besoin du mux),
plus d'erreur d'onglet.

**Ce que ça ne couvre pas** : Safari et Firefox (pas de `tabCapture`) — le
flux actuel (bouton Capturer + sélecteur) **reste le chemin** pour eux ;
c'est déjà en place.

## 3. Coûts / risques

- **Dev** : ~3-5 j (MV3 service worker + handshake saas + reprise du pipeline
  multipart) + revue sécurité.
- **Distribution** : force-install = chaque client Workspace doit pousser la
  policy (doc d'onboarding à écrire) ; sinon Web Store unlisted (revue Google,
  délais).
- **Permissions** : `tabCapture`, `tabs` sur les 3 domaines visio — à
  documenter RGPD (la capture reste dans le navigateur du client jusqu'à
  l'upload Wasabi UE).
- **Risque produit** : les clients non-Chromium n'auront jamais l'auto — le
  manuel doit rester visible et assumé dans l'UX.
- **Opportunité coût** : avec la capture utilisateur comme source vidéo, les
  bots Recall peuvent passer en **audio-only** (~0,37 $/h au lieu de
  ~0,70 $/h) — à valider après fiabilisation de l'extension.

## 4. Décisions demandées

1. **GO/NO-GO extension Chromium** (V1 ciblée : Google Meet d'abord ?).
2. Distribution : force-install Workspace only, ou aussi Web Store unlisted ?
3. Bots Recall audio-only une fois l'extension fiable (économie ~47 %) ?
4. Confirmer le plan Google Workspace du tenant (l'enregistrement natif Meet
   reste un bonus opportuniste si le plan le permet — test : meet.new).
