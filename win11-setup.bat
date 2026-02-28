@echo off
setlocal enabledelayedexpansion

:: ═══════════════════════════════════════════════════════════
:: win11-setup.bat — Post-install Windows 11 25H2 optimisé 1 Go RAM
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
:: Méthode registre native — INTERDIT d'utiliser WMI/wmic pagefileset
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

echo [%date% %time%] Section 5 : Memoire/Prefetch/SysMain OK >> "%LOG%"

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
echo [%date% %time%] Section 6 : Telemetrie/AI/Copilot/Recall/SIUF/CEIP OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 7 — AutoLoggers télémétrie (désactivation à la source)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagTrack-Listener" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\DiagLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\SQMLogger" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\WiFiSession" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
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
echo [%date% %time%] Section 8 : WindowsSearch policies OK (WSearch conserve) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 9 — Edge / GameDVR / Delivery Optimization
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v AriaTelemetryEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
:: Edge — Copilot et fonctions IA désactivées
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v HubsSidebarEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeCopilotEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v CopilotPageContext /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeShoppingAssistantEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v PersonalizationReportingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v EdgeEnhanceImagesEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v SpotlightExperiencesAndRecommendationsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Edge — pré-lancement désactivé (empêche Edge de se lancer avant toute demande)
reg add "HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main" /v AllowPrelaunch /t REG_DWORD /d 0 /f >nul 2>&1
:: GameDVR — désactiver les optimisations plein écran (réduit overhead GPU)
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f >nul 2>&1
echo [%date% %time%] Section 9 : Edge/GameDVR/DeliveryOptimization OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 10 — Windows Update (non-destructif — wuauserv conservé)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v AllowAutoWindowsUpdateDownloadOverMeteredNetwork /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v RestartNotificationsAllowed2 /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 10 : Windows Update policies OK >> "%LOG%"

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
:: Notifications toast — clé non-policy directe (effet immédiat sans redémarrage — prérequis ligne 270)
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

:: Notifications toast — HKLM policy (system-wide, complément du HKCU ligne 170)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1

:: CloudContent — expériences personnalisées / Spotlight / SoftLanding
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1

:: Maps — empêche màj cartes (complément service MapsBroker désactivé)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maps" /v AutoDownloadAndUpdateMapData /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Maps" /v AllowUntriggeredNetworkTrafficOnSettingsPage /t REG_DWORD /d 0 /f >nul 2>&1

:: Speech — empêche màj modèle vocal (complément tâche SpeechModelDownloadTask désactivée)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Speech" /v AllowSpeechModelUpdate /t REG_DWORD /d 0 /f >nul 2>&1

:: Offline Files — policy (complément service CscService désactivé)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetCache" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1

:: AppPrivacy — empêche apps UWP de s'exécuter en arrière-plan (économie RAM sur 1 Go)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f >nul 2>&1

echo [%date% %time%] Section 11 : Vie privee/Securite/WER/InputPerso/CloudContent/Maps/Speech/NetCache/AppPrivacy OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 11b — CDP / Cloud Clipboard / ContentDeliveryManager / AppPrivacy étendu
:: ═══════════════════════════════════════════════════════════
:: Activity History — clés complémentaires (EnableActivityFeed couvert en section 11)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f >nul 2>&1

:: Cloud Clipboard et CDP Nearby Share désactivés
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v AllowClipboardHistory /t REG_DWORD /d 0 /f >nul 2>&1
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
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f >nul 2>&1
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

:: Lock Screen — désactiver caméra et diaporama
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenSlideshow /t REG_DWORD /d 1 /f >nul 2>&1

:: Écriture manuscrite — partage données désactivé
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1

:: Maintenance automatique Windows — désactiver (évite le polling Microsoft et les réveils réseau)
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" /v MaintenanceDisabled /t REG_DWORD /d 1 /f >nul 2>&1

:: Localisation — clés supplémentaires (complément DisableLocation section 11)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocationScripting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableWindowsLocationProvider /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableSensors /t REG_DWORD /d 1 /f >nul 2>&1

:: Langue — ne pas exposer la liste de langues aux sites web
reg add "HKCU\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1

echo [%date% %time%] Section 11b : CDP/Clipboard/NCSI/CDM/AppPrivacy/LockScreen/Handwriting/Maintenance/Geo OK >> "%LOG%"

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
reg add "HKCU\Software\Classes\CLSID\{e88865ea-0009-4384-87f5-7b8f32a3d6d5}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >nul 2>&1

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
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoInstrumentation /t REG_DWORD /d 1 /f >nul 2>&1

:: Copilot — masquer le bouton dans la barre des tâches (HKCU per-user)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f >nul 2>&1

