# Prérequis & Contraintes Obligatoires — Windows 11 Setup

> ⚠️ Ce fichier définit les règles **non-négociables** à respecter dans le script. Il doit être lu en premier à chaque usage de la skill.
>  **Cible active: Windows 11 25H2 — 1 Go RAM — TPM 2.0 natif — sans bypass**

---

## ✅ Apps TOUJOURS conservées

Ces apps ne doivent **jamais** être supprimées, peu importe le profil :

| App                              | Raison                        |
|----------------------------------|-------------------------------|
| `Microsoft.MicrosoftEdge*`       | Navigateur principal demandé  |
| `Microsoft.Windows.Photos`       | Visionneuse photos demandée   |
| `Microsoft.OneDriveSync` / OneDrive | Stockage cloud demandé     |
| `Microsoft.WindowsNotepad`       | Éditeur texte léger           |
| `Microsoft.WindowsTerminal`      | Terminal système              |
| `Microsoft.DesktopAppInstaller`  | winget (gestionnaire paquets) |
| `Microsoft.VCLibs.*`             | Dépendance runtime critique   |
| `Microsoft.UI.Xaml.*`            | Dépendance runtime critique   |
| `Microsoft.NET.Native.*`         | Dépendance runtime critique   |
| `Microsoft.ScreenSketch`         | Capture d'écran Win+Shift+S   |

---

## ❌ Apps TOUJOURS supprimées

| App                                        | Raison                            |
|--------------------------------------------|-----------------------------------|
| `7EE7776C.LinkedInforWindows`              | Réseau social tiers               |
| `Microsoft.LinkedIn`                       | Réseau social tiers (alias 25H2)  |
| `Facebook.Facebook`                        | Réseau social tiers               |
| `MSTeams` / `Microsoft.Teams`              | Bloatware communication           |
| `Microsoft.3DBuilder`                      | Inutile                           |
| `Microsoft.3DViewer`                       | Inutile                           |
| `Microsoft.Microsoft3DViewer`              | Inutile (alias nom 25H2)          |
| `Microsoft.549981C3F5F10`                  | Cortana                           |
| `Microsoft.Advertising.Xaml`              | Publicité Microsoft               |
| `Microsoft.BingNews`                       | Actualités Bing                   |
| `Microsoft.BingWeather`                    | Météo Bing                        |
| `Microsoft.BingSearch`                     | Recherche Bing                    |
| `Microsoft.Copilot`                        | IA Microsoft — 25H2               |
| `*Windows.Recall*` (joker)                 | Recall IA — 25H2                  |
| `Microsoft.GetHelp`                        | Aide Microsoft en ligne           |
| `Microsoft.Getstarted`                     | Tips / démarrage                  |
| `Microsoft.GamingApp`                      | Gaming                            |
| `Microsoft.Messaging`                      | SMS/Messagerie                    |
| `Microsoft.MicrosoftOfficeHub`             | Hub Office                        |
| `Microsoft.MicrosoftSolitaireCollection`   | Jeux                              |
| `Microsoft.MicrosoftStickyNotes`           | Notes autocollantes               |
| `Microsoft.MixedReality.Portal`            | Réalité mixte                     |
| `Microsoft.NetworkSpeedTest`               | Test réseau                       |
| `Microsoft.News`                           | Actualités                        |
| `Microsoft.Office.OneNote`                 | OneNote                           |
| `Microsoft.Office.Sway`                    | Sway                              |
| `Microsoft.OneConnect`                     | Mobile broadband                  |
| `Microsoft.OutlookForWindows`              | Nouvel Outlook — 25H2             |
| `Microsoft.People`                         | Contacts                          |
| `Microsoft.PowerAutomateDesktop`           | Automatisation                    |
| `Microsoft.Print3D`                        | Impression 3D                     |
| `Microsoft.BioEnrollment`                  | Enrôlement biométrique            |
| `Microsoft.RemoteDesktop`                  | Bureau à distance                 |

| `Microsoft.SkypeApp`                       | Skype                             |
| `Microsoft.Todos`                          | Todo list                         |
| `Microsoft.Wallet`                         | Portefeuille                      |
| `Microsoft.Whiteboard`                     | Tableau blanc                     |
| `Microsoft.WidgetsPlatformRuntime`         | Widgets                           |
| `Microsoft.WindowsAlarms`                  | Alarmes                           |
| `Microsoft.WindowsCamera`                  | Caméra                            |
| `Microsoft.WindowsCalculator`              | Calculatrice Windows              |
| `Microsoft.WindowsFeedbackHub`             | Feedback Microsoft                |
| `Microsoft.WindowsMaps`                    | Cartes                            |
| `Microsoft.WindowsSoundRecorder`           | Enregistreur audio                |
| `Microsoft.Windows.DevHome`                | Dev Home — 25H2                   |
| `Microsoft.Windows.NarratorQuickStart`     | Narrateur                         |
| `Microsoft.Windows.ParentalControls`       | Contrôle parental                 |
| `Microsoft.Windows.SecureAssessmentBrowser`| Navigateur évaluation             |
| `Microsoft.XboxApp`                        | Xbox                              |
| `Microsoft.Xbox.TCUI`                      | Xbox UI                           |
| `Microsoft.XboxGameOverlay`                | Xbox overlay                      |
| `Microsoft.XboxGamingOverlay`              | Xbox gaming overlay               |
| `Microsoft.XboxIdentityProvider`           | Xbox identity                     |
| `Microsoft.XboxSpeechToTextOverlay`        | Xbox speech                       |
| `Microsoft.ZuneMusic`                      | Groove Music                      |
| `Microsoft.ZuneVideo`                      | Films & TV                        |
| `MicrosoftWindows.CrossDevice`             | Cross-device                      |
| `MicrosoftCorporationII.QuickAssist`       | Assistance rapide                 |
| `MicrosoftCorporationII.MicrosoftFamily`   | Famille Microsoft                 |
| `MicrosoftCorporationII.PhoneLink`         | Phone Link (nouveau nom 22H2+)    |
| `Microsoft.YourPhone`                      | Phone Link (ancien nom)           |
| `Microsoft.Windows.Ai.Copilot.Provider`    | Provider Copilot IA               |
| `Microsoft.WindowsRecall`                  | Recall IA (nom exact package)     |
| `Microsoft.RecallApp`                      | Recall IA (nom alternatif)        |
| `Netflix`                                  | Streaming tiers                   |
| `SpotifyAB.SpotifyMusic`                   | Streaming musique tiers           |
| `clipchamp.Clipchamp`                      | Éditeur vidéo                     |
| `king.com.*` (joker)                       | Jeux CandyCrush & co              |
| `Microsoft.WindowsCommunicationsApps`      | Mail & Calendrier UWP             |
| `Microsoft.Windows.HolographicFirstRun`    | OOBE HoloLens — inutile sur PC    |

