# Optimisation Windows

> Script de post-installation Windows 11 25H2 — optimisé pour systèmes à faibles ressources

---

## Description

**WinOptimum** est un toolkit de debloat et d'optimisation de Windows 11 25H2 conçu pour les machines à ressources limitées (1 Go RAM). Il supprime les applications inutiles, désactive la télémétrie, bloque Copilot/Recall/IA 25H2, optimise la mémoire et applique plus de 100 réglages registre — tout en conservant la sécurité et les fonctionnalités essentielles de Windows.

Le script est pensé pour un **déploiement non assisté** : il s'intègre dans un fichier `autounattend.xml` via la section `FirstLogonCommands`, et s'exécute automatiquement au premier démarrage après installation. Il peut également être lancé manuellement en tant qu'administrateur sur un Windows déjà installé.

Toutes les actions sont journalisées dans `C:\Windows\Temp\win11-setup.log`. Un résumé d'exécution est écrit en fin de log.

---

## Prérequis système

| Composant | Requis |
|---|---|
| Système d'exploitation | Windows 11 25H2 |
| Firmware | UEFI |
| Sécurité | TPM 2.0 |
| RAM | 1 Go minimum |
| Espace disque libre | 10 Go minimum (pour le pagefile fixe) |
| Droits | Administrateur local |

---

## Fonctionnalités

Le script est organisé en **20 sections** qui s'exécutent séquentiellement :

