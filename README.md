# 📚 Agentova — Docs partagées

Dépôt privé de partage de documents de travail entre Olivio et le CTO : veilles techniques, cadrages, audits, rapports d'avancement.

## Structure

| Dossier | Contenu |
|---|---|
| `veille/` | Veilles techniques et comparatifs (vendors, APIs, architectures) |
| `cadrage/` | Documents de cadrage avant développement |
| `audits/` | Audits (UX, sécurité, régressions, Sentry) |
| `rapports/` | Rapports d'avancement et comptes-rendus |

**Convention** : un fichier Markdown par sujet, daté dans le nom quand c'est un instantané (`*-YYYY-MM-DD.md`), sans date quand c'est un document vivant.

## Documents disponibles

- [`veille/systeme-visio-recorder-agentova.md`](veille/systeme-visio-recorder-agentova.md) — **Système d'enregistrement/transcription de visios** : architecture recommandée (Recall.ai + Gladia), plan B (Vexa), coûts, risques, plan POC→MVP. *Document de cadrage prêt pour lancer le design.*
- [`veille/veille-recorders-visio-2026-07-15.md`](veille/veille-recorders-visio-2026-07-15.md) — La veille détaillée qui fonde la recommandation (23 sources, prix vérifiés le 15/07/2026, comparatifs par famille).
- [`veille/attendee-self-host-vs-heberge.md`](veille/attendee-self-host-vs-heberge.md) — **Attendee : pourquoi le self-host coûte 4× moins cher** — décomposition du prix, point de bascule (~400-800 h/mois), conditions avant de basculer, plan de pilote à 0 €.