:: Démarrer — arrêter le suivi programmes et documents récents
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1

:: Démarrer — masquer apps récemment ajoutées (HKLM policy)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f >nul 2>&1

:: Widgets — masquer le fil d'actualités (2=masqué — complément AllowNewsAndInterests=0)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f >nul 2>&1

echo [%date% %time%] Section 12 : Interface OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 13 — Priorité CPU applications premier plan
:: Win32PrioritySeparation : NON TOUCHE (valeur Windows par défaut)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v SystemResponsiveness /t REG_DWORD /d 10 /f >nul 2>&1
echo [%date% %time%] Section 13 : PriorityControl SystemResponsiveness=10 OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 14 — Services désactivés (Start=4, effectif après reboot)
:: NE PAS toucher : WSearch, WinDefend, wuauserv, RpcSs, PlugPlay, WlanSvc
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
reg add "HKLM\SYSTEM\CurrentControlSet\Services\TabletInputService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\lltdsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SensorDataService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SensrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\BingMapsGeocoder" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\PushToInstall" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\tiledatamodelsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
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
:: Cloud clipboard / sync cross-device
reg add "HKLM\SYSTEM\CurrentControlSet\Services\cbdhsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\CDPUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DevicesFlowUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Push notifications (livraison de pubs et alertes MS)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpnUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: GameDVR broadcast user
reg add "HKLM\SYSTEM\CurrentControlSet\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Diagnostics Policy / Hosts de diagnostic (déclenchent des troubleshooters qui phoned home)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DPS" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdiSystemHost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WdiServiceHost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\diagnosticshub.standardcollector.service" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Divers inutiles sur PC de bureau 1 Go RAM
reg add "HKLM\SYSTEM\CurrentControlSet\Services\DusmSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\icssvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SEMgrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\WpcMonSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\MixedRealityOpenXRSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NaturalAuthentication" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\SmsRouter" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 14 : Services Start=4 ecrits (effectifs apres reboot) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 15 — Arrêt immédiat des services listés
:: ═══════════════════════════════════════════════════════════
for %%S in (DiagTrack dmwappushsvc dmwappushservice diagsvc WerSvc wercplsupport NetTcpPortSharing RemoteAccess RemoteRegistry SharedAccess TrkWks WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc BDESVC wbengine Fax RetailDemo ScDeviceEnum SCardSvr AJRouter MessagingService SensorService PrintNotify wisvc lfsvc MapsBroker CDPSvc PhoneSvc WalletService AIXSvc CscService TabletInputService lltdsvc SensorDataService SensrSvc BingMapsGeocoder PushToInstall tiledatamodelsvc FontCache SysMain Ndu FDResPub SSDPSRV upnphost Recall WindowsAIService WinMLService CoPilotMCPService cbdhsvc CDPUserSvc DevicesFlowUserSvc WpnService WpnUserService BcastDVRUserService DPS WdiSystemHost WdiServiceHost DusmSvc icssvc SEMgrSvc WpcMonSvc MixedRealityOpenXRSvc NaturalAuthentication SmsRouter diagnosticshub.standardcollector.service) do (
  sc stop %%S >nul 2>&1
)
if "%NEED_BT%"=="0" sc stop BthAvctpSvc >nul 2>&1
echo [%date% %time%] Section 15 : sc stop envoye aux services listes >> "%LOG%"
:: Paramètres de récupération DiagTrack — Ne rien faire sur toutes défaillances
sc failure DiagTrack reset= 0 actions= none/0/none/0/none/0 >nul 2>&1
echo [%date% %time%] Section 15 : sc failure DiagTrack (aucune action sur defaillance) OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 16 — Fichier hosts (blocage télémétrie)
:: ═══════════════════════════════════════════════════════════
set HOSTSFILE=%windir%\System32\drivers\etc\hosts
copy "%HOSTSFILE%" "%HOSTSFILE%.bak" >nul 2>&1
(
  echo # Telemetry blocks - win11-setup
  echo 0.0.0.0 telemetry.microsoft.com
  echo 0.0.0.0 vortex.data.microsoft.com
  echo 0.0.0.0 settings-win.data.microsoft.com
  echo 0.0.0.0 watson.telemetry.microsoft.com
  echo 0.0.0.0 sqm.telemetry.microsoft.com
  echo 0.0.0.0 compat.smartscreen.microsoft.com
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
) >> "%HOSTSFILE%" 2>nul