| Section | Action |
|---|---|
| 1 | Vérification des droits administrateur — arrêt immédiat si non admin |
| 2 | Création d'un point de restauration système (obligatoire avant toute modification) |
| 3 | Suppression des fichiers Panther (`C:\Windows\Panther`) — sécurité : mot de passe admin en clair (25H2) |
| 4 | Pagefile fixe à 6 Go sur C: (uniquement si ≥ 10 Go d'espace libre) |
| 5 | Optimisation mémoire : compression activée, Prefetch désactivé, SysMain arrêté, opt-out télémétrie PowerShell |
| 6 | Zéro télémétrie : 20+ clés registre — Copilot, Recall, DiagTrack, IA 25H2, Spotlight, Cloud Search, collecte Microsoft |
| 7 | AutoLoggers désactivés : DiagTrack, DiagLog, SQMLogger, WiFiSession, NtfsLog, ReadyBoot, AppModel, LwtNetLog, CloudExperienceHostOobe |
| 8 | Windows Search : désactivation recherche web, Bing, Search Highlights animés (WSearch reste actif) |
| 9 | GameDVR désactivé, Delivery Optimization désactivé, Edge démarrage anticipé/arrière-plan off (HKCU) |
| 10 | Politiques Windows Update : redémarrage rapide, réseau mesuré autorisé, notifications conservées |
| 11 | Vie privée & sécurité : Cortana, ID publicitaire, historique d'activité, géolocalisation, RemoteAssistance, saisie, AutoPlay, contenu cloud, cartes hors ligne, modèle vocal |
| 11b | CDP, Presse-papiers local Win+V activé (cloud/cross-device désactivé), ContentDeliveryManager, HKCU privacy, LLMNR, WPAD, SMBv1, Biométrie |
| 12 | Interface Win10 : barre à gauche (HKLM), widgets supprimés, Teams/Copilot masqués, menu contextuel classique, "Ce PC" par défaut, Galerie/Réseau masqués, son démarrage off, hibernation off, Fast Startup off — centre de notifications conservé |
| 13 | Priorité CPU : `SystemResponsiveness = 10`, PowerThrottling off, TCP security |
| 14 | 90+ services désactivés via registre (`Start=4`) |
| 15 | Arrêt immédiat des services désactivés + `sc failure DiagTrack` |
| 16 | Fichier `hosts` : 57+ domaines de télémétrie bloqués en `0.0.0.0` (+ bloc Adobe optionnel) |
| 17a | GPO AppCompat : `DisableUAR`, `DisableInventory`, `DisablePCA`, `AITEnable=0` |
| 17 | 73+ tâches planifiées désactivées (télémétrie, CEIP, Recall, Copilot, Xbox, IA 25H2, MDM, Work Folders) |
| 18 | Suppression de 73+ applications bloatware (UWP) via PowerShell |
| 19 | Nettoyage du dossier `C:\Windows\Prefetch` |
| 19b | Vérification intégrité système (SFC/DISM) + restart Explorer |
| 20 | Résumé d'exécution dans le log + fin du script |

---

## Ce qui est toujours conservé

Le script ne touche jamais aux éléments suivants, considérés comme essentiels :

**Applications préservées :**
- Microsoft Edge
- Photos
- OneDrive
- Notepad (Bloc-notes)
- Terminal Windows
- DesktopAppInstaller (winget)
- ScreenSketch (capture d'écran Win+Shift+S)
- VCLibs, UI.Xaml, NET.Native (runtimes)

**Fonctionnalités UI conservées :**
- Centre de notifications (Action Center)
- Écran de verrouillage et Spotlight

**Services toujours actifs :**
- `WSearch` — Windows Search (indexation)
- `WinDefend` — Windows Defender
- `wuauserv` — Windows Update
- `RpcSs` — Remote Procedure Call
- `PlugPlay` — Plug and Play
- `WlanSvc` — Wi-Fi
- `AppXSvc` — Store et winget en dépendent
- `seclogon` — installeurs tiers en dépendent
- `TokenBroker` — OneDrive et Edge en dépendent
- `OneSyncSvc` — OneDrive en dépend
- `wlidsvc` — Microsoft Account (OneDrive, Edge)

---

## Configuration

Cinq variables sont disponibles en tête du script pour adapter le comportement selon l'usage :

| Variable | Valeur par défaut | Description |
|---|---|---|
| `LOG` | `C:\Windows\Temp\win11-setup.log` | Chemin du fichier de journal |
| `BLOCK_ADOBE` | `0` | `1` = bloquer les domaines Adobe dans le fichier hosts (désactivé par défaut) |
| `NEED_RDP` | `0` | `1` = conserver les services `TermService`/`SessionEnv` et autoriser les connexions RDP entrantes — *l'application RemoteDesktop est toujours supprimée* |
| `NEED_WEBCAM` | `0` | Variable définie mais sans effet : `WindowsCamera` est toujours supprimée — réservée pour usage futur |
| `NEED_BT` | `0` | `1` = conserver le service Bluetooth audio `BthAvctpSvc` (sinon désactivé) |
| `NEED_PRINTER` | `1` | `0` = désactiver le service Spooler (si aucune imprimante) |

Pour modifier une option, ouvrir `win11-setup.bat` et changer la valeur correspondante dans la section de configuration en tête de fichier.

---

## Utilisation

### Mode 1 — Déploiement automatisé (recommandé)

Intégrer le script dans un fichier `autounattend.xml` via la section `oobeSystem` / `FirstLogonCommands` :

```xml
<FirstLogonCommands>
  <SynchronousCommand wcm:action="add">
    <Order>1</Order>
    <CommandLine>cmd /c "D:\win11-setup.bat"</CommandLine>
    <Description>Optimisation Windows 11</Description>
    <RequiresUserInput>false</RequiresUserInput>
  </SynchronousCommand>
</FirstLogonCommands>
```

Copier `win11-setup.bat` sur la clé USB d'installation et référencer son chemin dans la commande ci-dessus.

### Mode 2 — Exécution manuelle

Sur un Windows 11 déjà installé :

1. Faire un clic droit sur `win11-setup.bat`
2. Sélectionner **"Exécuter en tant qu'administrateur"**
3. Le script s'exécute silencieusement (aucune invite, aucun redémarrage automatique)
4. Consulter le log à la fin : `C:\Windows\Temp\win11-setup.log`

### Mode 3 — Optimisation hors-ligne d'une image WIM

Pour pré-intégrer les optimisations dans une image Windows avant déploiement :

1. Ouvrir une invite de commandes en tant qu'administrateur
2. Exécuter `ApplyScriptWim.cmd` et suivre les invites (répertoire de montage, options)
3. Le script monte l'image, charge les ruches registre, applique les mêmes réglages que `win11-setup.bat` (mémoire, télémétrie, services, tâches, hosts…), puis démonte proprement
4. Le log est écrit dans `optiwim.log` à côté du script

---

## Statistiques

| Catégorie | Quantité |
|---|---|
| Clés registre modifiées | 135+ |
| Services désactivés | 90+ |
| Tâches planifiées désactivées | 73+ |
| Applications (UWP) supprimées | 73+ |
| Domaines de télémétrie bloqués | 57+ |
| Options de configuration | 5 |

---

## Fichiers du projet

| Fichier | Description |
|---|---|
| `win11-setup.bat` | Script principal d'optimisation post-installation (~1 025 lignes) |
| `ApplyScriptWim.cmd` | Outil d'optimisation hors-ligne d'une image WIM avant installation (~920 lignes) |
| `prerequis_WIN11.md` | Document de spécification : règles de conception, listes d'apps/services/tâches, contraintes techniques |
| `CLAUDE.md` | Fichier de configuration interne — structure du script, règles absolues, conventions |

---

## Avertissements

- **Point de restauration** : le script en crée un automatiquement en section 2. Ne jamais l'ignorer ou le désactiver.
- **Test en VM** : tester sur une machine virtuelle avant tout déploiement en production.
- **Options conditionnelles** : si vous avez besoin de Bureau à distance, d'une webcam, du Bluetooth audio ou d'une imprimante, ajuster les variables `NEED_RDP`, `NEED_WEBCAM`, `NEED_BT`, `NEED_PRINTER` avant l'exécution.
- **Contexte FirstLogonCommands** : certaines limitations WMI et PowerShell s'appliquent dans ce contexte d'exécution — le script est conçu pour les contourner proprement.
- **Windows Defender conservé** : aucune modification de la sécurité antivirus n'est effectuée (`SubmitSamplesConsent` jamais à 2).
- **Vérification intégrité** : SFC et DISM sont exécutés en fin de script pour vérifier l'intégrité du système après les modifications.
