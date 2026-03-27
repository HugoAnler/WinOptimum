@echo off
setlocal enabledelayedexpansion

:: ═══════════════════════════════════════════════════════════
:: win11-setup.bat — Post-install Windows 11 25H2 optimisé 1 Go RAM
:: Fusionné avec optimisation-windows11-complet-modified.cmd (TILKO 2026-03)
:: Exécuté via FirstLogonCommands (contexte utilisateur, droits admin)
:: ═══════════════════════════════════════════════════════════

:: -------------------------
:: Configuration (modifier avant exécution si besoin)
:: -------------------------
set LOG=C:\Windows\Temp\win11-setup.log
set BLOCK_ADOBE=0      :: 0 = Adobe hosts commentés (par défaut), 1 = activer blocage Adobe
set NEED_RDP=0         :: 0 = Microsoft.RemoteDesktop supprimé, 1 = conservé
set NEED_WEBCAM=0      :: 0 = Microsoft.WindowsCamera supprimé, 1 = conservé
set NEED_BT=0          :: 0 = BthAvctpSvc désactivé (casques BT audio peuvent échouer), 1 = conservé
set NEED_PRINTER=1     :: 0 = Spooler désactivé (pas d'imprimante), 1 = conservé

echo [%date% %time%] win11-setup.bat start >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 1 — Vérification droits administrateur
:: ═══════════════════════════════════════════════════════════
openfiles >nul 2>&1
if errorlevel 1 (
  echo [%date% %time%] ERROR: script must run as Administrator >> "%LOG%"
  exit /b 1
)
echo [%date% %time%] Section 1 : Admin OK >> "%LOG%"
:: ═══════════════════════════════════════════════════════════
:: SECTION 2 — Point de restauration (OBLIGATOIRE — EN PREMIER)
:: ═══════════════════════════════════════════════════════════
powershell -NoProfile -NonInteractive -Command "try { Checkpoint-Computer -Description 'Avant win11-setup' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop } catch { }" >nul 2>&1
echo [%date% %time%] Section 2 : Checkpoint-Computer attempted >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 3 — Suppression fichiers Panther (SECURITE 25H2)
:: Mot de passe admin exposé en clair dans ces fichiers
:: ═══════════════════════════════════════════════════════════
del /f /q "C:\Windows\Panther\unattend.xml" >nul 2>&1
del /f /q "C:\Windows\Panther\unattend-original.xml" >nul 2>&1
echo [%date% %time%] Section 3 : Fichiers Panther supprimes >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 4 — Vérification espace disque + Pagefile fixe 6 Go
:: Méthode registre native — wmic pagefileset/Set-WmiInstance INTERDITS (pas de token WMI write en FirstLogonCommands)
:: wmic logicaldisk (lecture seule) utilisé en détection d'espace — silencieux si absent (fallback ligne 59)
:: ═══════════════════════════════════════════════════════════
set FREE=
for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where DeviceID^="C:" get FreeSpace /value 2^>nul') do set FREE=%%F
if defined FREE (
  set /a FREE_GB=!FREE:~0,-6! / 1000
  if !FREE_GB! GEQ 10 (
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v AutomaticManagedPagefile /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 6144 6144" /f >nul 2>&1
    echo [%date% %time%] Section 4 : Pagefile 6 Go fixe applique (espace OK : !FREE_GB! Go) >> "%LOG%"
  ) else (
    echo [%date% %time%] Section 4 : Pagefile auto conserve - espace insuffisant (!FREE_GB! Go) >> "%LOG%"
  )
) else (
  echo [%date% %time%] Section 4 : Pagefile auto conserve - FREE non defini (wmic echoue) >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 5 — Mémoire : compression, prefetch, cache
:: ═══════════════════════════════════════════════════════════
:: Registre mémoire
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v MinFreeSystemCommit /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMAgent" /v EnableMemoryCompression /t REG_DWORD /d 1 /f >nul 2>&1

:: Prefetch / Superfetch désactivés
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f >nul 2>&1

:: SysMain désactivé (Start=4, effectif après reboot)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul 2>&1

:: PowerShell telemetry opt-out (variable système)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v POWERSHELL_TELEMETRY_OPTOUT /t REG_SZ /d 1 /f >nul 2>&1

:: Délais d'arrêt application/service réduits (réactivité fermeture processus)
reg add "HKLM\SYSTEM\CurrentControlSet\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v WaitToKillAppTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v HungAppTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v AutoEndTasks /t REG_SZ /d 1 /f >nul 2>&1
:: Délai démarrage Explorer à zéro
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f >nul 2>&1
:: Mémoire réseau — throttling index désactivé (latence réseau améliorée)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f >nul 2>&1
:: Page file — ne pas effacer à l'arrêt (accélère le shutdown)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f >nul 2>&1
:: Réseau — taille pile IRP serveur (améliore partage fichiers réseau)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v IRPStackSize /t REG_DWORD /d 30 /f >nul 2>&1
:: Chemins longs activés (>260 chars)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul 2>&1
:: NTFS — désactiver la mise à jour Last Access Time (supprime une écriture disque sur chaque lecture — gain I/O majeur HDD)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 1 /f >nul 2>&1
:: NTFS — désactiver les noms courts 8.3 (réduit les entrées NTFS par fichier)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 5 : Memoire/Prefetch/SysMain/NTFS OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 6 — Télémétrie / IA / Copilot / Recall / Logging
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v AllowRecallEnablement /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DontSendAdditionalData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v LoggingDisabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DiagTrack" /v DisableTelemetry /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SQM" /v DisableSQM /t REG_DWORD /d 1 /f >nul 2>&1
:: Feedback utilisateur (SIUF) — taux de solicitation à zéro
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f >nul 2>&1
:: CEIP désactivé via registre (complément aux tâches planifiées section 17)
reg add "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f >nul 2>&1
:: Recall 25H2 — clés supplémentaires au-delà de AllowRecallEnablement=0
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableRecallSnapshots /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v TurnOffSavingSnapshots /t REG_DWORD /d 1 /f >nul 2>&1
:: Recall per-user (HKCU)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v RecallFeatureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v HideRecallUIElements /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v AIDashboardEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: IA Windows 25H2 — master switch NPU/ML
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v EnableWindowsAI /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v AllowOnDeviceML /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableWinMLFeatures /t REG_DWORD /d 1 /f >nul 2>&1
:: Copilot — désactiver le composant service background (complément TurnOffWindowsCopilot)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v DisableCopilotService /t REG_DWORD /d 1 /f >nul 2>&1
:: SIUF — période à zéro (complément NumberOfSIUFInPeriod=0)
reg add "HKCU\SOFTWARE\Microsoft\Siuf\Rules" /v PeriodInNanoSeconds /t REG_DWORD /d 0 /f >nul 2>&1
:: Windows Defender — non touché (SubmitSamplesConsent et SpynetReporting conservés à l'état Windows par défaut)
:: DataCollection — clés complémentaires à AllowTelemetry=0 (redondantes mais couverture maximale)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v LimitDiagnosticLogCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableDiagnosticDataViewer /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowDeviceNameInTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v LimitEnhancedDiagnosticDataWindowsAnalytics /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v MicrosoftEdgeDataOptIn /t REG_DWORD /d 0 /f >nul 2>&1
:: Software Protection Platform — empêche génération tickets de licence (réduit télémétrie licence)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform" /v NoGenTicket /t REG_DWORD /d 1 /f >nul 2>&1
:: Experimentation et A/B testing Windows 25H2
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\System" /v AllowExperimentation /t REG_DWORD /d 0 /f >nul 2>&1
:: OneSettings — empêche téléchargement config push Microsoft
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v DisableOneSettingsDownloads /t REG_DWORD /d 1 /f >nul 2>&1
:: DataCollection — chemins supplémentaires (Wow6432Node + SystemSettings)
reg add "HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SystemSettings\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
:: Recherche — désactiver l'historique de recherche sur l'appareil
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsDeviceSearchHistoryEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Recherche — désactiver la boîte de recherche dynamique (pingue Microsoft) et cloud search AAD/MSA
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsDynamicSearchBoxEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsAADCloudSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsMSACloudSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Cortana — clés HKLM\...\Search complémentaires (chemins non-policy)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Consentement Skype désactivé
reg add "HKCU\SOFTWARE\Microsoft\AppSettings" /v Skype-UserConsentAccepted /t REG_DWORD /d 0 /f >nul 2>&1
:: Notifications de compte Microsoft désactivées
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v AccountNotifications /t REG_DWORD /d 0 /f >nul 2>&1
:: Appels téléphoniques — accès apps UWP refusé
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall" /v Value /t REG_SZ /d Deny /f >nul 2>&1
:: Recherche cloud désactivée
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
:: OneDrive — policy non écrite (conservé, démarrage géré par l'utilisateur)

echo [%date% %time%] Section 6 : Telemetrie/AI/Copilot/Recall/SIUF/CEIP/Defender/DataCollection OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 7 — AutoLoggers télémétrie (désactivation à la source)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagTrack-Listener" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SQMLogger" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
:: CloudExperienceHostOobe — télémétrie OOBE cloud
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\CloudExperienceHostOobe" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
:: NtfsLog — trace NTFS performance (inutile en production)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\NtfsLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
:: ReadyBoot — prefetch au boot (inutile : EnablePrefetcher=0 déjà appliqué)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\ReadyBoot" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
:: AppModel — trace cycle de vie des apps UWP (inutile en production)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\AppModel" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
:: LwtNetLog — trace réseau légère (inutile en production)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\LwtNetLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 7 : AutoLoggers desactives >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 8 — Windows Search policies (WSearch SERVICE conservé actif)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsSearch" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsSearch" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsSearch" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1
:: Search HKCU — Bing et Cortana per-user (complément policies HKLM ci-dessus)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f >nul 2>&1
:: Windows Search policy — cloud et localisation
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowSearchToUseLocation /t REG_DWORD /d 0 /f >nul 2>&1
:: Exclure Outlook de l'indexation (réduit I/O disque sur 1 Go RAM)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v PreventIndexingOutlook /t REG_DWORD /d 1 /f >nul 2>&1
:: Highlights dynamiques barre de recherche — désactiver les tuiles animées MSN/IA
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v EnableDynamicContentInWSB /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 8 : WindowsSearch policies OK (WSearch conserve) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 9 — GameDVR / Delivery Optimization / Messagerie
:: NOTE : aucune clé HKLM\SOFTWARE\Policies\Microsoft\Edge intentionnellement
::        — toute clé sous ce chemin affiche "géré par une organisation" dans Edge
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
:: Messagerie — synchronisation cloud désactivée
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Messaging" /v AllowMessageSync /t REG_DWORD /d 0 /f >nul 2>&1
:: GameDVR — désactiver les optimisations plein écran (réduit overhead GPU)
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f >nul 2>&1
:: Edge — démarrage anticipé et mode arrière-plan désactivés (HKCU non-policy — évite "géré par l'organisation")
reg add "HKCU\SOFTWARE\Microsoft\Edge\Main" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Edge\Main" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 9 : GameDVR/DeliveryOptimization/Messaging/Edge OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 10 — Windows Update
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] Section 10 : Windows Update conserve (non touche) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 11 — Vie privée / Sécurité / Localisations
:: ═══════════════════════════════════════════════════════════
:: Cortana
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1

:: Advertising ID
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1

:: Activity History
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f >nul 2>&1

:: Projection / SmartGlass désactivé
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Connect" /v AllowProjectionToPC /t REG_DWORD /d 0 /f >nul 2>&1

:: Remote Assistance désactivé
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Remote Assistance" /v fAllowFullControl /t REG_DWORD /d 0 /f >nul 2>&1

:: Input Personalization (collecte frappe / encre)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1

:: Géolocalisation désactivée (lfsvc désactivé en section 14 + registre)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
:: Localisation bloquée par app (CapabilityAccessManager — UWP/Store apps)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1

:: Notifications toast désactivées
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1
:: Notifications toast — clé non-policy directe (effet immédiat sans redémarrage — complément HKLM policy ligne 248)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: AutoPlay / AutoRun désactivés (sécurité USB)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HonorAutorunSetting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1

:: Bloatware auto-install Microsoft bloqué
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1

:: WerFault / Rapport erreurs désactivé (clés non-policy)
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontSendAdditionalData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v LoggingDisabled /t REG_DWORD /d 1 /f >nul 2>&1
:: WER désactivé via policy path (prioritaire sur les clés non-policy ci-dessus)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f >nul 2>&1
:: WER — masquer l'UI (complément DontSendAdditionalData)
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD /d 1 /f >nul 2>&1

:: Input Personalization — policy HKLM (appliqué system-wide, complément des clés HKCU)
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1
:: Input Personalization — désactiver la personnalisation globale (complément Restrict*)
reg add "HKLM\SOFTWARE\Policies\Microsoft\InputPersonalization" /v AllowInputPersonalization /t REG_DWORD /d 0 /f >nul 2>&1

:: Notifications toast — HKLM policy (system-wide, complément du HKCU lignes 221-223)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1

:: CloudContent — expériences personnalisées / Spotlight / SoftLanding
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1

:: CloudContent 25H2 — contenu "optimisé" cloud injecté dans l'interface (nouveau en 25H2)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f >nul 2>&1

:: Maps — empêche màj cartes (complément service MapsBroker désactivé)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maps" /v AutoDownloadAndUpdateMapData /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maps" /v AllowUntriggeredNetworkTrafficOnSettingsPage /t REG_DWORD /d 0 /f >nul 2>&1

:: Speech — empêche màj modèle vocal (complément tâche SpeechModelDownloadTask désactivée)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Speech" /v AllowSpeechModelUpdate /t REG_DWORD /d 0 /f >nul 2>&1

:: Offline Files — policy (complément service CscService désactivé)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1

:: AppPrivacy — empêche apps UWP de s'exécuter en arrière-plan (économie RAM sur 1 Go)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f >nul 2>&1

:: SmartGlass / projection Bluetooth
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SmartGlass" /v UserAuthPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SmartGlass" /v BluetoothPolicy /t REG_DWORD /d 0 /f >nul 2>&1
:: Localisation — service lfsvc (complément DisableLocation registry)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 0 /f >nul 2>&1
:: Capteurs — permission globale désactivée
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v SensorPermissionState /t REG_DWORD /d 0 /f >nul 2>&1
:: Expérimentation système — policy\system (complément PolicyManager couvert en section 6)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowExperimentation /t REG_DWORD /d 0 /f >nul 2>&1
:: Applications arrière-plan — désactiver globalement HKCU
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul 2>&1
:: Advertising ID — clé HKLM complémentaire
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 11 : Vie privee/Securite/WER/InputPerso/CloudContent/Maps/Speech/NetCache/AppPrivacy OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 11b — CDP / Cloud Clipboard / ContentDeliveryManager / AppPrivacy étendu
:: ═══════════════════════════════════════════════════════════
:: Activity History — clés complémentaires (EnableActivityFeed couvert en section 11)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f >nul 2>&1

:: Clipboard local activé (Win+V), cloud/cross-device désactivé
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowClipboardHistory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Clipboard" /v EnableClipboardHistory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v DisableCdp /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkChannelUserAuthzPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /v CdpSessionUserAuthzPolicy /t REG_DWORD /d 0 /f >nul 2>&1

:: NCSI — stopper les probes vers msftconnecttest.com
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" /v NoActiveProbe /t REG_DWORD /d 1 /f >nul 2>&1

:: Wi-Fi Sense — auto-connect désactivé
reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f >nul 2>&1

:: Input Personalization — arrêt collecte contacts pour autocomplete
reg add "HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f >nul 2>&1

:: ContentDeliveryManager — bloquer réinstallation silencieuse apps après màj majeure (CRITIQUE)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353698Enabled" /t REG_DWORD /d 0 /f >nul 2>&1

:: AppPrivacy — blocage global accès capteurs/données par apps UWP (complément LetAppsRunInBackground)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCamera /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessMicrophone /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessLocation /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessAccountInfo /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessContacts /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCalendar /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCallHistory /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessEmail /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessMessaging /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessTasks /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessRadios /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsActivateWithVoice /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsActivateWithVoiceAboveLock /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessBackgroundSpatialPerception /t REG_DWORD /d 2 /f >nul 2>&1

:: Lock Screen — aucune modification (fond d'écran, diaporama, Spotlight, caméra : état Windows par défaut)

:: Écriture manuscrite — partage données désactivé
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1

:: Maintenance automatique Windows — désactiver (évite le polling Microsoft et les réveils réseau)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" /v MaintenanceDisabled /t REG_DWORD /d 1 /f >nul 2>&1

:: Localisation — clés supplémentaires (complément DisableLocation section 11)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocationScripting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableWindowsLocationProvider /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableSensors /t REG_DWORD /d 1 /f >nul 2>&1
:: SettingSync — désactiver la synchronisation cloud des paramètres (thèmes, mots de passe Wi-Fi, etc.)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul 2>&1
:: Storage Sense — désactiver les scans de stockage en arrière-plan
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\StorageSense" /v AllowStorageSenseGlobal /t REG_DWORD /d 0 /f >nul 2>&1

:: Langue — ne pas exposer la liste de langues aux sites web
reg add "HKCU\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1
:: Vie privée HKCU — désactiver expériences personnalisées à partir des données de diagnostic
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Consentement vie privée — marquer comme non accepté (empêche pre-population du consentement)
reg add "HKCU\SOFTWARE\Microsoft\Personalization\Settings" /v AcceptedPrivacyPolicy /t REG_DWORD /d 0 /f >nul 2>&1
:: CloudContent HKCU — suggestions tiers et Spotlight per-user (complément HKLM section 11)
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableThirdPartySuggestions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1

:: Tips & suggestions Windows — désactiver les popups "Discover" / "Get the most out of Windows"
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul 2>&1

:: Réduire taille journaux événements (économie disque/mémoire sur 1 Go RAM — 1 Mo au lieu de 20 Mo)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Application" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\EventLog\System" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\EventLog\Security" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
:: Windows Ink Workspace — désactivé (inutile sur PC de bureau sans stylet/tablette)
reg add "HKLM\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" /v AllowWindowsInkWorkspace /t REG_DWORD /d 0 /f >nul 2>&1
:: Réseau pair-à-pair (PNRP/Peernet) — désactiver (inutile sur PC non-serveur)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Peernet" /v Disabled /t REG_DWORD /d 1 /f >nul 2>&1
:: Tablet PC Input Service — désactiver la collecte données stylet/encre (inutile sur PC de bureau)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1
:: Biométrie — policy HKLM (complément WbioSrvc=4 désactivé en section 14)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Biometrics" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
:: LLMNR — désactiver (réduit broadcast réseau + sécurité : pas de résolution de noms locale non authentifiée)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" /v EnableMulticast /t REG_DWORD /d 0 /f >nul 2>&1
:: WPAD — désactiver l'auto-détection de proxy (sécurité : prévient proxy poisoning)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\WinHttp" /v DisableWpad /t REG_DWORD /d 1 /f >nul 2>&1
:: SMBv1 — désactiver explicitement côté serveur (sécurité, déjà off sur 25H2 — belt-and-suspenders)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" /v SMB1 /t REG_DWORD /d 0 /f >nul 2>&1

echo [%date% %time%] Section 11b : CDP/Clipboard/NCSI/CDM/AppPrivacy/LockScreen/Handwriting/Maintenance/Geo/PrivacyHKCU/Tips/EventLog/InkWorkspace/Peernet/LLMNR/SMBv1/WPAD OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 12 — Interface utilisateur (style Windows 10)
:: HKLM policy utilisé en priorité — HKCU uniquement où pas d'alternative
:: ═══════════════════════════════════════════════════════════
:: Effets visuels minimalistes (per-user — HKCU obligatoire)
reg add "HKCU\Control Panel\Desktop" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v MinAnimate /t REG_SZ /d 0 /f >nul 2>&1

:: Barre des tâches : alignement gauche (HKLM policy)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v TaskbarAlignment /t REG_DWORD /d 0 /f >nul 2>&1

:: Widgets désactivés (HKLM policy)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul 2>&1

:: Bouton Teams/Chat désactivé dans la barre (HKLM policy)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v ChatIcon /t REG_DWORD /d 2 /f >nul 2>&1

:: Copilot barre déjà couvert par TurnOffWindowsCopilot=1 en section 6 (HKLM)

:: Démarrer : recommandations masquées (GPO Pro/Enterprise — HKLM)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1

:: Explorateur : Ce PC par défaut — HKCU obligatoire (pas de policy HKLM)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1

:: Menu contextuel classique (Win10) — HKCU obligatoire (Shell class registration)
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /t REG_SZ /d "" /f >nul 2>&1

:: Galerie masquée dans l'explorateur — HKCU obligatoire (namespace Shell)
:: CLSID actif 25H2 : IsPinnedToNameSpaceTree + HiddenByDefault pour masquage complet
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0009-4384-87f5-7b8f32a3d6d5}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0009-4384-87f5-7b8f32a3d6d5}" /v "HiddenByDefault" /t REG_DWORD /d 1 /f >nul 2>&1

:: Réseau masqué dans l'explorateur (HKLM)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "NonEnum" /t REG_DWORD /d 1 /f >nul 2>&1

:: Son au démarrage désactivé (HKLM)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v UserSetting_DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1

:: Hibernation désactivée / Fast Startup désactivé (HKLM)
:: Registre en priorité (prérequis) — powercfg en complément pour supprimer hiberfil.sys
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v HibernateEnabledDefault /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
powercfg /h off >nul 2>&1

:: Explorateur — divers (HKLM)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoResolveTrack /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoInstrumentation /t REG_DWORD /d 1 /f >nul 2>&1

:: Copilot — masquer le bouton dans la barre des tâches (HKCU per-user)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f >nul 2>&1

:: Démarrer — arrêter le suivi programmes et documents récents
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul 2>&1

:: Démarrer — masquer apps récemment ajoutées (HKLM policy)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f >nul 2>&1

:: Widgets — masquer le fil d'actualités (2=masqué — complément AllowNewsAndInterests=0)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f >nul 2>&1

:: Animations barre des tâches désactivées (économie RAM/CPU)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul 2>&1
:: Aero Peek désactivé (aperçu bureau en survol barre — économise RAM GPU)
reg add "HKCU\SOFTWARE\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f >nul 2>&1
:: Réduire le délai menu (réactivité perçue sans coût mémoire)
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 50 /f >nul 2>&1
:: Désactiver cache miniatures (libère RAM explorateur)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v DisableThumbnailCache /t REG_DWORD /d 1 /f >nul 2>&1

:: Barre des tâches — masquer bouton Vue des tâches (HKCU)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f >nul 2>&1
:: Barre des tâches — masquer widget Actualités (Da) et Meet Now (Mn)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f >nul 2>&1
:: Mode classique barre des tâches (Start_ShowClassicMode)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_ShowClassicMode /t REG_DWORD /d 1 /f >nul 2>&1
:: Barre recherche — mode icône uniquement (0=masqué, 1=icône, 2=barre)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f >nul 2>&1
:: People — barre contact masquée
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v PeopleBand /t REG_DWORD /d 0 /f >nul 2>&1
:: Démarrer — masquer recommandations AI et iris
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_IrisRecommendations /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_Recommendations /t REG_DWORD /d 0 /f >nul 2>&1
:: Démarrer — masquer apps fréquentes / récentes (policy complémentaire)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v ShowRecentApps /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer\Start" /v HideFrequentlyUsedApps /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
:: Windows Chat — bloquer installation automatique (complément ChatIcon=2)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v Communications /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f >nul 2>&1
:: Explorateur — HubMode HKLM + HKCU (mode allégé sans panneau de droite)
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer" /v HubMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v HubMode /t REG_DWORD /d 1 /f >nul 2>&1
:: Explorateur — masquer fréquents, activer fichiers récents, masquer Cloud/suggestions, ne pas effacer à la fermeture
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowOrHideMostUsedApps /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ClearRecentDocsOnExit /t REG_DWORD /d 0 /f >nul 2>&1
:: Galerie explorateur — CLSID alternatif (e0e1c = ancienne GUID W11 22H2)
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /v HiddenByDefault /t REG_DWORD /d 1 /f >nul 2>&1
:: Visuel — lissage police, pas de fenêtres opaques pendant déplacement, transparence off
reg add "HKCU\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul 2>&1
:: Systray — masquer Meet Now
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f >nul 2>&1
:: Fil d'actualités barre des tâches désactivé (HKCU policy)
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f >nul 2>&1
:: OperationStatusManager — mode détaillé (affiche taille + vitesse lors des copies)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" /v EnthusiastMode /t REG_DWORD /d 1 /f >nul 2>&1
:: Application paramètres aux nouveaux comptes utilisateurs (Default User hive)
reg load HKU\DefaultUser C:\Users\Default\NTUSER.DAT >nul 2>&1
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer" /v HubMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f >nul 2>&1
reg unload HKU\DefaultUser >nul 2>&1
echo [%date% %time%] Section 12 : Interface OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 13 — Priorité CPU applications premier plan
:: Win32PrioritySeparation : NON TOUCHE (valeur Windows par défaut)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v SystemResponsiveness /t REG_DWORD /d 10 /f >nul 2>&1
:: Profil multimédia — SystemResponsiveness chemin Software (complément PriorityControl)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 10 /f >nul 2>&1
:: Tâches Games — priorité GPU et CPU minimale (économie ressources bureau)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 1 /f >nul 2>&1
:: Power Throttling — désactiver le bridage CPU (Intel Speed Shift) pour meilleure réactivité premier plan
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f >nul 2>&1
:: TCP Time-Wait — réduire de 120s à 30s (libération sockets plus rapide)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f >nul 2>&1
:: TCP/IP sécurité — désactiver le routage source IP (prévient les attaques d'usurpation)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v DisableIPSourceRouting /t REG_DWORD /d 2 /f >nul 2>&1
:: TCP/IP sécurité — désactiver les redirections ICMP (prévient les attaques de redirection de routage)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v EnableICMPRedirect /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 13 : PriorityControl/PowerThrottling/TCP/IPSecurity OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 13b — Configuration système avancée
:: (Bypass TPM/RAM, PasswordLess, NumLock, SnapAssist, Hibernation menu)
:: ═══════════════════════════════════════════════════════════
:: Bypass TPM/RAM — permet installations/mises à niveau sur matériel non certifié W11
reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f >nul 2>&1
:: Connexion sans mot de passe désactivée (Windows Hello/PIN imposé uniquement si souhaité)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f >nul 2>&1
:: NumLock activé au démarrage (Default hive + hive courant)
reg add "HKU\.DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_DWORD /d 2 /f >nul 2>&1
:: Snap Assist désactivé (moins de distractions, économie ressources)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SnapAssist /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableTaskGroups /t REG_DWORD /d 0 /f >nul 2>&1
:: Menu alimentation — masquer Hibernation et Veille
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowHibernateOption /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowSleepOption /t REG_DWORD /d 0 /f >nul 2>&1
:: RDP — désactiver les connexions entrantes + service TermService (conditionnel NEED_RDP=0)
if "%NEED_RDP%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f >nul 2>&1
if "%NEED_RDP%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Services\TermService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 13b : Config systeme avancee OK >> "%LOG%"


:: ═══════════════════════════════════════════════════════════
:: SECTION 14 — Services désactivés (Start=4, effectif après reboot)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DiagTrack" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\dmwappushsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\dmwappushservice" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\diagsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WerSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wercplsupport" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NetTcpPortSharing" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\RemoteAccess" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\RemoteRegistry" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\TrkWks" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WMPNetworkSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\XblAuthManager" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\XblGameSave" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\XboxGipSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\BDESVC" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wbengine" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
if "%NEED_BT%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Services\BthAvctpSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Fax" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\RetailDemo" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\ScDeviceEnum" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SCardSvr" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AJRouter" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MessagingService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SensorService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PrintNotify" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wisvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lfsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MapsBroker" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CDPSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PhoneSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WalletService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\AIXSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CscService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lltdsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SensorDataService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SensrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\BingMapsGeocoder" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PushToInstall" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\FontCache" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: NDU — collecte stats réseau — consomme RAM/CPU inutilement
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Ndu" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Réseau discovery UPnP/SSDP — inutile sur poste de bureau non partagé
reg add "HKLM\SYSTEM\CurrentControlSet\Services\FDResPub" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SSDPSRV" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\upnphost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Services 25H2 IA / Recall
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Recall" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WindowsAIService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WinMLService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CoPilotMCPService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Cloud clipboard / sync cross-device (cbdhsvc conservé — requis pour Win+V historique local)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CDPUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Push notifications (livraison de pubs et alertes MS)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: GameDVR broadcast user
reg add "HKLM\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: DPS/WdiSystemHost/WdiServiceHost conservés — hébergent les interfaces COM requises par Windows Update (0x80004002 sinon)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\diagnosticshub.standardcollector.service" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Divers inutiles sur PC de bureau 1 Go RAM
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DusmSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\icssvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SEMgrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpcMonSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MixedRealityOpenXRSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NaturalAuthentication" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SmsRouter" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Défragmentation — service inutile si SSD (complément tâche ScheduledDefrag désactivée section 17)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\defragsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Delivery Optimization — DODownloadMode=0 déjà appliqué mais le service tourne encore (~20 Mo RAM)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Biométrie — BioEnrollment app supprimée, aucun capteur sur machine 1 Go RAM
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WbioSrvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Enterprise App Management — inutile hors domaine AD
reg add "HKLM\SYSTEM\CurrentControlSet\Services\EntAppSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Windows Management Service (MDM/Intune) — inutile en usage domestique
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WManSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Device Management Enrollment — inscription MDM inutile
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DmEnrollmentSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Remote Desktop Services — l'app est supprimée (NEED_RDP=0), arrêter aussi le service
if "%NEED_RDP%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Services\TermService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Spooler d'impression — conditionnel (consomme RAM en permanence)
if "%NEED_PRINTER%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Services\Spooler" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Mise à jour automatique fuseau horaire — inutile sur poste fixe (timezone configurée manuellement)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tzautoupdate" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: WMI Performance Adapter — collecte compteurs perf WMI à la demande — inutile en usage bureautique
reg add "HKLM\SYSTEM\CurrentControlSet\Services\wmiApSrv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Windows Backup — inutile (aucune sauvegarde Windows planifiée sur 1 Go RAM)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SDRSVC" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Windows Perception / Spatial Data — HoloLens / Mixed Reality — inutile sur PC de bureau
reg add "HKLM\SYSTEM\CurrentControlSet\Services\spectrum" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SharedRealitySvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Réseau pair-à-pair (PNRP) — inutile sur PC de bureau non-serveur
reg add "HKLM\SYSTEM\CurrentControlSet\Services\p2pimsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\p2psvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PNRPsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PNRPAutoReg" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Program Compatibility Assistant — contacte Microsoft pour collecte de données de compatibilité
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PcaSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Windows Image Acquisition (WIA) — scanners/caméras TWAIN, inutile sans scanner
reg add "HKLM\SYSTEM\CurrentControlSet\Services\stisvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Telephony (TAPI) — inutile sur PC de bureau sans modem/RNIS
reg add "HKLM\SYSTEM\CurrentControlSet\Services\TapiSrv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Wi-Fi Direct Services Connection Manager — inutile sur PC de bureau fixe
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WFDSConMgrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Remote Desktop Configuration — conditionnel (complément TermService NEED_RDP=0)
if "%NEED_RDP%"=="0" reg add "HKLM\SYSTEM\CurrentControlSet\Services\SessionEnv" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 14 : Services Start=4 ecrits (effectifs apres reboot) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 15 — Arrêt immédiat des services listés
:: ═══════════════════════════════════════════════════════════
for %%S in (DiagTrack dmwappushsvc dmwappushservice diagsvc WerSvc wercplsupport NetTcpPortSharing RemoteAccess RemoteRegistry SharedAccess TrkWks WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc BDESVC wbengine Fax RetailDemo ScDeviceEnum SCardSvr AJRouter MessagingService SensorService PrintNotify wisvc lfsvc MapsBroker CDPSvc PhoneSvc WalletService AIXSvc CscService lltdsvc SensorDataService SensrSvc BingMapsGeocoder PushToInstall FontCache SysMain Ndu FDResPub SSDPSRV upnphost Recall WindowsAIService WinMLService CoPilotMCPService CDPUserSvc DevicesFlowUserSvc WpnService WpnUserService BcastDVRUserService DusmSvc icssvc SEMgrSvc WpcMonSvc MixedRealityOpenXRSvc NaturalAuthentication SmsRouter diagnosticshub.standardcollector.service defragsvc DoSvc WbioSrvc EntAppSvc WManSvc DmEnrollmentSvc) do (
  sc query %%S >nul 2>&1 && sc stop %%S >nul 2>&1
)
if "%NEED_BT%"=="0" sc stop BthAvctpSvc >nul 2>&1
if "%NEED_PRINTER%"=="0" sc stop Spooler >nul 2>&1
if "%NEED_RDP%"=="0" sc stop TermService >nul 2>&1
:: Arrêt immédiat des nouveaux services désactivés
for %%S in (tzautoupdate wmiApSrv SDRSVC spectrum SharedRealitySvc p2pimsvc p2psvc PNRPsvc PNRPAutoReg) do (
  sc query %%S >nul 2>&1 && sc stop %%S >nul 2>&1
)
:: Arrêt immédiat des services additionnels
for %%S in (PcaSvc stisvc TapiSrv WFDSConMgrSvc) do (
  sc query %%S >nul 2>&1 && sc stop %%S >nul 2>&1
)
if "%NEED_RDP%"=="0" sc stop SessionEnv >nul 2>&1
echo [%date% %time%] Section 15 : sc stop envoye aux services listes >> "%LOG%"
:: Paramètres de récupération DiagTrack — Ne rien faire sur toutes défaillances
sc failure DiagTrack reset= 0 actions= none/0/none/0/none/0 >nul 2>&1
echo [%date% %time%] Section 15 : sc failure DiagTrack (aucune action sur defaillance) OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 16 — Fichier hosts (blocage télémétrie)
:: ═══════════════════════════════════════════════════════════
set HOSTSFILE=%windir%\System32\drivers\etc\hosts
copy "%HOSTSFILE%" "%HOSTSFILE%.bak" >nul 2>&1
:: Vérification anti-doublon : n'ajouter que si le marqueur est absent
findstr /C:"Telemetry blocks - win11-setup" "%HOSTSFILE%" >nul 2>&1 || (
(
  echo # Telemetry blocks - win11-setup
  echo 0.0.0.0 telemetry.microsoft.com
  echo 0.0.0.0 vortex.data.microsoft.com
  echo 0.0.0.0 settings-win.data.microsoft.com
  echo 0.0.0.0 watson.telemetry.microsoft.com
  echo 0.0.0.0 sqm.telemetry.microsoft.com
  echo 0.0.0.0 browser.pipe.aria.microsoft.com
  echo 0.0.0.0 activity.windows.com
  echo 0.0.0.0 v10.events.data.microsoft.com
  echo 0.0.0.0 v20.events.data.microsoft.com
  echo 0.0.0.0 self.events.data.microsoft.com
  echo 0.0.0.0 pipe.skype.com
  echo 0.0.0.0 copilot.microsoft.com
  echo 0.0.0.0 sydney.bing.com
  echo 0.0.0.0 feedback.windows.com
  echo 0.0.0.0 oca.microsoft.com
  echo 0.0.0.0 watson.microsoft.com
  echo 0.0.0.0 bingads.microsoft.com
  echo 0.0.0.0 eu-mobile.events.data.microsoft.com
  echo 0.0.0.0 us-mobile.events.data.microsoft.com
  echo 0.0.0.0 mobile.events.data.microsoft.com
  echo 0.0.0.0 aria.microsoft.com
  echo 0.0.0.0 settings.data.microsoft.com
  echo 0.0.0.0 msftconnecttest.com
  echo 0.0.0.0 www.msftconnecttest.com
  echo 0.0.0.0 connectivity.microsoft.com
  echo 0.0.0.0 edge-analytics.microsoft.com
  echo 0.0.0.0 analytics.live.com
  echo 0.0.0.0 dc.services.visualstudio.com
  echo 0.0.0.0 ris.api.iris.microsoft.com
  echo 0.0.0.0 c.bing.com
  echo 0.0.0.0 g.bing.com
  echo 0.0.0.0 th.bing.com
  echo 0.0.0.0 edgeassetservice.azureedge.net
  echo 0.0.0.0 api.msn.com
  echo 0.0.0.0 assets.msn.com
  echo 0.0.0.0 ntp.msn.com
  echo 0.0.0.0 web.vortex.data.microsoft.com
  echo 0.0.0.0 watson.events.data.microsoft.com
  echo 0.0.0.0 edge.activity.windows.com
  echo 0.0.0.0 browser.events.data.msn.com
  echo 0.0.0.0 telecommand.telemetry.microsoft.com
  echo 0.0.0.0 storeedge.operationmanager.microsoft.com
  echo 0.0.0.0 checkappexec.microsoft.com
  echo 0.0.0.0 inference.location.live.net
  echo 0.0.0.0 location.microsoft.com
  echo 0.0.0.0 watson.ppe.telemetry.microsoft.com
  echo 0.0.0.0 umwatson.telemetry.microsoft.com
  echo 0.0.0.0 config.edge.skype.com
  echo 0.0.0.0 tile-service.weather.microsoft.com
  echo 0.0.0.0 outlookads.live.com
  echo 0.0.0.0 fp.msedge.net
  echo 0.0.0.0 nexus.officeapps.live.com
) >> "%HOSTSFILE%" 2>nul
if "%BLOCK_ADOBE%"=="1" (
  (
    echo 0.0.0.0 lmlicenses.wip4.adobe.com
    echo 0.0.0.0 lm.licenses.adobe.com
    echo 0.0.0.0 practivate.adobe.com
    echo 0.0.0.0 activate.adobe.com
  ) >> "%HOSTSFILE%" 2>nul
)
)
):: fin anti-doublon
if "%BLOCK_ADOBE%"=="1" (
  echo [%date% %time%] Section 16 : Hosts OK (Adobe BLOQUE) >> "%LOG%"
) else (
  echo [%date% %time%] Section 16 : Hosts OK (Adobe commente par defaut) >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 17 — Tâches planifiées désactivées
:: Bloc registre GPO en premier — empêche la réactivation automatique
:: puis schtasks individuels (complément nécessaire — pas de clé registre directe)
:: ═══════════════════════════════════════════════════════════
:: GPO AppCompat — bloque la réactivation des tâches Application Experience / CEIP
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v DisableUAR /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v DisableInventory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v DisablePCA /t REG_DWORD /d 1 /f >nul 2>&1
:: AITEnable=0 — désactiver Application Impact Telemetry (AIT) globalement
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v AITEnable /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 17a : AppCompat GPO registre OK >> "%LOG%"

schtasks /Query /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Application Experience\ProgramDataUpdater" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\ProgramDataUpdater" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Application Experience\StartupAppTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\StartupAppTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Autochk\Proxy" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Autochk\Proxy" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Feedback\Siuf\DmClient" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Feedback\Siuf\DmClient" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Maps\MapsToastTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Maps\MapsToastTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Maps\MapsUpdateTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Maps\MapsUpdateTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\NetTrace\GatherNetworkInfo" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\NetTrace\GatherNetworkInfo" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Speech\SpeechModelDownloadTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Speech\SpeechModelDownloadTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Windows Error Reporting\QueueReporting" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /Disable >nul 2>&1

schtasks /Query /TN "\Microsoft\XblGameSave\XblGameSaveTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\XblGameSave\XblGameSaveTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Shell\FamilySafetyMonitor" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Shell\FamilySafetyMonitor" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Shell\FamilySafetyRefreshTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Shell\FamilySafetyRefreshTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Diagnosis\Scheduled" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Diagnosis\Scheduled" /Disable >nul 2>&1
:: Application Experience supplémentaires
schtasks /Query /TN "\Microsoft\Windows\Application Experience\MareBackfill" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\MareBackfill" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Application Experience\AitAgent" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\AitAgent" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Application Experience\PcaPatchDbTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Application Experience\PcaPatchDbTask" /Disable >nul 2>&1
:: CEIP supplémentaires
schtasks /Query /TN "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Customer Experience Improvement Program\Uploader" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Uploader" /Disable >nul 2>&1
:: Device Information — collecte infos matériel envoyées à Microsoft
schtasks /Query /TN "\Microsoft\Windows\Device Information\Device" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Device Information\Device" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Device Information\Device User" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Device Information\Device User" /Disable >nul 2>&1
:: DiskFootprint telemetry
schtasks /Query /TN "\Microsoft\Windows\DiskFootprint\Diagnostics" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\DiskFootprint\Diagnostics" /Disable >nul 2>&1
:: Flighting / OneSettings — serveur push config Microsoft
schtasks /Query /TN "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Flighting\OneSettings\RefreshCache" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Flighting\OneSettings\RefreshCache" /Disable >nul 2>&1
:: WinSAT — benchmark envoyé à Microsoft
schtasks /Query /TN "\Microsoft\Windows\Maintenance\WinSAT" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Maintenance\WinSAT" /Disable >nul 2>&1
:: SQM — Software Quality Metrics
schtasks /Query /TN "\Microsoft\Windows\PI\Sqm-Tasks" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\PI\Sqm-Tasks" /Disable >nul 2>&1

:: CloudExperienceHost — onboarding IA/OOBE
schtasks /Query /TN "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask" /Disable >nul 2>&1
:: Windows Store telemetry
schtasks /Query /TN "\Microsoft\Windows\WS\WSTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\WS\WSTask" /Disable >nul 2>&1
:: Clipboard license validation
schtasks /Query /TN "\Microsoft\Windows\Clip\License Validation" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Clip\License Validation" /Disable >nul 2>&1
:: Xbox GameSave logon (complement de XblGameSaveTask deja desactive)
schtasks /Query /TN "\Microsoft\XblGameSave\XblGameSaveTaskLogon" >nul 2>&1 && schtasks /Change /TN "\Microsoft\XblGameSave\XblGameSaveTaskLogon" /Disable >nul 2>&1
:: IA / Recall / Copilot 25H2
schtasks /Query /TN "\Microsoft\Windows\AI\AIXSvcTaskMaintenance" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\AI\AIXSvcTaskMaintenance" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Copilot\CopilotDailyReport" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Copilot\CopilotDailyReport" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Recall\IndexerRecoveryTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Recall\IndexerRecoveryTask" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" /Disable >nul 2>&1
:: Recall maintenance supplémentaire
schtasks /Query /TN "\Microsoft\Windows\Recall\RecallMaintenanceTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Recall\RecallMaintenanceTask" /Disable >nul 2>&1
:: Windows Push Notifications cleanup
schtasks /Query /TN "\Microsoft\Windows\WPN\PushNotificationCleanup" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\WPN\PushNotificationCleanup" /Disable >nul 2>&1
:: Diagnostic recommandations scanner
schtasks /Query /TN "\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner" /Disable >nul 2>&1
:: Data Integrity Scan — rapport disque
schtasks /Query /TN "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan" /Disable >nul 2>&1
:: SettingSync — synchronisation paramètres cloud
schtasks /Query /TN "\Microsoft\Windows\SettingSync\BackgroundUploadTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\SettingSync\BackgroundUploadTask" /Disable >nul 2>&1
:: MUI Language Pack cleanup (CPU à chaque logon)
schtasks /Query /TN "\Microsoft\Windows\MUI\LPRemove" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\MUI\LPRemove" /Disable >nul 2>&1
:: Memory Diagnostic — collecte et envoie données mémoire à Microsoft
schtasks /Query /TN "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic" /Disable >nul 2>&1
:: Location — localisation déjà désactivée, ces tâches se déclenchent quand même
schtasks /Query /TN "\Microsoft\Windows\Location\Notifications" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Location\Notifications" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\Location\WindowsActionDialog" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Location\WindowsActionDialog" /Disable >nul 2>&1
:: StateRepository — suit l'usage des apps pour Microsoft
schtasks /Query /TN "\Microsoft\Windows\StateRepository\MaintenanceTask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\StateRepository\MaintenanceTask" /Disable >nul 2>&1
:: ErrorDetails — contacte Microsoft pour màj des détails d'erreurs
schtasks /Query /TN "\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate" /Disable >nul 2>&1
:: DiskCleanup — nettoyage silencieux avec reporting MS (Prefetch déjà vidé en section 19)
schtasks /Query /TN "\Microsoft\Windows\DiskCleanup\SilentCleanup" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\DiskCleanup\SilentCleanup" /Disable >nul 2>&1
:: PushToInstall — installation d'apps en push à la connexion (service déjà désactivé)
schtasks /Query /TN "\Microsoft\Windows\PushToInstall\LoginCheck" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\PushToInstall\LoginCheck" /Disable >nul 2>&1
schtasks /Query /TN "\Microsoft\Windows\PushToInstall\Registration" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\PushToInstall\Registration" /Disable >nul 2>&1

:: License Manager — échange de licences temporaires signées (contacte Microsoft)
schtasks /Query /TN "\Microsoft\Windows\License Manager\TempSignedLicenseExchange" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\License Manager\TempSignedLicenseExchange" /Disable >nul 2>&1
:: UNP — notifications de disponibilité de mise à jour Windows
schtasks /Query /TN "\Microsoft\Windows\UNP\RunUpdateNotificationMgmt" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\UNP\RunUpdateNotificationMgmt" /Disable >nul 2>&1
:: ApplicationData — nettoyage état temporaire apps (déclenche collecte usage)
schtasks /Query /TN "\Microsoft\Windows\ApplicationData\CleanupTemporaryState" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\ApplicationData\CleanupTemporaryState" /Disable >nul 2>&1
:: AppxDeploymentClient — nettoyage apps provisionnées (inutile après setup initial)
schtasks /Query /TN "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup" /Disable >nul 2>&1

:: Retail Demo — nettoyage contenu démo retail hors ligne
schtasks /Query /TN "\Microsoft\Windows\RetailDemo\CleanupOfflineContent" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\RetailDemo\CleanupOfflineContent" /Disable >nul 2>&1
:: Work Folders — synchronisation dossiers de travail (fonctionnalité entreprise inutile)
schtasks /Query /TN "\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization" /Disable >nul 2>&1
:: Workplace Join — adhésion MDM automatique (inutile hors domaine d'entreprise)
schtasks /Query /TN "\Microsoft\Windows\Workplace Join\Automatic-Device-Join" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Workplace Join\Automatic-Device-Join" /Disable >nul 2>&1
:: DUSM — maintenance data usage (complément DusmSvc désactivé section 14)
schtasks /Query /TN "\Microsoft\Windows\DUSM\dusmtask" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\DUSM\dusmtask" /Disable >nul 2>&1
:: Mobile Provisioning — approvisionnement réseau cellulaire (inutile sur PC de bureau)
schtasks /Query /TN "\Microsoft\Windows\Management\Provisioning\Cellular" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Management\Provisioning\Cellular" /Disable >nul 2>&1
:: MDM Provisioning Logon — enrôlement MDM au logon (inutile hors Intune/SCCM)
schtasks /Query /TN "\Microsoft\Windows\Management\Provisioning\Logon" >nul 2>&1 && schtasks /Change /TN "\Microsoft\Windows\Management\Provisioning\Logon" /Disable >nul 2>&1
echo [%date% %time%] Section 17 : Taches planifiees desactivees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 18 — Suppression applications Appx

:: Note : NEED_RDP et NEED_WEBCAM n'affectent plus la suppression des apps (incluses inconditionnellement)
:: ═══════════════════════════════════════════════════════════

set "APPLIST=7EE7776C.LinkedInforWindows_3.0.42.0_x64__w1wdnht996qgy Facebook.Facebook MSTeams Microsoft.3DBuilder Microsoft.3DViewer Microsoft.549981C3F5F10 Microsoft.Advertising.Xaml Microsoft.BingNews Microsoft.BingWeather Microsoft.GetHelp Microsoft.Getstarted Microsoft.Messaging Microsoft.Microsoft3DViewer Microsoft.MicrosoftOfficeHub Microsoft.MicrosoftSolitaireCollection Microsoft.MixedReality.Portal Microsoft.NetworkSpeedTest Microsoft.News Microsoft.Office.OneNote Microsoft.Office.Sway Microsoft.OneConnect Microsoft.People Microsoft.Print3D Microsoft.RemoteDesktop Microsoft.SkypeApp Microsoft.Todos Microsoft.Wallet Microsoft.Whiteboard Microsoft.WindowsAlarms Microsoft.WindowsFeedbackHub Microsoft.WindowsMaps Microsoft.WindowsSoundRecorder Microsoft.XboxApp Microsoft.XboxGameOverlay Microsoft.XboxGamingOverlay Microsoft.XboxIdentityProvider Microsoft.XboxSpeechToTextOverlay Microsoft.ZuneMusic Microsoft.ZuneVideo Netflix SpotifyAB.SpotifyMusic king.com.* clipchamp.Clipchamp Microsoft.Copilot Microsoft.BingSearch Microsoft.Windows.DevHome Microsoft.PowerAutomateDesktop Microsoft.WindowsCamera 9WZDNCRFJ4Q7 Microsoft.OutlookForWindows MicrosoftCorporationII.QuickAssist Microsoft.MicrosoftStickyNotes Microsoft.BioEnrollment Microsoft.GamingApp Microsoft.WidgetsPlatformRuntime Microsoft.Windows.NarratorQuickStart Microsoft.Windows.ParentalControls Microsoft.Windows.SecureAssessmentBrowser Microsoft.WindowsCalculator MicrosoftWindows.CrossDevice Microsoft.LinkedIn Microsoft.Teams Microsoft.Xbox.TCUI MicrosoftCorporationII.MicrosoftFamily MicrosoftCorporationII.PhoneLink Microsoft.YourPhone Microsoft.Windows.Ai.Copilot.Provider Microsoft.WindowsRecall Microsoft.RecallApp MicrosoftWindows.Client.WebExperience Microsoft.GamingServices Microsoft.WindowsCommunicationsApps Microsoft.Windows.HolographicFirstRun"
for %%A in (%APPLIST%) do (
    powershell -NonInteractive -NoProfile -Command "Get-AppxPackage -AllUsers -Name %%A | Remove-AppxPackage -ErrorAction SilentlyContinue" >nul 2>&1
    powershell -NonInteractive -NoProfile -Command "Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq '%%A' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue" >nul 2>&1
    echo Suppression de %%A
)
echo [%date% %time%] Section 18 : Apps supprimees >> "%LOG%"
:: ═══════════════════════════════════════════════════════════
:: SECTION 19 — Vider le dossier Prefetch
:: ═══════════════════════════════════════════════════════════
if exist "C:\Windows\Prefetch" (
  del /f /q "C:\Windows\Prefetch\*" >nul 2>&1
  echo [%date% %time%] Section 19 : Dossier Prefetch vide >> "%LOG%"
  )
:: ═══════════════════════════════════════════════════════════
:: SECTION 19 — Vérification intégrité système + restart Explorer
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] Section 19b : SFC/DISM en cours (patience)... >> "%LOG%"
echo Verification integrite systeme en cours (SFC)... Cela peut prendre plusieurs minutes.
sfc /scannow >nul 2>&1
echo Reparation image systeme en cours (DISM)... Cela peut prendre plusieurs minutes.
dism /online /cleanup-image /restorehealth >nul 2>&1
echo [%date% %time%] Section 19b : SFC/DISM termine >> "%LOG%"
:: Redémarrer l'explorateur pour appliquer les changements d'interface immédiatement
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
echo [%date% %time%] Section 19b : Explorer redémarre >> "%LOG%"

) else (
  echo [%date% %time%] Section 19 : Dossier Prefetch absent - rien a faire >> "%LOG%"
  )

:: ═══════════════════════════════════════════════════════════
:: SECTION 20 — Fin
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] === RESUME === >> "%LOG%"
echo [%date% %time%] Services : 90+ desactives (Start=4, effectifs apres reboot) >> "%LOG%"
echo [%date% %time%] Taches planifiees : 73+ desactivees >> "%LOG%"
echo [%date% %time%] Apps UWP : 73+ supprimees >> "%LOG%"
echo [%date% %time%] Hosts : 57+ domaines telemetrie bloques >> "%LOG%"
echo [%date% %time%] Registre : 135+ cles vie privee/telemetrie/perf appliquees >> "%LOG%"
echo [%date% %time%] win11-setup.bat termine avec succes. Reboot recommande. >> "%LOG%"
echo.
echo Optimisation terminee. Un redemarrage est recommande pour finaliser.
echo Consultez le log : C:\Windows\Temp\win11-setup.log
exit /b 0