> ⚠️ `Microsoft.RemoteDesktop` et `Microsoft.WindowsCamera` sont supprimés inconditionnellement dans la boucle APPLIST — `NEED_RDP` et `NEED_WEBCAM` n'affectent plus la suppression de ces apps (ils contrôlent uniquement `BthAvctpSvc` pour le Bluetooth).

---

## ✅ Services TOUJOURS conservés

Ces services ne doivent **jamais** être désactivés :

| Service     | Raison                                                        |
|-------------|---------------------------------------------------------------|
| `WSearch`   | Recherche Windows — toujours actif (tous profils, toute RAM)  |
| `WinDefend` | Windows Defender — sécurité                                   |
| `wuauserv`  | Windows Update — patches sécurité                             |
| `RpcSs`     | RPC — critique pour le système                                |
| `PlugPlay`  | Plug and Play — détection matériel                            |
| `WlanSvc`   | WiFi — connexion sans fil                                     |

---

## ❌ Services TOUJOURS désactivés

| Service               | Raison                                              |
|-----------------------|-----------------------------------------------------|
| `DiagTrack`           | Télémétrie principale Microsoft                     |
| `dmwappushsvc`        | Télémétrie push WAP                                 |
| `dmwappushservice`    | Télémétrie push WAP (alias)                         |
| `diagsvc`             | Service de diagnostic                               |
| `WerSvc`              | Rapport d'erreurs Windows                           |
| `wercplsupport`       | Support panneau de contrôle erreurs                 |
| `NetTcpPortSharing`   | Partage port TCP/IP — inutile                       |
| `RemoteAccess`        | Accès distant — inutile                             |
| `RemoteRegistry`      | Registre distant — risque sécurité                  |
| `SharedAccess`        | Partage connexion Internet                          |
| `TrkWks`              | Suivi des liens distribués                          |
| `WMPNetworkSvc`       | Partage Windows Media Player                        |
| `XblAuthManager`      | Xbox Live authentification                          |
| `XblGameSave`         | Xbox Live sauvegarde                                |
| `XboxNetApiSvc`       | Xbox Live réseau                                    |
| `XboxGipSvc`          | Xbox accessoires                                    |
| `BDESVC`              | BitLocker                                           |
| `wbengine`            | Moteur de sauvegarde BitLocker                      |
| `BthAvctpSvc`         | Audio Bluetooth                                     |
| `Fax`                 | Télécopie                                           |
| `RetailDemo`          | Mode démo retail                                    |
| `ScDeviceEnum`        | Énumération smart card                              |
| `SCardSvr`            | Smart card                                          |
| `AJRouter`            | AllJoyn routeur — IoT                               |
| `MessagingService`    | Messagerie                                          |
| `SensorService`       | Capteurs                                            |
| `PrintNotify`         | Notifications imprimante                            |
| `wisvc`               | Windows Insider                                     |
| `lfsvc`               | Géolocalisation                                     |
| `MapsBroker`          | Cartes hors ligne                                   |
| `CDPSvc`              | Plateforme appareils connectés                      |
| `PhoneSvc`            | Téléphone                                           |
| `WalletService`       | Portefeuille                                        |
| `AIXSvc`              | Service IA — 25H2                                   |
| `CscService`          | Fichiers hors connexion                             |
| `lltdsvc`             | Découverte réseau Link-Layer — inutile              |
| `SensorDataService`   | Données capteurs physiques — inutile sur PC fixe    |
| `SensrSvc`            | Capteurs physiques — inutile sur PC fixe            |
| `BingMapsGeocoder`    | Géocodage Bing — envoie des données de position     |
| `PushToInstall`       | Microsoft pousse des apps à distance                |
| `SysMain`             | Superfetch — désactivé inconditionnellement (1 Go RAM) |
| `FontCache`           | Cache de polices — consomme RAM inutilement         |
| `cbdhsvc`             | Cloud Clipboard — envoie le presse-papiers à Microsoft |
| `WpnService`          | Push Notifications system (livraison de pubs MS)    |
| `WpnUserService`      | Push Notifications user service                     |
| `CDPUserSvc`          | Connected Devices Platform user (cross-device sync) |
| `DevicesFlowUserSvc`  | Devices Flow — expérience Phone Link                |
| `BcastDVRUserService` | GameDVR broadcast user service                      |
| `DPS`                 | Diagnostic Policy Service — troubleshooters qui phoned home |
| `WdiSystemHost`       | Diagnostic System Host                              |
| `WdiServiceHost`      | Diagnostic Service Host                             |
| `diagnosticshub.standardcollector.service` | Diagnostics Hub — collecte dev/télémétrie |
| `DusmSvc`             | Data Usage — stats réseau par app                   |
| `icssvc`              | Mobile Hotspot — inutile sur PC de bureau           |
| `SEMgrSvc`            | Payments and NFC Manager                            |
| `WpcMonSvc`           | Parental Controls (app supprimée)                   |
| `MixedRealityOpenXRSvc` | Mixed Reality OpenXR (app supprimée)              |
| `NaturalAuthentication` | Natural Authentication (biométrie de proximité)   |
| `SmsRouter`           | SMS Router via Phone Link                           |
| `Ndu`                 | Network Data Usage — stats réseau par app (RAM/CPU) |
| `FDResPub`            | Function Discovery Resource Publication — découverte réseau LAN |
| `SSDPSRV`             | SSDP Discovery — protocole UPnP inutile sur PC fixe |
| `upnphost`            | UPnP Device Host — inutile sur PC fixe non partagé  |
| `Recall`              | Recall AI — service captures écran 25H2             |
| `WindowsAIService`    | Windows AI Service — orchestrateur NPU (25H2)       |
| `WinMLService`        | Windows ML inference broker (25H2)                  |
| `CoPilotMCPService`   | Copilot Model Context Protocol (25H2)               |
| `DoSvc`               | Delivery Optimization — DODownloadMode=0 appliqué mais service tourne encore |
| `WbioSrvc`            | Windows Biometric Service — BioEnrollment supprimé, pas de capteur sur 1 Go |
| `EntAppSvc`           | Enterprise App Management — inutile hors domaine AD |
| `WManSvc`             | Windows Management Service — MDM/Intune, inutile    |
| `DmEnrollmentSvc`     | Device Management Enrollment — inscription MDM, inutile |
| `TermService`         | Remote Desktop Services — conditionnel `NEED_RDP=0` |
| `tzautoupdate`        | Auto Time Zone Updater — inutile sur poste fixe (timezone configurée manuellement) |
| `wmiApSrv`            | WMI Performance Adapter — collecte compteurs perf WMI, inutile en usage bureautique |
| `SDRSVC`              | Windows Backup — inutile, aucune sauvegarde planifiée sur 1 Go RAM |
| `spectrum`            | Windows Perception Service — HoloLens/Mixed Reality, inutile sur PC de bureau |
| `SharedRealitySvc`    | Spatial Data Service — données spatiales Mixed Reality, inutile sur PC de bureau |
| `p2pimsvc`            | Peer Networking Identity Manager — réseau pair-à-pair, inutile sur PC non-serveur |
| `p2psvc`              | Peer Networking Grouping — réseau P2P, inutile sur PC non-serveur |
| `PNRPsvc`             | Peer Name Resolution Protocol — résolution noms P2P, inutile |
| `PNRPAutoReg`         | PNRP Machine Name Publication Service — publication nom machine sur PNRP, inutile |
| `uhssvc`              | Microsoft Update Health Service — rapporte état WU à Microsoft et tente de restaurer composants désactivés |
| `PcaSvc`              | Program Compatibility Assistant — contacte Microsoft pour collecte données compatibilité |
| `stisvc`              | Windows Image Acquisition (WIA) — scanners/caméras TWAIN, inutile sur PC sans scanner |
| `TapiSrv`             | Telephony (TAPI) — inutile sur PC de bureau sans modem/RNIS/softphone |
| `WFDSConMgrSvc`       | Wi-Fi Direct Services Connection Manager — inutile sur PC de bureau fixe |
| `SessionEnv`          | Remote Desktop Configuration — conditionnel `NEED_RDP=0` (complément TermService) |

