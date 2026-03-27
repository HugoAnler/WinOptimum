# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

Script de post-installation Windows 11 25H2 pour systèmes à 1 Go de RAM. S'exécute via `FirstLogonCommands` (non-interactif, silencieux) ou manuellement en tant qu'administrateur.

## Fichiers

| Fichier | Rôle |
|---|---|
| `win11-setup.bat` | Script principal — **tout** le code d'optimisation post-installation est ici |
| `prerequis_WIN11.md` | **Document de référence obligatoire** — lire en premier avant toute modification |

Il n'existe pas d'`autounattend.xml` dans ce dépôt (fichier séparé, hors dépôt). Ne jamais y mettre de clés registre.

## Rôle de ce fichier

| Fichier | Rôle | Parsé par la CI |
|---|---|---|
| `prerequis_WIN11.md` | **Source de vérité unique** — toutes les règles techniques du script | ✅ Oui |
| `CLAUDE.md` | Instructions de travail pour l'IA — conventions, structure, navigation | ❌ Non |

> Ne jamais écrire dans `CLAUDE.md` des règles déjà présentes dans `prerequis_WIN11.md`. Toute règle absente de `prerequis_WIN11.md` n'est pas validée par la CI.

## Structure de `win11-setup.bat`

20 sections séquentielles — ordre imposé :

| Section | Contenu |
|---|---|
| 1 | Vérification droits admin (`openfiles`) |
| 2 | Point de restauration — **toujours en premier** |
| 3 | Suppression fichiers Panther (mot de passe en clair 25H2) |
| 4 | Pagefile fixe 6 Go — vérification 10 Go libres avant |
| 5 | Mémoire : compression, SysMain/Prefetch désactivés |
| 6 | Télémétrie / Copilot / Recall / IA 25H2 |
| 7 | AutoLoggers (DiagTrack, DiagLog, SQMLogger, WiFiSession, CloudExperienceHostOobe, NtfsLog, ReadyBoot, AppModel, LwtNetLog) |
| 8 | Windows Search — désactive web/Bing/Search Highlights (WSearch reste actif) |
| 9 | GameDVR, Delivery Optimization, Edge démarrage anticipé/arrière-plan (HKCU) |
| 10 | Politiques Windows Update |
| 11 | Vie privée, sécurité, WER, ContentDelivery, AppPrivacy |
| 11b | CDP, Clipboard (Win+V local activé, cloud désactivé), ContentDeliveryManager, HKCU privacy, Ink Workspace, Peernet, TCP sécurité, LLMNR, WPAD, SMBv1, Biométrie |
| 12 | Interface Win10 (taskbar, widgets, menu contextuel, hibernation) |
| 13 | CPU : `SystemResponsiveness=10`, PowerThrottling off, sécurité TCP/IP (`DisableIPSourceRouting`, `EnableICMPRedirect=0`) |
| 13b | Config avancée : bypass TPM/RAM, PasswordLess, NumLock, Snap Assist, menu alimentation, RDP conditionnel |
| 14 | Services → `Start=4` (90+ services, effectif après reboot) |
| 15 | `sc stop` immédiat + `sc failure DiagTrack` |
| 16 | Fichier `hosts` — blocage 57+ domaines télémétrie |
| 17a | GPO AppCompat (`DisableUAR`, `DisableInventory`, `DisablePCA`) |
| 17 | 73+ tâches planifiées désactivées (`schtasks /Change /Disable`) |
| 18 | Suppression apps UWP (PowerShell `Remove-AppxPackage`) |
| 19 | Vidage `C:\Windows\Prefetch\` |
| 19b | Vérification intégrité système (SFC/DISM) + restart Explorer |
| 20 | Résumé d'exécution dans le log + log de fin |

## Variables de configuration (tête du script)

```batch
set NEED_RDP=0      # 1 = conserver TermService/SessionEnv + autoriser RDP (app RemoteDesktop toujours supprimée)
set NEED_WEBCAM=0   # défini mais sans effet — WindowsCamera toujours supprimée (réservé usage futur)
set NEED_BT=0       # 1 = conserver BthAvctpSvc (Bluetooth audio)
set NEED_PRINTER=1  # 0 = désactiver Spooler (pas d'imprimante)
set BLOCK_ADOBE=0   # 1 = activer le bloc Adobe dans hosts
```

## Conventions de code

- Chaque section se termine par une ligne `echo [%date% %time%] Section N : ... >> "%LOG%"`
- Toutes les commandes redirigent vers `>nul 2>&1`
- Les services conditionnels utilisent `if "%NEED_X%"=="0" reg add ...`
- Les tâches planifiées avec espaces dans le chemin → appels `schtasks` individuels (pas de boucle `for`)
- Les clés HKCU s'appliquent à l'utilisateur courant (contexte FirstLogonCommands = premier utilisateur)
