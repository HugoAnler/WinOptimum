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
) else (
  set FREE_GB=0
)
if %FREE_GB% GEQ 10 (
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v AutomaticManagedPagefile /t REG_DWORD /d 0 /f >nul 2>&1
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 6144 6144" /f >nul 2>&1
  echo [%date% %time%] Section 4 : Pagefile 6 Go fixe applique (espace OK : %FREE_GB% Go) >> "%LOG%"
) else (
  echo [%date% %time%] Section 4 : Pagefile auto conserve - espace insuffisant (%FREE_GB% Go) >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 5 — Mémoire : compression, prefetch, cache
:: ═══════════════════════════════════════════════════════════
:: Compression mémoire via MMAgent
powershell -NoProfile -NonInteractive -Command "try { Enable-MMAgent -MemoryCompression -ErrorAction Stop } catch { }" >nul 2>&1
echo [%date% %time%] Section 5 : Enable-MMAgent MemoryCompression attempted >> "%LOG%"

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
:: [hors prérequis] DisableOSUpgrade=1 bloque la montée vers une version majeure future (ex. Windows 12)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v DisableOSUpgrade /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 6 : Telemetrie/AI/Copilot/Recall OK >> "%LOG%"

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

:: Input Personalization (collecte frappe / encre)
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1

:: Géolocalisation désactivée (lfsvc désactivé en section 14 + registre)
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
:: Localisation bloquée par app (CapabilityAccessManager — UWP/Store apps)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1

:: Notifications toast désactivées
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1

:: AutoPlay / AutoRun désactivés (sécurité USB)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HonorAutorunSetting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1

:: Bloatware auto-install Microsoft bloqué
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1

:: WerFault / Rapport erreurs désactivé
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v DontSendAdditionalData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v LoggingDisabled /t REG_DWORD /d 1 /f >nul 2>&1

echo [%date% %time%] Section 11 : Vie privee/Securite OK >> "%LOG%"

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
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
powercfg /h off >nul 2>&1

:: Explorateur — divers (HKLM)
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoResolveTrack /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoInstrumentation /t REG_DWORD /d 1 /f >nul 2>&1

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
echo [%date% %time%] Section 14 : Services Start=4 ecrits (effectifs apres reboot) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 15 — Arrêt immédiat des services listés
:: ═══════════════════════════════════════════════════════════
for %%S in (DiagTrack dmwappushsvc dmwappushservice diagsvc WerSvc wercplsupport NetTcpPortSharing RemoteAccess RemoteRegistry SharedAccess TrkWks WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc BDESVC wbengine Fax RetailDemo ScDeviceEnum SCardSvr AJRouter MessagingService SensorService PrintNotify wisvc lfsvc MapsBroker CDPSvc PhoneSvc WalletService AIXSvc CscService TabletInputService lltdsvc SensorDataService SensrSvc BingMapsGeocoder PushToInstall tiledatamodelsvc FontCache SysMain) do (
  sc stop %%S >nul 2>&1
)
if "%NEED_BT%"=="0" sc stop BthAvctpSvc >nul 2>&1
echo [%date% %time%] Section 15 : sc stop envoye aux services listes >> "%LOG%"

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
) >> "%HOSTSFILE%" 2>nul

:: Hosts Adobe — commentés par défaut (KEEP_ADOBE=1 pour activer)
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
:: Appels individuels — pas de for loop (chemins avec espaces)
:: ═══════════════════════════════════════════════════════════
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
    'clipchamp.Clipchamp' ^
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