> ⚠️ `WSearch` : **NE PAS ajouter à cette liste** — toujours conservé sans exception

---

## ❌ Tâches planifiées TOUJOURS désactivées

| Tâche planifiée                                                                   | Raison                        |
|-----------------------------------------------------------------------------------|-------------------------------|
| `\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser`     | Télémétrie compatibilité      |
| `\Microsoft\Windows\Application Experience\ProgramDataUpdater`                    | Télémétrie apps               |
| `\Microsoft\Windows\Application Experience\StartupAppTask`                        | Télémétrie démarrage          |
| `\Microsoft\Windows\Autochk\Proxy`                                                | Proxy vérification auto       |
| `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator`         | CEIP collecte                 |
| `\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask`       | CEIP kernel                   |
| `\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip`              | CEIP USB                      |
| `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector` | Diagnostic disque envoyé MS   |
| `\Microsoft\Windows\Feedback\Siuf\DmClient`                                       | Feedback Microsoft            |
| `\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload`                     | Feedback Microsoft            |
| `\Microsoft\Windows\Maps\MapsToastTask`                                           | Notifications cartes          |
| `\Microsoft\Windows\Maps\MapsUpdateTask`                                          | Mise à jour cartes            |
| `\Microsoft\Windows\NetTrace\GatherNetworkInfo`                                   | Collecte info réseau          |
| `\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem`                   | Diagnostic énergie            |
| `\Microsoft\Windows\Speech\SpeechModelDownloadTask`                               | Téléchargement modèle vocal   |
| `\Microsoft\Windows\Windows Error Reporting\QueueReporting`                       | Rapport d'erreurs             |
| `\Microsoft\Windows\WindowsUpdate\Automatic App Update`                           | Màj auto apps Store           |
| `\Microsoft\XblGameSave\XblGameSaveTask`                                          | Xbox sauvegarde               |
| `\Microsoft\Windows\Shell\FamilySafetyMonitor`                                    | Contrôle parental             |
| `\Microsoft\Windows\Shell\FamilySafetyRefreshTask`                                | Contrôle parental             |
| `\Microsoft\Windows\Defrag\ScheduledDefrag`                                       | Défragmentation automatique   |
| `\Microsoft\Windows\Diagnosis\Scheduled`                                          | Diagnostic automatique        |
| `\Microsoft\Windows\Application Experience\MareBackfill`                          | Télémétrie compatibilité 25H2 |
| `\Microsoft\Windows\Application Experience\AitAgent`                              | Application Impact Telemetry  |
| `\Microsoft\Windows\Application Experience\PcaPatchDbTask`                        | Patching DB compatibilité     |
| `\Microsoft\Windows\Customer Experience Improvement Program\BthSQM`               | CEIP Bluetooth                |
| `\Microsoft\Windows\Customer Experience Improvement Program\Uploader`             | Envoi données CEIP            |
| `\Microsoft\Windows\Device Information\Device`                                    | Collecte infos matériel       |
| `\Microsoft\Windows\Device Information\Device User`                               | Collecte infos user/matériel  |
| `\Microsoft\Windows\DiskFootprint\Diagnostics`                                    | Télémétrie empreinte disque   |
| `\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures`                    | Windows Insider flighting     |
| `\Microsoft\Windows\Flighting\OneSettings\RefreshCache`                           | Push config serveur Microsoft |
| `\Microsoft\Windows\Maintenance\WinSAT`                                           | Benchmark envoyé à Microsoft  |
| `\Microsoft\Windows\PI\Sqm-Tasks`                                                 | Software Quality Metrics      |
| `\Microsoft\Windows\UpdateOrchestrator\Report policies`                           | Rapport policy vers Microsoft |
| `\Microsoft\Windows\CloudExperienceHost\CreateObjectTask`                         | Onboarding IA/OOBE cloud      |
| `\Microsoft\Windows\WS\WSTask`                                                    | Windows Store télémétrie      |
| `\Microsoft\Windows\Clip\License Validation`                                      | Validation licence Clipboard  |
| `\Microsoft\XblGameSave\XblGameSaveTaskLogon`                                     | Xbox GameSave au logon        |
| `\Microsoft\Windows\AI\AIXSvcTaskMaintenance`                                     | Maintenance IA Service (25H2) |
| `\Microsoft\Windows\Copilot\CopilotDailyReport`                                   | Rapport Copilot (25H2)        |
| `\Microsoft\Windows\Recall\IndexerRecoveryTask`                                   | Recall indexer (25H2)         |
| `\Microsoft\Windows\Recall\RecallScreenshotTask`                                  | Recall captures (25H2)        |
| `\Microsoft\Windows\Recall\RecallMaintenanceTask`                                 | Recall maintenance (25H2)     |
| `\Microsoft\Windows\WPN\PushNotificationCleanup`                                  | Nettoyage push notifications  |
| `\Microsoft\Windows\BITS\CacheMaintenanceTask`                                    | Cache maintenance BITS        |
| `\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner`                  | Scanner recommandations MS    |
| `\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan`                      | Rapport intégrité disque      |
| `\Microsoft\Windows\SettingSync\BackgroundUploadTask`                             | Sync paramètres cloud         |
| `\Microsoft\Windows\MUI\LPRemove`                                                 | Cleanup packs langue (CPU logon) |
| `\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents`               | Collecte données mémoire envoyées à Microsoft |
| `\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic`                     | Diagnostic complet RAM envoyé à Microsoft |
| `\Microsoft\Windows\Location\Notifications`                                       | Localisation désactivée — tâche redondante |
| `\Microsoft\Windows\Location\WindowsActionDialog`                                 | Localisation désactivée — tâche redondante |
| `\Microsoft\Windows\StateRepository\MaintenanceTask`                              | Suit l'usage des apps pour Microsoft |
| `\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate`                        | Contacte Microsoft pour màj détails d'erreurs |
| `\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate`                              | Contacte Microsoft pour màj détails d'erreurs |
| `\Microsoft\Windows\DiskCleanup\SilentCleanup`                                    | Nettoyage silencieux avec reporting MS |
| `\Microsoft\Windows\PushToInstall\LoginCheck`                                     | Vérifie les apps à installer en push à la connexion |
| `\Microsoft\Windows\PushToInstall\Registration`                                   | Enregistre le poste pour push install Microsoft |
| `\Microsoft\Windows\WaaSMedic\PlugScheduler`                                      | Réactive automatiquement les composants WU désactivés |
| `\Microsoft\Windows\License Manager\TempSignedLicenseExchange`                    | Échange de licences temporaires — contacte Microsoft |
| `\Microsoft\Windows\UNP\RunUpdateNotificationMgmt`                                | Notifications de disponibilité de mise à jour Windows |
| `\Microsoft\Windows\ApplicationData\CleanupTemporaryState`                        | Nettoyage état temporaire apps — déclenche collecte usage |
| `\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup`                  | Nettoyage apps provisionnées — inutile après setup |
| `\Microsoft\Windows\WindowsUpdate\sih`                                            | Service Initiated Healing — restaure silencieusement les composants WU désactivés |
| `\Microsoft\Windows\RetailDemo\CleanupOfflineContent`                             | Nettoyage contenu démo retail hors ligne |
| `\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization`              | Synchronisation dossiers de travail — fonctionnalité entreprise inutile |
| `\Microsoft\Windows\Workplace Join\Automatic-Device-Join`                         | Adhésion MDM automatique — inutile hors domaine d'entreprise |
| `\Microsoft\Windows\DUSM\dusmtask`                                                | Maintenance Data Usage Service — complément DusmSvc désactivé |
| `\Microsoft\Windows\Management\Provisioning\Cellular`                             | Approvisionnement réseau cellulaire — inutile sur PC de bureau |
| `\Microsoft\Windows\Management\Provisioning\Logon`                                | MDM provisioning au logon — inutile hors Intune/SCCM |