:: Hosts Adobe — commentés par défaut (BLOCK_ADOBE=1 pour activer)
if "%BLOCK_ADOBE%"=="1" (
  (
    echo 0.0.0.0 lmlicenses.wip4.adobe.com
    echo 0.0.0.0 lm.licenses.adobe.com
    echo 0.0.0.0 practivate.adobe.com
    echo 0.0.0.0 activate.adobe.com
  ) >> "%HOSTSFILE%" 2>nul
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
echo [%date% %time%] Section 17a : AppCompat GPO registre OK >> "%LOG%"

schtasks /Change /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Application Experience\ProgramDataUpdater" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Application Experience\StartupAppTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Autochk\Proxy" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Feedback\Siuf\DmClient" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Maps\MapsToastTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Maps\MapsUpdateTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\NetTrace\GatherNetworkInfo" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Speech\SpeechModelDownloadTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Windows Error Reporting\QueueReporting" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\WindowsUpdate\Automatic App Update" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\XblGameSave\XblGameSaveTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Shell\FamilySafetyMonitor" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Shell\FamilySafetyRefreshTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Defrag\ScheduledDefrag" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Diagnosis\Scheduled" /Disable >nul 2>&1
:: Application Experience supplémentaires
schtasks /Change /TN "\Microsoft\Windows\Application Experience\AitAgent" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Application Experience\PcaPatchDbTask" /Disable >nul 2>&1
:: CEIP supplémentaires
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Uploader" /Disable >nul 2>&1
:: Device Information — collecte infos matériel envoyées à Microsoft
schtasks /Change /TN "\Microsoft\Windows\Device Information\Device" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Device Information\Device User" /Disable >nul 2>&1
:: DiskFootprint telemetry
schtasks /Change /TN "\Microsoft\Windows\DiskFootprint\Diagnostics" /Disable >nul 2>&1
:: Flighting / OneSettings — serveur push config Microsoft
schtasks /Change /TN "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Flighting\OneSettings\RefreshCache" /Disable >nul 2>&1
:: WinSAT — benchmark envoyé à Microsoft
schtasks /Change /TN "\Microsoft\Windows\Maintenance\WinSAT" /Disable >nul 2>&1
:: SQM — Software Quality Metrics
schtasks /Change /TN "\Microsoft\Windows\PI\Sqm-Tasks" /Disable >nul 2>&1
:: UpdateOrchestrator — rapport policy télémétrie
schtasks /Change /TN "\Microsoft\Windows\UpdateOrchestrator\Report policies" /Disable >nul 2>&1
:: CloudExperienceHost — onboarding IA/OOBE
schtasks /Change /TN "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask" /Disable >nul 2>&1
:: Windows Store telemetry
schtasks /Change /TN "\Microsoft\Windows\WS\WSTask" /Disable >nul 2>&1
:: Clipboard license validation
schtasks /Change /TN "\Microsoft\Windows\Clip\License Validation" /Disable >nul 2>&1
:: Xbox GameSave logon (complement de XblGameSaveTask deja desactive)
schtasks /Change /TN "\Microsoft\XblGameSave\XblGameSaveTaskLogon" /Disable >nul 2>&1
:: IA / Recall / Copilot 25H2
schtasks /Change /TN "\Microsoft\Windows\AI\AIXSvcTaskMaintenance" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Copilot\CopilotDailyReport" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Recall\IndexerRecoveryTask" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Recall\RecallScreenshotTask" /Disable >nul 2>&1
echo [%date% %time%] Section 17 : Taches planifiees desactivees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 18 — Suppression applications Appx
:: Liste "TOUJOURS supprimées" : exécution inconditionnelle
:: NEED_RDP et NEED_WEBCAM contrôlent les 2 apps optionnelles
:: Apps TOUJOURS conservées : Edge, Photos, OneDrive, Notepad, Terminal, DesktopAppInstaller, VCLibs, UI.Xaml, NET.Native
:: ═══════════════════════════════════════════════════════════

:: Lot 1 — apps toujours supprimées (liste principale)
powershell -NoProfile -NonInteractive -Command ^
"try { ^
  $apps = @( ^
    '7EE7776C.LinkedInforWindows', ^
    'Microsoft.LinkedIn', ^
    'Facebook.Facebook', ^
    'MSTeams', ^
    'Microsoft.Teams', ^
    'Microsoft.3DBuilder', ^
    'Microsoft.3DViewer', ^
    'Microsoft.549981C3F5F10', ^
    'Microsoft.Advertising.Xaml', ^
    'Microsoft.BingNews', ^
    'Microsoft.BingWeather', ^
    'Microsoft.BingSearch', ^
    'Microsoft.Copilot', ^
    'Microsoft.GetHelp', ^
    'Microsoft.Getstarted', ^
    'Microsoft.GamingApp', ^
    'Microsoft.Messaging', ^
    'Microsoft.MicrosoftOfficeHub', ^
    'Microsoft.MicrosoftSolitaireCollection', ^
    'Microsoft.MicrosoftStickyNotes', ^
    'Microsoft.MixedReality.Portal', ^
    'Microsoft.NetworkSpeedTest', ^
    'Microsoft.News', ^
    'Microsoft.Office.OneNote', ^
    'Microsoft.Office.Sway', ^
    'Microsoft.OneConnect', ^
    'Microsoft.OutlookForWindows', ^
    'Microsoft.People', ^
    'Microsoft.PowerAutomateDesktop', ^
    'Microsoft.Print3D', ^
    'Microsoft.ScreenSketch', ^
    'Microsoft.SkypeApp', ^
    'Microsoft.Todos', ^
    'Microsoft.Wallet', ^
    'Microsoft.Whiteboard', ^
    'Microsoft.WidgetsPlatformRuntime', ^
    'Microsoft.WindowsAlarms', ^
    'Microsoft.WindowsFeedbackHub', ^
    'Microsoft.WindowsMaps', ^
    'Microsoft.WindowsSoundRecorder', ^
    'Microsoft.Windows.DevHome', ^
    'Microsoft.Windows.NarratorQuickStart', ^
    'Microsoft.Windows.ParentalControls', ^
    'Microsoft.Windows.SecureAssessmentBrowser', ^
    'Microsoft.XboxApp', ^
    'Microsoft.Xbox.TCUI', ^
    'Microsoft.XboxGameOverlay', ^
    'Microsoft.XboxGamingOverlay', ^
    'Microsoft.XboxIdentityProvider', ^
    'Microsoft.XboxSpeechToTextOverlay', ^
    'Microsoft.ZuneMusic', ^
    'Microsoft.ZuneVideo', ^
    'MicrosoftWindows.CrossDevice', ^
    'MicrosoftCorporationII.QuickAssist', ^
    'MicrosoftCorporationII.MicrosoftFamily', ^
    'Netflix', ^
    'SpotifyAB.SpotifyMusic', ^
    'clipchamp.Clipchamp', ^
    'MicrosoftCorporationII.PhoneLink', ^
    'Microsoft.YourPhone', ^
    'Microsoft.Windows.Ai.Copilot.Provider', ^
    'Microsoft.WindowsRecall', ^
    'Microsoft.RecallApp' ^
  ); ^
  foreach ($a in $apps) { ^
    try { Get-AppxPackage -Name $a -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue } } catch {} ^
    try { $p = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like ('*' + $a + '*') }; if ($p) { $p | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue } } } catch {} ^
  } ^
} catch { }" >nul 2>&1
echo [%date% %time%] Section 18 Lot1 : Apps principales supprimees >> "%LOG%"

