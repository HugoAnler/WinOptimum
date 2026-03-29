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
| 6 | Télémétrie / Copilot / Recall / IA 25H2 / EventTranscript / MRT / TailoredExperiences / DesktopAnalytics |
| 7 | AutoLoggers (DiagTrack, DiagLog, SQMLogger, WiFiSession, CloudExperienceHostOobe, NtfsLog, ReadyBoot, AppModel, LwtNetLog) |
| 8 | Windows Search — désactive web/Bing/Search Highlights (WSearch reste actif) |
| 9 | GameDVR, Delivery Optimization, Edge démarrage anticipé/arrière-plan (HKCU) |
| 10 | Politiques Windows Update |
| 11 | Vie privée, sécurité, WER, ContentDelivery, AppPrivacy |
| 11b | CDP, Clipboard (Win+V local activé, cloud désactivé), ContentDeliveryManager, HKCU privacy, Spotlight suggestions (ActionCenter/Settings/TailoredExperiences HKCU), ShowSyncProviderNotifications=0, PreventDeviceMetadataFromNetwork=1, Ink Workspace, Peernet, TCP sécurité, LLMNR, WPAD, SMBv1, Biométrie |
| 12 | Interface Win10 (taskbar, widgets, menu contextuel, hibernation) |
| 13 | CPU : `SystemResponsiveness=10`, PowerThrottling off, sécurité TCP/IP (`DisableIPSourceRouting`, `EnableICMPRedirect=0`), `DisableBandwidthThrottling=1` (LanmanWorkstation), TCP Keep-Alive (`KeepAliveTime=300000`, `KeepAliveInterval=1000`) |
| 13b | Config avancée : bypass TPM/RAM, PasswordLess, NumLock, Snap Assist, menu alimentation, RDP conditionnel |
| 14 | Services → `Start=4` (95+ services, effectif après reboot) dont WinRM, RasAuto, RasMan, iphlpsvc, IKEEXT, PolicyAgent, fhsvc, AxInstSV, MSiSCSI, TextInputManagementService, GraphicsPerfSvc, NcdAutoSetup, lmhosts, CertPropSvc |
| 15 | `sc stop` immédiat (incluant les 14 nouveaux services v2+v3) + `sc failure DiagTrack` |
| 16 | Fichier `hosts` — blocage 63+ domaines télémétrie dont `eu/us.vortex-win.data.microsoft.com`, `inference.microsoft.com`, `arc.msn.com`, `redir.metaservices.microsoft.com`, `i1.services.social.microsoft.com` |
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

## CI / Validation automatique

| Fichier | Rôle |
|---|---|
| `.github/workflows/validate.yml` | Déclenche `validate_bat.py` sur push/PR vers `Update` et `main` |
| `.github/scripts/validate_bat.py` | 35 tests statiques — règles lues depuis `prerequis_WIN11.md` + checks hardcodés + rapport GitHub Step Summary |

Tests clés : valeurs registre interdites, services protégés, apps protégées, WU intouché, hosts WU jamais bloqués, structure 20 sections, optimisations obligatoires, services v2/v3 désactivés, hosts v2/v3 bloqués, apps v3 présentes.

## Conventions de code

- Chaque section se termine par une ligne `echo [%date% %time%] Section N : ... >> "%LOG%"`
- Toutes les commandes redirigent vers `>nul 2>&1`
- Les services conditionnels utilisent `if "%NEED_X%"=="0" reg add ...`
- Les tâches planifiées avec espaces dans le chemin → appels `schtasks` individuels (pas de boucle `for`)
- Les clés HKCU s'appliquent à l'utilisateur courant (contexte FirstLogonCommands = premier utilisateur)

## Règles opérationnelles — Git et validation

Ces règles sont issues de problèmes concrets rencontrés lors de modifications sur ce dépôt. Elles sont **obligatoires**.

### 1. Toujours pousser les fichiers volumineux via `git` directement

Les outils MCP (`create_or_update_file`) ne peuvent pas gérer fiablement des fichiers de 90 Ko+ avec des caractères Unicode. Le contenu est tronqué ou corrompu silencieusement.

**Règle** : pour `win11-setup.bat`, `validate_bat.py` et tout fichier > 10 Ko, utiliser exclusivement :
```bash
git add <fichier>
git commit -m "message"
git push -u origin <branche>
```
Ne jamais passer le contenu d'un grand fichier en paramètre inline d'un outil MCP ou d'un agent.

### 2. Ne jamais lancer d'agents en arrière-plan sur les mêmes fichiers

Un agent lancé en arrière-plan (`run_in_background`) peut lire un état stale du dépôt (avant un commit récent) et pousser une version corrompue ou périmée du fichier, écrasant les corrections.

**Règle** : toute opération qui lit, modifie ou pousse `win11-setup.bat` ou `validate_bat.py` doit être effectuée **séquentiellement dans la session principale**. Aucun agent parallèle ou arrière-plan pour ces fichiers.

### 3. Exécuter le validateur avant tout premier push

Une clé registre interdite (ex. `DisableWindowsSpotlightFeatures`) qui passe inaperçue en local fait échouer la CI. Corriger en CI = commits supplémentaires inutiles.

**Règle** : avant le premier `git push` de toute modification de `win11-setup.bat`, toujours exécuter :
```bash
python3 .github/scripts/validate_bat.py
```
et vérifier que tous les tests passent (0 FAIL). Ne pousser qu'après validation locale réussie.