---

## 🚫 Domaines TOUJOURS bloqués (hosts file)

| Domaine                              | Raison                        |
|--------------------------------------|-------------------------------|
| `telemetry.microsoft.com`            | Télémétrie principale         |
| `vortex.data.microsoft.com`          | Collecte données Vortex       |
| `settings-win.data.microsoft.com`    | Paramètres télémétrie         |
| `watson.telemetry.microsoft.com`     | Watson crash reports          |
| `sqm.telemetry.microsoft.com`        | SQM télémétrie                |
| `compat.smartscreen.microsoft.com`   | SmartScreen compatibilité     |
| `browser.pipe.aria.microsoft.com`    | Aria telemetry Edge           |
| `activity.windows.com`               | Historique d'activité         |
| `v10.events.data.microsoft.com`      | Events pipeline télémétrie    |
| `v20.events.data.microsoft.com`      | Events pipeline télémétrie    |
| `self.events.data.microsoft.com`     | Events pipeline télémétrie    |
| `pipe.skype.com`                     | Télémétrie Skype/Teams        |
| `copilot.microsoft.com`              | Service Copilot Microsoft     |
| `sydney.bing.com`                    | Bing AI / Copilot chat        |
| `feedback.windows.com`              | Feedback Windows              |
| `oca.microsoft.com`                  | WER Online Crash Analysis     |
| `watson.microsoft.com`               | WER télémétrie Watson         |
| `bingads.microsoft.com`              | Publicités Bing               |
| `eu-mobile.events.data.microsoft.com` | Pipeline Aria télémétrie (EU) |
| `us-mobile.events.data.microsoft.com` | Pipeline Aria télémétrie (US) |
| `mobile.events.data.microsoft.com`  | Pipeline Aria télémétrie      |
| `edge.activity.windows.com`         | Historique activité Edge      |
| `browser.events.data.msn.com`       | Télémétrie Edge/MSN           |
| `telecommand.telemetry.microsoft.com` | Télécommande télémétrie Microsoft |
| `storeedge.operationmanager.microsoft.com` | Store Edge opérations |
| `checkappexec.microsoft.com`        | Vérification exécution apps (SmartScreen réseau) |
| `inference.location.live.net`       | Inférence de localisation Microsoft |
| `location.microsoft.com`            | Service de localisation Microsoft |
| `watson.ppe.telemetry.microsoft.com` | Watson pipeline PPE (staging télémétrie) |
| `umwatson.telemetry.microsoft.com`  | Watson user-mode crash reports |
| `config.edge.skype.com`             | Config Skype/Teams (apps supprimées) |
| `tile-service.weather.microsoft.com` | Télémétrie tuile météo MSN |
| `outlookads.live.com`               | Publicités Outlook |
| `dl.delivery.mp.microsoft.com`      | CDN Delivery Optimization (DO déjà désactivé) |
| `fp.msedge.net`                     | CDN télémétrie Edge |
| `nexus.officeapps.live.com`         | Télémétrie Office |

> Adobe (commenté par défaut — activer si pas de logiciel Adobe) :
> `lmlicenses.wip4.adobe.com`, `lm.licenses.adobe.com`, `practivate.adobe.com`, `activate.adobe.com`

> ⚙️ Implémentation : utiliser **`0.0.0.0`** (pas `127.0.0.1`) — résolution immédiate sans aller-retour loopback, plus rapide et sans effet de bord.

---

## ✅ Optimisations TOUJOURS appliquées