:: Lot 2 — wildcards (king.com.*, *Recall*)
powershell -NoProfile -NonInteractive -Command ^
"try { ^
  $wildcards = @('king.com', 'Windows.Recall'); ^
  foreach ($w in $wildcards) { ^
    try { Get-AppxPackage -Name ('*' + $w + '*') -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue } } catch {} ^
    try { $p = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like ('*' + $w + '*') }; if ($p) { $p | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue } } } catch {} ^
  } ^
} catch { }" >nul 2>&1
echo [%date% %time%] Section 18 Lot2 : Wildcards (king.com, Recall) OK >> "%LOG%"

:: Apps conditionnelles
if "%NEED_RDP%"=="0" (
  powershell -NoProfile -NonInteractive -Command "try { Get-AppxPackage -Name 'Microsoft.RemoteDesktop' -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like '*RemoteDesktop*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue } } catch { }" >nul 2>&1
  echo [%date% %time%] Section 18 : RemoteDesktop supprime (NEED_RDP=0) >> "%LOG%"
) else (
  echo [%date% %time%] Section 18 : RemoteDesktop conserve (NEED_RDP=1) >> "%LOG%"
)

if "%NEED_WEBCAM%"=="0" (
  powershell -NoProfile -NonInteractive -Command "try { Get-AppxPackage -Name 'Microsoft.WindowsCamera' -AllUsers -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }; Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like '*Camera*' } | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue } } catch { }" >nul 2>&1
  echo [%date% %time%] Section 18 : WindowsCamera supprimee (NEED_WEBCAM=0) >> "%LOG%"
) else (
  echo [%date% %time%] Section 18 : WindowsCamera conservee (NEED_WEBCAM=1) >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 19 — Vider le dossier Prefetch
:: ═══════════════════════════════════════════════════════════
if exist "C:\Windows\Prefetch" (
  del /f /q "C:\Windows\Prefetch\*" >nul 2>&1
  echo [%date% %time%] Section 19 : Dossier Prefetch vide >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 20 — Fin
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] win11-setup.bat termine avec succes. Reboot recommande. >> "%LOG%"
exit /b 0
