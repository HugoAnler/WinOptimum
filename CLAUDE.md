# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

Script de post-installation Windows 11 25H2 pour systèmes à 1 Go de RAM. S'exécute via `FirstLogonCommands` (non-interactif, silencieux) ou manuellement en tant qu'administrateur.

## Fichiers

| Fichier | Rôle |
|---|---|
| `win11-setup.bat` | Script principal — **tout** le code est ici |
| `prerequis_WIN11.md` | **Document de référence obligatoire** — lire en premier avant toute modification |

Il n'existe pas d'`autounattend.xml` dans ce dépôt (fichier séparé, hors dépôt). Ne jamais y mettre de clés registre.

## Règles absolues (extraites de `prerequis_WIN11.md`)

### Ne jamais désactiver ces services
`WSearch`, `WinDefend`, `wuauserv`, `RpcSs`, `PlugPlay`, `WlanSvc`, `AppXSvc`, `seclogon`, `TokenBroker`, `OneSyncSvc`, `wlidsvc`

### Ne jamais supprimer ces apps
`Microsoft.MicrosoftEdge*`, `Microsoft.Windows.Photos`, `Microsoft.OneDriveSync`, `Microsoft.WindowsNotepad`, `Microsoft.WindowsTerminal`, `Microsoft.DesktopAppInstaller`, `Microsoft.VCLibs.*`, `Microsoft.UI.Xaml.*`, `Microsoft.NET.Native.*`, `Microsoft.ScreenSketch`

### Interdictions techniques
- **WMI interdit** : `wmic`, `Set-WmiInstance`, `Win32_ComputerSystem.Put()` — token COM absent en `FirstLogonCommands`, arrêt silencieux du script
- **PowerShell** : toujours avec `-NonInteractive` + `try/catch` — sinon exit code ≠ 0 rompt le batch parent
- **Registre en priorité** : toujours `reg add` plutôt que PowerShell/WMI quand la clé existe
- **Pas de `PAUSE` ni `shutdown /r`** : script silencieux
- **`SubmitSamplesConsent` jamais à 2** : affaiblit Defender
- **`Win32PrioritySeparation` jamais modifié**
- **DNS sécurisé Edge jamais modifié** : `BuiltInDnsClientEnabled`, `DnsOverHttpsMode`, `DnsOverHttpsTemplates` — choix utilisateur
- **Pas de doublons dans la liste de services** : erreur silencieuse dans la boucle `for`

## Structure de `win11-setup.bat`

20 sections séquentielles — ordre imposé :

| Section | Contenu |
|---|---|
| 1 | Vérification droits admin (`openfiles`) |
| 2 | Point de restauration — **toujours en premier** |
| 3 | Suppression fichiers Panther (mot de passe en clair 25H2) |
| 4 | Pagefile fixe 6 Go — vérification 10 Go libres avant |
| 5 | Mémoire : compression, SysMain/Prefetch désactivés, `DisablePagingExecutive=1` (noyau en RAM) |
| 6 | Télémétrie / Copilot / Recall / IA 25H2 + OOBE privacy + `AllowOnlineTips=0` |
| 7 | AutoLoggers (DiagTrack, DiagLog, SQMLogger, WiFiSession, AppModel, LwtNetLog) |
| 8 | Windows Search — désactive web/Bing (WSearch reste actif) |
| 9 | GameDVR (flags complets), Delivery Optimization, messagerie cloud |
| 10 | Politiques Windows Update |
| 11 | Vie privée, sécurité, WER, ContentDelivery, AppPrivacy |
| 11b | CDP, Cloud Clipboard, ContentDeliveryManager, HKCU privacy, Ink Workspace, Peernet, TCP sécurité |
| 12 | Interface Win10 (taskbar, widgets, menu contextuel, hibernation, `ShowInfoTip=0`) |
| 13 | CPU : `SystemResponsiveness=10`, sécurité TCP/IP (`DisableIPSourceRouting`, `EnableICMPRedirect=0`, protection SYN flood) |
| 14 | Services → `Start=4` (89+ services, effectif après reboot) |
| 15 | `sc stop` immédiat + `sc failure DiagTrack` |
| 16 | Fichier `hosts` — blocage 58+ domaines télémétrie |
| 17a | GPO AppCompat (`DisableUAR`, `DisableInventory`, `DisablePCA`) |
| 17 | 95+ tâches planifiées désactivées (`schtasks /Change /Disable`) |
| 18 | Suppression apps UWP (PowerShell `Remove-AppxPackage`) dont `microsoft.windowscommunicationsapps` |
| 19 | Vidage `C:\Windows\Prefetch\` |
| 19b | Vérification intégrité système (SFC/DISM) + restart Explorer |
| 20 | Résumé d'exécution dans le log + log de fin |

## Variables de configuration (tête du script)

```batch
set NEED_RDP=0      # 1 = conserver Microsoft.RemoteDesktop
set NEED_WEBCAM=0   # 1 = conserver Microsoft.WindowsCamera
set NEED_BT=0       # 1 = conserver BthAvctpSvc (Bluetooth audio)
set BLOCK_ADOBE=0   # 1 = activer le bloc Adobe dans hosts
```

## Conventions de code

- Chaque section se termine par une ligne `echo [%date% %time%] Section N : ... >> "%LOG%"`
- Toutes les commandes redirigent vers `>nul 2>&1`
- Les services conditionnels utilisent `if "%NEED_X%"=="0" reg add ...`
- Les tâches planifiées avec espaces dans le chemin → appels `schtasks` individuels (pas de boucle `for`)
- Les clés HKCU s'appliquent à l'utilisateur courant (contexte FirstLogonCommands = premier utilisateur)