| Optimisation                              | Implémentation                                          |
|-------------------------------------------|---------------------------------------------------------|
| Zéro télémétrie                           | `AllowTelemetry=0` + `DiagTrack` disabled               |
| Recall désactivé                          | `AllowRecallEnablement=0` + `DisableAIDataAnalysis=1`   |
| Copilot désactivé                         | `TurnOffWindowsCopilot=1` (HKLM + HKCU)                |
| IA Windows 25H2 désactivée               | `HKLM\...\WindowsAI\DisableAIDataAnalysis=1`            |
| Game DVR désactivé                        | `GameDVR_Enabled=0` + `AllowGameDVR=0`                  |
| Compression mémoire                       | `EnableMemoryCompression=1` (`HKLM\...\MMAgent` — registre natif) |
| Fast Startup désactivé                    | `HiberbootEnabled=0`                                    |
| Hibernation off                           | `powercfg /h off`                                       |
| Pagefile fixe **6 Go**                    | InitialSize=6144 MaximumSize=6144 (1 Go RAM)            |
| Vérif espace disque avant pagefile        | Seuil minimum 10 Go libres                              |
| Bloatware auto-install bloqué             | `DisableWindowsConsumerFeatures=1`                      |
| Géolocalisation désactivée               | `lfsvc` disabled + registre — toujours, sans demander    |
| Localisation bloquée par app              | `CapabilityAccessManager` Deny — toutes les apps        |
| WerFaultSecure.exe bloqué                 | `DontSendAdditionalData=1` + `LoggingDisabled=1`        |
| AutoLogger désactivé                      | 4 loggers coupés : DiagTrack, DiagLog, SQMLogger, WiFi  |
| Priorité CPU apps au premier plan         |`SystemResponsiveness=10`                                |
| Bing dans la recherche désactivé          | `BingSearchEnabled=0` + `DisableSearchBoxSuggestions=1` |
| "Réseau" masqué dans l'explorateur        | `NonEnum {F02C1A0D...}` = 1                             |
| Windows Update : redémarrage dès que possible | `NoAutoRebootWithLoggedOnUsers=0`                       |
| Windows Update : connexion limitée            | `AllowAutoWindowsUpdateDownloadOverMeteredNetwork=1`    |
| Windows Update : notification redémarrage     | `RestartNotificationsAllowed2=1`                        |
| Input Personalization désactivé           | `RestrictImplicitInkCollection=1`                       |
| Delivery Optimization P2P désactivé      | `DODownloadMode=0`                                      |
| Activity History désactivé               | `EnableActivityFeed=0`                                  |
| Advertising ID désactivé                  | `DisabledByGroupPolicy=1`                               |
| Cortana désactivé                         | `AllowCortana=0`                                        |
| SmartGlass / Connect désactivé            | `AllowProjectionToPC=0`                                 |
| Remote Assistance désactivé               | `fAllowToGetHelp=0`                                     |
| `LargeSystemCache=0`                      | Favorise apps vs cache disque — libère 50-150 Mo RAM    |
| `MinFreeSystemCommit`                     | Libération mémoire agressive sous pression — stable 1 Go|
| `EnablePrefetcher=0`                      | Arrête le préchargement RAM — libère 50-100 Mo          |
| `POWERSHELL_TELEMETRY_OPTOUT=1`           | Variable système — coupe télémétrie PowerShell          |
| `SysMain` désactivé inconditionnellement  | 1 Go RAM — désactivation directe sans détection SSD/HDD |
| Son au démarrage désactivé                | `DisableStartupSound=1`                                 |
| AutoPlay / AutoRun désactivés             | Sécurité USB — pas d'exécution automatique              |
| Dossier Prefetch vidé au démarrage        | Suppression contenu `C:\Windows\Prefetch\`              |
| Interface Win10 : barre gauche            | **HKLM** `Policies\...\Explorer` `TaskbarAlignment=0`  |
| Interface Win10 : sans Widgets            | **HKLM** `Policies\Microsoft\Dsh` `AllowNewsAndInterests=0` |
| Interface Win10 : sans Teams barre        | **HKLM** `Policies\...\Windows Chat` `ChatIcon=2`       |
| Interface Win10 : sans Copilot barre      | Couvert par `TurnOffWindowsCopilot=1` (HKLM déjà présent) |
| Interface Win10 : menu contextuel classique | **HKCU** CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` — HKCU uniquement par design Shell |
| Interface Win10 : Ce PC par défaut        | **HKCU** `LaunchTo=1` — préférence per-user, pas de policy HKLM |
| Interface Win10 : Galerie masquée         | **HKCU** CLSID `{e88865ea...}` — namespace Shell HKCU uniquement |
| Interface Win10 : effets visuels minimalistes | `VisualFXSetting=2`, `MinAnimate=0`                 |
| Interface Win10 : Démarrer sans recommandations | `HideRecommendedSection=1` — GPO Pro/Enterprise     |
| Notifications toast désactivées           | `ToastEnabled=0`                                        |
| Recall 25H2 — clés supplémentaires        | `DisableRecallSnapshots=1` + `TurnOffSavingSnapshots=1` + HKCU `RecallFeatureEnabled=0` |
| AppCompat GPO — blocage réactivation tâches AE/CEIP | `DisableUAR=1` + `DisableInventory=1` + `DisablePCA=1` (complément avant `schtasks /Disable`) |
| Copilot service background désactivé      | `DisableCopilotService=1` — complément `TurnOffWindowsCopilot=1` |
| Bouton Copilot masqué                     | HKCU `ShowCopilotButton=0`                              |
| IA Windows 25H2 — master switch           | `EnableWindowsAI=0` + `AllowOnDeviceML=0` + `DisableWinMLFeatures=1` |
| SIUF — période à zéro                     | HKCU `PeriodInNanoSeconds=0`                            |
| Search HKCU Bing/Cortana désactivé        | `BingSearchEnabled=0` + `CortanaConsent=0` (per-user)   |
| Windows Search — cloud désactivé          | `AllowCloudSearch=0` + `ConnectedSearchUseWeb=0` + HKLM Policy |
| OneDrive auto-start désactivé             | `DisableFileSyncNGSC=1` (HKLM Policy OneDrive)         |
| Windows Spotlight                         | **Conservé** — fond d'écran verrouillage = état Windows par défaut, ne pas toucher |
| GameDVR — fullscreen optimizations off    | HKCU `GameDVR_FSEBehavior=2`                            |
| Remote Assistance — contrôle total bloqué | `fAllowFullControl=0`                                   |
| WER — pas d'UI                            | `DontShowUI=1`                                          |
| Cloud Clipboard désactivé                 | `AllowClipboardHistory=0` + `AllowCrossDeviceClipboard=0` |
| CDP / Nearby Share désactivé              | `DisableCdp=1` — bloque cross-device                    |
| NCSI — stop probes msftconnecttest.com    | `NoActiveProbe=1`                                       |
| Wi-Fi Sense — auto-connect désactivé      | `AutoConnectAllowedOEM=0`                               |
| InputPersonalization — contacts           | HKCU `HarvestContacts=0`                                |
| ContentDeliveryManager — bloque réinstall | `SilentInstalledAppsEnabled=0` + `ContentDeliveryAllowed=0` + SubscribedContent-* |
| AppPrivacy — blocage global sensors/data  | `LetAppsAccessCamera/Microphone/Location/...=2` (14 permissions) |
| Lock Screen — caméra et diaporama off     | `NoLockScreenCamera=1` + `NoLockScreenSlideshow=1`      |
| Écriture manuscrite — partage off         | `PreventHandwritingDataSharing=1`                       |
| Maintenance automatique Windows désactivée| `MaintenanceDisabled=1`                                 |
| Start Menu — suivi programmes off         | HKCU `Start_TrackProgs=0` + `Start_TrackDocs=0`         |
| Feeds — fil d'actualités masqué           | HKCU `ShellFeedsTaskbarViewMode=2`                      |
| Localisation — clés complètes             | `DisableLocationScripting=1` + `DisableWindowsLocationProvider=1` + `DisableSensors=1` |
| Langue — liste non exposée aux sites web  | HKCU `HttpAcceptLanguageOptOut=1`                       |
| Windows Ink Workspace désactivé           | `AllowWindowsInkWorkspace=0` — bouton stylet inutile sur PC de bureau |
| Réseau P2P/PNRP désactivé                | `HKLM\...\Peernet\Disabled=1` — protocoles pair-à-pair inutiles |
| TCP/IP sécurité — routage source off      | `DisableIPSourceRouting=2` — prévient usurpation d'adresse |
| TCP/IP sécurité — redirections ICMP off   | `EnableICMPRedirect=0` — prévient attaques de redirection routage |
| AutoLogger AppModel désactivé             | Trace cycle de vie apps UWP — inutile en production    |
| AutoLogger LwtNetLog désactivé            | Trace réseau légère — inutile en production            |
| Search Highlights désactivés              | `EnableDynamicContentInWSB=0` — tuiles animées MSN/IA dans la barre de recherche |
| Edge démarrage anticipé off (HKCU)        | `StartupBoostEnabled=0` — pas de policy (évite "géré par l'organisation") |
| Edge mode arrière-plan off (HKCU)         | `BackgroundModeEnabled=0` — économise RAM/CPU au repos |
| Biométrie désactivée (policy)             | `HKLM\...\Biometrics\Enabled=0` — complément WbioSrvc=4 |
| LLMNR désactivé                           | `EnableMulticast=0` — réduit broadcasts réseau + sécurité |
| WPAD désactivé                            | `DisableWpad=1` — prévient proxy poisoning              |
| SMBv1 désactivé (belt-and-suspenders)     | `LanmanServer\Parameters\SMB1=0` — belt-and-suspenders 25H2 |

