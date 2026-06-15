# Reek — Scanner Anti-Cheat

Scanner forensique desktop pour Windows. Détecte les traces de cheats à travers 35 sections de vérification en utilisant les artefacts natifs de Windows.

## Démo

[![Démo Reek](https://img.youtube.com/vi/15LxpykwNKQ/maxresdefault.jpg)](https://youtu.be/15LxpykwNKQ)

## Ce qu'il vérifie

| Catégorie | Sections |
|-----------|----------|
| Artefacts forensiques | Prefetch, Amcache, Shimcache, UserAssist, BAM, DAM, Jump Lists |
| Fichiers & dossiers | Fichiers récents, Temp, Téléchargements, Corbeille, Dossiers connus |
| Persistance | Run/RunOnce registre, Services, Dossiers Startup |
| Processus | Processus actifs, DLL chargées, injections, handles |
| Drivers | Drivers non signés, drivers récents, services noyau |
| Réseau | Cache DNS, connexions TCP, règles pare-feu, fichier hosts |
| Système | Intégrité Windows Defender, virtualisation, journaux d'événements |
| Outils | Débogueurs, éditeurs mémoire, sniffers réseau |

## Stack

- **C#** + WinForms + WebView2 — fenêtre desktop borderless
- **PowerShell** — scanner forensique 35 sections (`AntiCheat_AIO.ps1`)
- **HTML/CSS/JS** — interface liquid glass rendue dans WebView2

## Build

Nécessite .NET Framework 4 et le runtime WebView2.

```
powershell -ExecutionPolicy Bypass -File compiler.ps1
```

Les DLLs (`Microsoft.Web.WebView2.*.dll`, `WebView2Loader.dll`) doivent être présentes dans le même dossier.

## Niveaux d'alerte

| Niveau | Signification |
|--------|---------------|
| `[HIGH]` | Indicateur fort de présence de cheat |
| `[MEDIUM]` | Suspect — vérification manuelle recommandée |
| `[LOW]` | Informatif |
| `[OK]` | Propre |

Les résultats et l'historique des scans sont stockés localement dans le localStorage WebView2.