---

## 🔐 Sécurité 25H2 — Fichier Panther

Depuis Windows 11 25H2, le setup copie `unattend.xml` et `unattend-original.xml`
dans `C:\Windows\Panther\` avec le **mot de passe du compte local en clair**.

**Action obligatoire en Section 3 du .bat :**
```bat
del /f /q "C:\Windows\Panther\unattend.xml" >nul 2>&1
del /f /q "C:\Windows\Panther\unattend-original.xml" >nul 2>&1
```
⛔ Ne jamais omettre cette section si un mot de passe est défini sur le compte local.

---

## ❌ Ce qui ne doit JAMAIS être fait

| Action interdite                      | Raison                                                        |
|---------------------------------------|---------------------------------------------------------------|
| Désactiver `WSearch`                  | Recherche Windows toujours voulue — tous profils, toute RAM   |
| Désactiver `WlanSvc`                  | WiFi — connexion sans fil                                     |
| Supprimer Edge                        | Conservé explicitement                                        |
| Supprimer OneDrive                    | Conservé explicitement                                        |
| Supprimer Photos                      | Conservée explicitement                                       |
| Désactiver `WinDefend`                | Sécurité — interdit                                           |
| Désactiver `wuauserv`                 | Windows Update — patches sécurité                            |
| `SubmitSamplesConsent=2`              | Réduit détection malware Defender                             |
| Bypass TPM/RAM/SecureBoot par défaut  | Matériel compatible — bypass non voulu                        |
| `PAUSE` ou `shutdown /r` dans le .bat | Script silencieux, pas d'interaction                         |
| CommandLine > 1024 chars dans le XML  | Erreur WSIM rouge                                             |
| Params dépréciés dans oobeSystem      | `NetworkLocation`, `SkipMachineOOBE`, `SkipUserOOBE`          |
| Doublons dans la liste de services    | Erreur silencieuse dans la boucle `for`                       |
| Désactiver `AppXSvc`                  | Store et winget en dépendent — cassé sinon                    |
| Désactiver `seclogon`                 | Laissé par défaut Windows — installeurs tiers en dépendent    |
| Remplacer `explorer.exe`              | Shell alternatif — instable, jamais                           |
| Modifier Defender / antivirus         | Intouchable — sécurité système                                |
| Désactiver `ctfmon.exe`               | Dictée vocale en dépend                                       |
| Désactiver `TiWorker.exe`             | Lié à Windows Update — interdit                               |
| Désactiver Aero / `dwm.exe`           | Wallpaper Engine en dépend                                    |
| Désactiver stack VPN RAS              | CyberGhost en dépend potentiellement                          |
| Désactiver `TokenBroker`              | OneDrive et Edge en dépendent                                 |
| Désactiver `OneSyncSvc`               | OneDrive en dépend — jamais désactivé                         |
| Désactiver `wlidsvc`                  | Microsoft Account Sign-in Assistant — OneDrive et Edge en dépendent |
| Omettre la suppression fichiers Panther | Mot de passe admin exposé en clair — risque sécurité        |
| `Win32_ComputerSystem.Put()` / `Set-WmiInstance` / `wmic pagefileset` dans le BAT | Token COM/WMI absent en `FirstLogonCommands` — arrêt silencieux du script — utiliser clés registre |
| Commande PowerShell sans `-NonInteractive` + `try/catch`     | Exception PS propage exit code ≠ 0 → arrêt silencieux du BAT parent  |
| **Mettre des clés de registre dans `autounattend.xml`**  | **Le XML ne contient que le strict minimum setup — tout le registre est dans le .bat** |
| Modifier `Win32PrioritySeparation`       | Valeur Windows par défaut conservée — ne jamais écrire cette clé       |
| Modifier le DNS sécurisé Edge            | `BuiltInDnsClientEnabled`, `DnsOverHttpsMode`, `DnsOverHttpsTemplates` — section **Sécurité > Utiliser un DNS sécurisé** dans Edge — ne jamais écrire ces clés (choix utilisateur, impact réseau critique) |
| Écrire toute clé sous `HKLM\SOFTWARE\Policies\Microsoft\Edge` | La seule présence de ce chemin affiche **"géré par une organisation"** dans Edge — interdit sans exception. Inclut aussi `HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\*` |
| Mentionner Claude ou Claude Code dans un fichier du projet    | Outil interne — ne doit pas apparaître dans les fichiers du dépôt |
| Toute modification de l'écran de verrouillage (`NoLockScreen`, `NoLockScreenCamera`, `NoLockScreenSlideshow`, `RotatingLockScreenEnabled`, `RotatingLockScreenOverlayEnabled`, `DisableWindowsSpotlightFeatures`) | Écran de verrouillage, fond d'écran et Spotlight conservés à l'état Windows par défaut — non négociable |

---

## ⚠️ Actions à ne PAS faire sans demande explicite

| Action déconseillée par défaut        | Raison                                                        |
|---------------------------------------|---------------------------------------------------------------|
| Désactiver `NgcSvc` / `NgcCtnrSvc`    | Windows Hello/PIN — risque blocage login compte Microsoft     |
| Désactiver `WinHttpAutoProxySvc`      | VPN CyberGhost peut en dépendre                               |

---

## 📋 Rappel technique clé

Le `.bat` est copié depuis la clé USB en `specialize` puis appelé dans `FirstLogonCommands` :

```xml
<!-- specialize -->
<Path>cmd /c for %d in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do @if exist "%d:\win11-setup.bat" copy /y "%d:\win11-setup.bat" "C:\Windows\Temp\win11-setup.bat"</Path>

<!-- oobeSystem FirstLogonCommands -->
<CommandLine>cmd.exe /c "C:\Windows\Temp\win11-setup.bat"</CommandLine>
```

---

## 🛠️ Règles de conception du code

### Séparation XML / BAT — principe XML STRICT MINIMUM

**Le `autounattend.xml` ne contient que ce qui est structurellement impossible à faire dans le .bat :**

| Pass XML       | Contenu autorisé — UNIQUEMENT                                |
|----------------|--------------------------------------------------------------|
| `windowsPE`    | Langue WinPE, partitionnement GPT/UEFI, EULA, clé produit   |
| `specialize`   | `ComputerName`, `TimeZone`, copie du `.bat` depuis clé USB   |
| `oobeSystem`   | Création compte, paramètres OOBE, `FirstLogonCommands`       |

**Aucune clé de registre ne doit figurer dans le XML**, même `AllowTelemetry`.
Toute configuration registre, service, interface, mémoire, télémétrie → **BAT uniquement**.

| Fichier            | Contexte d'exécution    | Que doit-il contenir ?                                           |
|--------------------|-------------------------|------------------------------------------------------------------|
| `autounattend.xml` | SYSTEM, avant OOBE      | Setup pur — langue, partition, compte, copie du .bat             |
| `win11-setup.bat`  | Utilisateur, post-logon | **Tout le reste** : registre HKLM + HKCU, services, apps, hosts |

**Règle principale** : toute clé registre est dans le `.bat`, jamais dans le XML.
Exception tolérée : confirmation d'état (`sc stop DiagTrack`) pour s'assurer que le service est bien arrêté après redémarrage.

**Clés HKLM gérées UNIQUEMENT dans le BAT (ne pas mettre dans le XML) :**
- `AllowTelemetry` — Section 2 télémétrie
- `LargeSystemCache` — Section 5 mémoire
- `EnablePrefetcher` / `EnableSuperfetch` — Section 5 mémoire
- `DisableStartupSound` + `UserSetting_DisableStartupSound` — Section 6 interface
- Toute autre clé registre sans exception

---

### Règle fondamentale — Registre en priorité

**Toujours préférer les clés de registre natives à toute autre méthode**, dès que le paramètre est configurable par registre.

| Méthode | Priorité | Quand l'utiliser |
|---|---|---|
| `reg add` (clé registre native) | ✅ **1 — prioritaire** | Dès que la clé existe — toujours préférer |
| `sc config ... start= disabled` | ⚠️ 2 — complément | Uniquement si aucune clé `Start` registre disponible (rare) |
| `schtasks /Change /Disable` | ⚠️ 2 — complément | Tâches planifiées uniquement — pas de clé registre équivalente |
| `powershell -Command ...` | ⚠️ 3 — dernier recours | Uniquement si registre impossible (ex. `Checkpoint-Computer`) |
| `wmic`, `Set-WmiInstance`, `Win32_ComputerSystem.Put()` | ❌ **INTERDIT** | Jamais — token COM absent en FirstLogonCommands |

**Exemples :**
```bat
:: ✅ CORRECT — registre natif pour désactiver un service
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack" /v Start /t REG_DWORD /d 4 /f >nul 2>&1

:: ⚠️ ACCEPTABLE uniquement en complément (arrêt immédiat à chaud)
sc stop DiagTrack >nul 2>&1

:: ✅ CORRECT — registre natif pour une politique
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

:: ❌ ÉVITER — PowerShell quand le registre suffit
powershell -Command "Set-ItemProperty -Path '...' -Name AllowTelemetry -Value 0"
```

> Cette règle s'applique à **tous les contextes** : services, politiques, paramètres système, interface, mémoire. Le registre est plus fiable, plus rapide, sans dépendance externe, et garanti de ne pas interrompre le script.

---

### Règles de syntaxe batch obligatoires

**❌ Jamais de `for` loop pour des chemins avec espaces**
```bat
:: FAUX — for ne gère pas les espaces dans les éléments de liste
for %%T in ("\Microsoft\Windows\App Experience\Appraiser") do schtasks /Change /TN %%T ...

:: CORRECT — appels individuels
schtasks /Change /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable >nul 2>&1
```

**✅ For loop autorisée uniquement pour les noms courts sans espaces**
```bat
:: OK — noms de services sans espaces, avec vérification d'existence obligatoire
for %%S in (DiagTrack XblAuthManager XboxNetApiSvc) do (
    sc query %%S >nul 2>&1 && sc stop %%S >nul 2>&1
)
```

**✅ `schtasks /Disable` toujours précédé d'un `schtasks /Query`**

Sans vérification d'existence, `schtasks /Change /Disable` produit "Le chemin de tâche spécifié est introuvable" pour toute tâche absente (tâches 25H2 sur anciens builds, tâches optionnelles non installées).

```bat
:: ❌ FAUX — erreur si la tâche est absente
schtasks /Change /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" /Disable >nul 2>&1

:: ✅ CORRECT — ignoré proprement si la tâche n'existe pas
schtasks /Query /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" /Disable >nul 2>&1
```

**❌ Jamais de doublons dans les listes de services**
Vérifier avant chaque génération qu'un service n'apparaît pas deux fois dans la boucle `for`.

**❌ Jamais de `PAUSE`, `choice`, `shutdown /r` dans le .bat**
Le script est exécuté silencieusement en contexte non-interactif.
Terminer toujours par `exit /b 0`.

**❌ Jamais de `Win32_ComputerSystem.Put()` / `Set-WmiInstance` / `wmic pagefileset` dans le BAT**

**Bug confirmé (section 5) :** ces appels nécessitent un token élevé absent au premier logon (`FirstLogonCommands`). Ils provoquent un **arrêt silencieux du BAT** sans message d'erreur ni entrée dans le log.
Toujours utiliser les **clés registre natives** à la place :
```bat
:: ❌ INTERDIT — arrête le BAT silencieusement en FirstLogonCommands
powershell -NoProfile -Command "$cs = Get-WmiObject Win32_ComputerSystem; ..."

:: ✅ OBLIGATOIRE — registre natif, sans dépendance WMI
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v AutomaticManagedPagefile /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 6144 6144" /f >nul 2>&1
```

**❌ Jamais de commande PowerShell sans `-NonInteractive` + `try/catch` dans le BAT**

```bat
:: ❌ FAUX — exception terminante possible
powershell -NoProfile -Command "Checkpoint-Computer -Description 'test'" >nul 2>&1

:: ✅ CORRECT — exception absorbée, exit code garanti 0
powershell -NoProfile -NonInteractive -Command "try { Checkpoint-Computer -Description 'test' -ErrorAction Stop } catch { }" >nul 2>&1
```

> Note : `Enable-MMAgent -MemoryCompression` est souvent cité comme exemple, mais la clé registre
> native `EnableMemoryCompression=1` (sous `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMAgent`)
> est préférable et doit être utilisée à la place (règle "registre en priorité").

**✅ `echo` de traçabilité obligatoire après chaque bloc critique**

```bat
powershell -NoProfile -NonInteractive -Command "try { ... } catch { }" >nul 2>&1
echo [%date% %time%] NomBloc OK >> "%LOG%"
```

---

## ⚖️ Tradeoffs documentés

| Choix                         | Bénéfice                        | Coût réel                                               | Décision retenue                                        |
|-------------------------------|----------------------------------|---------------------------------------------------------|---------------------------------------------------------|
| `AllowTelemetry=0`            | Zéro collecte Microsoft          | Bloque certains diagnostics MS légitimes                | ✅ Maintenu — choix assumé                              |
| `SubmitSamplesConsent=2`      | Ne pas envoyer samples Defender  | **Réduit la détection malware** — perte sécurité réelle | ❌ Retiré du script                                     |
| Pagefile fixe **6 Go**        | Stabilité mémoire sur 1 Go RAM   | Risque si disque < 10 Go libre — vérif obligatoire      | ✅ Maintenu avec vérif espace disque                    |
| Suppression Xbox services     | ~20 Mo RAM libérés               | Peut gêner certains jeux utilisant Xbox API             | ✅ Maintenu                                             |
| `WSearch` conservé            | Recherche rapide active          | ~50-100 Mo RAM consommés                                | ✅ Conservé — tous profils, toute RAM, sans exception   |
| `SysMain` désactivé           | ~30 Mo RAM libérés               | Pas de prefetch (mineur sur SSD)                        | ✅ Désactivé inconditionnellement sur 1 Go RAM          |
| Copilot / Recall désactivés   | Ressources libérées + vie privée | Pas de fonctions IA 25H2                                | ✅ Obligatoire sur 1 Go RAM                             |
| Fast Startup désactivé        | Évite corruptions petites configs| Boot légèrement plus long                               | ✅ Maintenu sur 1 Go RAM                                |
| Pas de rollback automatique   | —                                | Modifications irréversibles sans reset                  | ✅ **Point de restauration créé en premier**            |
| **XML strict minimum**        | XML lisible, maintenance facile  | Tout le registre en post-logon (délai 1er démarrage)    | ✅ Retenu — cohérence et maintenabilité primées         |
| `Win32PrioritySeparation`     | Gain theórique ordonnancement    | Impact réel non mesuré — risque régression inattendue   | ❌ Non touché — valeur Windows par défaut conservée     |

---

## 🔒 Sécurité — lignes à ne jamais inclure

```bat
:: ❌ INTERDIT — réduit la capacité de détection de Defender
powershell -Command "Set-MpPreference -SubmitSamplesConsent 2"

:: ❌ INTERDIT — désactive complètement Windows Update (patches sécurité)
sc config wuauserv start= disabled

:: ❌ INTERDIT — désactive Windows Defender
sc config WinDefend start= disabled

:: ❌ INTERDIT — désactive WSearch (règle non-négociable)
sc config WSearch start= disabled
```

---

## 📐 Règles défensives obligatoires dans chaque .bat

```bat
:: 1. Point de restauration EN PREMIER — avant toute modification
powershell -NoProfile -NonInteractive -Command "try { Checkpoint-Computer -Description 'Avant win11-setup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop } catch { }"

:: 2. Vérification espace disque AVANT de fixer le pagefile (seuil 10 Go pour pagefile 6 Go)
::    ✅ Méthode registre native — NE PAS utiliser Win32_ComputerSystem.Put() / Set-WmiInstance / wmic pagefileset
for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where DeviceID^="C:" get FreeSpace /value 2^>nul') do set FREE=%%F
if defined FREE (
    set /a FREE_GB=!FREE:~0,-6! / 1000
    if !FREE_GB! GEQ 10 (
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v AutomaticManagedPagefile /t REG_DWORD /d 0 /f >nul 2>&1
        reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 6144 6144" /f >nul 2>&1
        echo [%date% %time%] Pagefile 6Go fixe applique >> "%LOG%"
    ) else (
        echo [%date% %time%] Pagefile auto conserve - espace insuffisant >> "%LOG%"
    )
) else (
    echo [%date% %time%] Pagefile auto conserve - FREE non defini >> "%LOG%"
)
```

---

## 🎛️ Options à demander à l'utilisateur avant génération

| Question à poser                        | Impact si non posé                                     | Valeur par défaut       |
|-----------------------------------------|--------------------------------------------------------|-------------------------|
| Utilises-tu des logiciels Adobe ?       | Hosts Adobe commentés → licences bloquées si activé    | ❌ Hosts commentés      |
| As-tu besoin du Bureau à distance (RDP)?| `Microsoft.RemoteDesktop` supprimé sinon               | ❌ Supprimé             |
| Appareils Bluetooth audio ?             | `BthAvctpSvc` désactivé → casques BT peuvent échouer   | ❌ Désactivé            |
| Webcam utilisée ?                       | `Microsoft.WindowsCamera` supprimé sinon               | ❌ Supprimé             |
| Machine partagée / multi-utilisateurs ? | `seclogon` laissé par défaut Windows — pas touché      | ✅ Défaut Windows       |

---

## 📋 Apps avec note d'avertissement obligatoire dans le .bat

```bat
:: OPTIONNEL : retirer si accès Bureau à distance nécessaire
:: Microsoft.RemoteDesktop

:: OPTIONNEL : retirer si webcam utilisée fréquemment
:: Microsoft.WindowsCamera
```

La section Hosts Adobe doit rester **commentée par défaut**, activable manuellement.
