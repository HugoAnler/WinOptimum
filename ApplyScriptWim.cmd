@echo off
setlocal enabledelayedexpansion

:: ═══════════════════════════════════════════════════════════
:: optiwim.cmd — Applique les optimisations win11-setup sur image WIM hors-ligne
:: Usage : optiwim.cmd <WIM_PATH> [INDEX] [/MOUNT:chemin]
:: Exemple: optiwim.cmd install.wim 6
::          optiwim.cmd "D:\Sources\install.wim" 1 /MOUNT:D:\WinMount
::
:: Traductions registre offline :
::   HKLM\SOFTWARE\           → HKLM\WIM_SOFT\
::   HKLM\SYSTEM\CurrentControlSet\ → HKLM\WIM_SYS\ControlSet001\
::   HKLM\SYSTEM\Setup\       → HKLM\WIM_SYS\Setup\
::   HKCU\                    → HKU\WIM_USER\  (Users\Default\NTUSER.DAT)
::   HKU\.DEFAULT\            → HKU\WIM_DEFAULT\ (config\DEFAULT)
::
:: Non applicable hors-ligne (à exécuter via win11-setup.bat au premier logon) :
::   sc stop, sc failure, schtasks /Change (sauf XML), sfc, dism /online
:: ═══════════════════════════════════════════════════════════

:: ─────────────────────────────────────────────────────────
:: VALEURS PAR DEFAUT (ecrasees par les questions interactives)
:: ─────────────────────────────────────────────────────────
set NEED_RDP=0
set NEED_WEBCAM=0
set NEED_BT=0
set NEED_PRINTER=1
set BLOCK_ADOBE=0
set WIM_INDEX=1
set MOUNT_DIR=C:\WinMount

:: ─────────────────────────────────────────────────────────
set "LOG=%~dp0optiwim.log"
set WIM_MOUNTED=0
set HIVES_LOADED=0
echo [%date% %time%] optiwim.cmd start > "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 1 — Droits administrateur
:: ═══════════════════════════════════════════════════════════
openfiles >nul 2>&1
if errorlevel 1 (
    echo ERREUR : Ce script doit etre execute en tant qu'Administrateur.
    echo [%date% %time%] ERROR: not admin >> "%LOG%"
    exit /b 1
)
echo [%date% %time%] Section 1 : Admin OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 1b — Configuration interactive
:: ═══════════════════════════════════════════════════════════
echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║         optiwim.cmd — Configuration                 ║
echo ╚══════════════════════════════════════════════════════╝
echo  Repondre par O (oui) ou N (non). Entree = valeur par defaut.
echo.

set "_r=N"
set /p "_r=Bureau de controle a distance (RDP) necessaire ? [o/N] : "
if /i "!_r!"=="o" (set NEED_RDP=1) else (set NEED_RDP=0)

set "_r=N"
set /p "_r=Casques Bluetooth audio utilises (BthAvctpSvc) ? [o/N] : "
if /i "!_r!"=="o" (set NEED_BT=1) else (set NEED_BT=0)

set "_r=O"
set /p "_r=Imprimante presente (conserver Spooler) ? [O/n] : "
if /i "!_r!"=="n" (set NEED_PRINTER=0) else (set NEED_PRINTER=1)

set "_r=N"
set /p "_r=Bloquer les serveurs Adobe dans hosts ? [o/N] : "
if /i "!_r!"=="o" (set BLOCK_ADOBE=1) else (set BLOCK_ADOBE=0)

echo.
set "_r=C:\WinMount"
set /p "_r=Dossier de montage temporaire [C:\WinMount] : "
if not "!_r!"=="" set MOUNT_DIR=!_r!

echo.
echo  Configuration retenue :
echo   RDP       : !NEED_RDP!   (0=desactive  1=conserve)
echo   Bluetooth : !NEED_BT!   (0=desactive  1=conserve)
echo   Imprimante: !NEED_PRINTER!   (0=desactive  1=conserve)
echo   Adobe     : !BLOCK_ADOBE!   (0=non bloque 1=bloque)
echo   Montage   : !MOUNT_DIR!
echo.
echo [%date% %time%] Config: RDP=%NEED_RDP% BT=%NEED_BT% PRINTER=%NEED_PRINTER% ADOBE=%BLOCK_ADOBE% MOUNT=%MOUNT_DIR% >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 2 — Chemin WIM et index
:: ═══════════════════════════════════════════════════════════
if "%~1"=="" (
    set "_r="
    set /p "_r=Chemin du fichier WIM : "
    if "!_r!"=="" (
        echo ERREUR : Chemin WIM obligatoire.
        exit /b 1
    )
    set "WIM_FILE=!_r!"
) else (
    set "WIM_FILE=%~1"
)

:: Index : argument 2 ou question interactive
if not "%~2"=="" (
    echo %~2 | findstr /r "^[0-9][0-9]*$" >nul 2>&1
    if not errorlevel 1 set WIM_INDEX=%~2
) else (
    echo.
    dism /get-wiminfo /wimfile:"!WIM_FILE!" 2>nul | findstr /i "Index\|Name\|Description"
    echo.
    set "_r=1"
    set /p "_r=Index de l'image a optimiser [1] : "
    echo !_r! | findstr /r "^[0-9][0-9]*$" >nul 2>&1
    if not errorlevel 1 set WIM_INDEX=!_r!
)

if not exist "!WIM_FILE!" (
    echo ERREUR : Fichier WIM introuvable : !WIM_FILE!
    echo [%date% %time%] ERROR: WIM not found: !WIM_FILE! >> "%LOG%"
    exit /b 1
)

echo [%date% %time%] WIM=%WIM_FILE%  Index=%WIM_INDEX%  Mount=%MOUNT_DIR% >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 3 — Preflight
:: ═══════════════════════════════════════════════════════════
dism /? >nul 2>&1
if errorlevel 1 (
    echo ERREUR : DISM introuvable. Executer depuis une invite elevee Windows.
    echo [%date% %time%] ERROR: DISM not found >> "%LOG%"
    exit /b 1
)

if not exist "%MOUNT_DIR%" mkdir "%MOUNT_DIR%" >nul 2>&1

:: Vérifier que le dossier est vide
dir /b "%MOUNT_DIR%" 2>nul | findstr "." >nul 2>&1
if not errorlevel 1 (
    echo ERREUR : Dossier de montage non vide : %MOUNT_DIR%
    echo Nettoyez ou choisissez un autre chemin avec /MOUNT:
    echo [%date% %time%] ERROR: mount dir not empty >> "%LOG%"
    exit /b 1
)
echo [%date% %time%] Section 3 : Preflight OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 4 — Montage WIM
:: ═══════════════════════════════════════════════════════════
echo Montage image WIM index %WIM_INDEX% (quelques minutes)...
dism /mount-wim /wimfile:"%WIM_FILE%" /index:%WIM_INDEX% /mountdir:"%MOUNT_DIR%"
if errorlevel 1 (
    echo ERREUR : Echec montage WIM.
    echo [%date% %time%] ERROR: dism /mount-wim failed >> "%LOG%"
    goto :ERROR_EXIT
)
set WIM_MOUNTED=1
echo [%date% %time%] Section 4 : WIM monte dans %MOUNT_DIR% >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 5 — Chargement ruches registre
:: ═══════════════════════════════════════════════════════════
reg load "HKLM\WIM_SOFT" "%MOUNT_DIR%\Windows\System32\config\SOFTWARE"
if errorlevel 1 (
    echo ERREUR : Echec chargement ruche SOFTWARE.
    echo [%date% %time%] ERROR: reg load SOFTWARE failed >> "%LOG%"
    goto :ERROR_EXIT
)
reg load "HKLM\WIM_SYS" "%MOUNT_DIR%\Windows\System32\config\SYSTEM"
if errorlevel 1 (
    echo ERREUR : Echec chargement ruche SYSTEM.
    echo [%date% %time%] ERROR: reg load SYSTEM failed >> "%LOG%"
    reg unload "HKLM\WIM_SOFT" >nul 2>&1
    goto :ERROR_EXIT
)
reg load "HKU\WIM_USER" "%MOUNT_DIR%\Users\Default\NTUSER.DAT"
if errorlevel 1 (
    echo ERREUR : Echec chargement NTUSER.DAT utilisateur par defaut.
    echo [%date% %time%] ERROR: reg load NTUSER.DAT failed >> "%LOG%"
    reg unload "HKLM\WIM_SOFT" >nul 2>&1
    reg unload "HKLM\WIM_SYS" >nul 2>&1
    goto :ERROR_EXIT
)
reg load "HKU\WIM_DEFAULT" "%MOUNT_DIR%\Windows\System32\config\DEFAULT" >nul 2>&1
if errorlevel 1 (
    echo AVERTISSEMENT : Ruche DEFAULT non chargee ^(NumLock non applique^).
    echo [%date% %time%] WARN: reg load DEFAULT failed (non bloquant) >> "%LOG%"
)
set HIVES_LOADED=1
echo [%date% %time%] Section 5 : Ruches chargees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 6 — Mémoire / Pagefile / NTFS  (win11-setup sections 4+5)
:: ═══════════════════════════════════════════════════════════
:: Pagefile fixe 6 Go (vérification espace non applicable hors-ligne)
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management" /v AutomaticManagedPagefile /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys 6144 6144" /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management" /v MinFreeSystemCommit /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\MMAgent" /v EnableMemoryCompression /t REG_DWORD /d 1 /f >nul 2>&1
:: Prefetch / Superfetch désactivés
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management\PrefetchParameters" /v EnablePrefetcher /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Memory Management\PrefetchParameters" /v EnableSuperfetch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SysMain" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: PowerShell telemetry opt-out
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Environment" /v POWERSHELL_TELEMETRY_OPTOUT /t REG_SZ /d 1 /f >nul 2>&1
:: Délais fermeture réduits
reg add "HKLM\WIM_SYS\ControlSet001\Control" /v WaitToKillServiceTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v WaitToKillAppTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v HungAppTimeout /t REG_SZ /d 2000 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v AutoEndTasks /t REG_SZ /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f >nul 2>&1
:: Réseau
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\LanmanServer\Parameters" /v IRPStackSize /t REG_DWORD /d 30 /f >nul 2>&1
:: NTFS
reg add "HKLM\WIM_SYS\ControlSet001\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\FileSystem" /v NtfsDisableLastAccessUpdate /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\FileSystem" /v NtfsDisable8dot3NameCreation /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 6 : Memoire/Pagefile/NTFS OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 7 — Télémétrie / IA / Copilot / Recall  (win11-setup section 6)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsAI" /v AllowRecallEnablement /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v DontSendAdditionalData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v LoggingDisabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DiagTrack" /v DisableTelemetry /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\SQM" /v DisableSQM /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v DoNotShowFeedbackNotifications /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f >nul 2>&1
:: Recall 25H2
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v DisableRecallSnapshots /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v TurnOffSavingSnapshots /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v RecallFeatureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v HideRecallUIElements /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsAI" /v AIDashboardEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: IA master switch NPU/ML
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsAI" /v EnableWindowsAI /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsAI" /v AllowOnDeviceML /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsAI" /v DisableWinMLFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsCopilot" /v DisableCopilotService /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Siuf\Rules" /v PeriodInNanoSeconds /t REG_DWORD /d 0 /f >nul 2>&1
:: Defender — SubmitSamplesConsent=0 (jamais 2 — affaiblirait Defender)
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows Defender\Spynet" /v SubmitSamplesConsent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows Defender\Spynet" /v SpynetReporting /t REG_DWORD /d 0 /f >nul 2>&1
:: DataCollection complémentaires
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v MaxTelemetryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v LimitDiagnosticLogCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v DisableDiagnosticDataViewer /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v AllowDeviceNameInTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v LimitEnhancedDiagnosticDataWindowsAnalytics /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v MicrosoftEdgeDataOptIn /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform" /v NoGenTicket /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\PolicyManager\current\device\System" /v AllowExperimentation /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DataCollection" /v DisableOneSettingsDownloads /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\SystemSettings\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
:: Recherche / Cortana / Skype
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsDeviceSearchHistoryEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsDynamicSearchBoxEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsAADCloudSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings" /v IsMSACloudSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\AppSettings" /v Skype-UserConsentAccepted /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v AccountNotifications /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall" /v Value /t REG_SZ /d Deny /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 7 : Telemetrie/AI/Copilot/Recall/CEIP OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 8 — AutoLoggers  (win11-setup section 7)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\DiagTrack-Listener" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\DiagLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\SQMLogger" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\WiFiSession" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\CloudExperienceHostOobe" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\NtfsLog" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\WMI\Autologger\ReadyBoot" /v Start /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 8 : AutoLoggers desactives >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 9 — Windows Search policies  (win11-setup section 8)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsSearch" /v DisableWebSearch /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsSearch" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsSearch" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v CortanaConsent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v ConnectedSearchUseWeb /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v AllowCloudSearch /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v AllowSearchToUseLocation /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v PreventIndexingOutlook /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 9 : WindowsSearch policies OK (WSearch conserve) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 10 — GameDVR / Delivery Optimization  (win11-setup section 9)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\GameDVR" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\GameDVR" /v AllowGameDVR /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Messaging" /v AllowMessageSync /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\System\GameConfigStore" /v GameDVR_FSEBehavior /t REG_DWORD /d 2 /f >nul 2>&1
echo [%date% %time%] Section 10 : GameDVR/DeliveryOptimization OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 11 — Windows Update  (win11-setup section 10)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsUpdate" /v AllowAutoWindowsUpdateDownloadOverMeteredNetwork /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsUpdate" /v RestartNotificationsAllowed2 /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsUpdate\Settings" /v AllowMUUpdateService /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\WindowsUpdate\Settings" /v IsExpedited /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Settings" /v IsContinuousInnovationOptedIn /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\WindowsStore" /v AutoDownload /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 11 : Windows Update policies OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 12 — Vie privée / Sécurité / WER  (win11-setup sections 11+11b)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AdvertisingInfo" /v DisabledByGroupPolicy /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Connect" /v AllowProjectionToPC /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Remote Assistance" /v fAllowToGetHelp /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Remote Assistance" /v fAllowFullControl /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications" /v ToastEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HonorAutorunSetting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoDriveTypeAutoRun /t REG_DWORD /d 255 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\Windows Error Reporting" /v DontSendAdditionalData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\Windows Error Reporting" /v LoggingDisabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\Windows Error Reporting" /v DontShowUI /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\InputPersonalization" /v RestrictImplicitInkCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\InputPersonalization" /v RestrictImplicitTextCollection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\InputPersonalization" /v AllowInputPersonalization /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CurrentVersion\PushNotifications" /v NoToastApplicationNotification /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CloudContent" /v DisableSoftLanding /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsSpotlightFeatures /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\CloudContent" /v DisableCloudOptimizedContent /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Maps" /v AutoDownloadAndUpdateMapData /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Maps" /v AllowUntriggeredNetworkTrafficOnSettingsPage /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Speech" /v AllowSpeechModelUpdate /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\NetCache" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsRunInBackground /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\SmartGlass" /v UserAuthPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\SmartGlass" /v BluetoothPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\lfsvc\Service\Configuration" /v Status /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" /v SensorPermissionState /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v AllowExperimentation /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul 2>&1
:: Section 11b — CDP / Cloud Clipboard / ContentDeliveryManager
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v AllowClipboardHistory /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v AllowCrossDeviceClipboard /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\System" /v DisableCdp /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /v RomeSdkChannelUserAuthzPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" /v CdpSessionUserAuthzPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\NetworkConnectivityStatusIndicator" /v NoActiveProbe /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore" /v HarvestContacts /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v PreInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v RotatingLockScreenOverlayEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338388Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-310093Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353698Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338389Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353694Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-353696Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
:: AppPrivacy étendu
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCamera /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessMicrophone /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessLocation /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessAccountInfo /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessContacts /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCalendar /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessCallHistory /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessEmail /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessMessaging /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessTasks /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessRadios /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsActivateWithVoice /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsActivateWithVoiceAboveLock /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppPrivacy" /v LetAppsAccessBackgroundSpatialPerception /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Personalization" /v NoLockScreenSlideshow /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" /v MaintenanceDisabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocationScripting /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\LocationAndSensors" /v DisableWindowsLocationProvider /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\LocationAndSensors" /v DisableSensors /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSync /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\SettingSync" /v DisableSettingSyncUserOverride /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\StorageSense" /v AllowStorageSenseGlobal /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\International\User Profile" /v HttpAcceptLanguageOptOut /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Personalization\Settings" /v AcceptedPrivacyPolicy /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableThirdPartySuggestions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableTailoredExperiencesWithDiagnosticData /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Journaux événements réduits (économie disque/RAM 1 Go)
reg add "HKLM\WIM_SYS\ControlSet001\Services\EventLog\Application" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\EventLog\System" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\EventLog\Security" /v MaxSize /t REG_DWORD /d 1048576 /f >nul 2>&1
echo [%date% %time%] Section 12 : Vie privee/CDP/CDM/AppPrivacy/EventLog OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 13 — Interface utilisateur  (win11-setup section 12)
:: ═══════════════════════════════════════════════════════════
reg add "HKU\WIM_USER\Control Panel\Desktop" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v MinAnimate /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Explorer" /v TaskbarAlignment /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Dsh" /v AllowNewsAndInterests /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Chat" /v ChatIcon /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /t REG_SZ /d "" /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Classes\CLSID\{e88865ea-0009-4384-87f5-7b8f32a3d6d5}" /v "System.IsPinnedToNameSpaceTree" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /v "NonEnum" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\System" /v DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Winlogon" /v UserSetting_DisableStartupSound /t REG_DWORD /d 1 /f >nul 2>&1
:: Hibernation / Fast Startup désactivés (powercfg /h off non applicable hors-ligne — registre suffit)
reg add "HKLM\WIM_SYS\ControlSet001\Control\Power" /v HibernateEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Power" /v HibernateEnabledDefault /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
:: Explorateur
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoResolveTrack /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoRecentDocsHistory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v NoInstrumentation /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackProgs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Explorer" /v HideRecentlyAddedApps /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" /v ShellFeedsTaskbarViewMode /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\DWM" /v EnableAeroPeek /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 50 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v DisableThumbnailCache /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_ShowClassicMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" /v PeopleBand /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_IrisRecommendations /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_Recommendations /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Explorer" /v ShowRecentApps /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Explorer\Start" /v HideFrequentlyUsedApps /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Chat" /v Communications /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\Windows Chat" /v ConfigureChatAutoInstall /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer" /v HubMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v HubMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowFrequent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowRecent /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v ShowOrHideMostUsedApps /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer" /v ClearRecentDocsOnExit /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /v HiddenByDefault /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f >nul 2>&1
reg add "HKU\WIM_USER\Control Panel\Desktop" /v DragFullWindows /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v HideSCAMeetNow /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v DisableNotificationCenter /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" /v EnableFeeds /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" /v EnthusiastMode /t REG_DWORD /d 1 /f >nul 2>&1
echo [%date% %time%] Section 13 : Interface OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 14 — CPU / TCP / Config système  (win11-setup sections 13+13b)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SYS\ControlSet001\Control\PriorityControl" /v SystemResponsiveness /t REG_DWORD /d 10 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 10 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Priority" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Control\Power\PowerThrottling" /v PowerThrottlingOff /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\Tcpip\Parameters" /v TcpTimedWaitDelay /t REG_DWORD /d 30 /f >nul 2>&1
:: Bypass TPM/RAM (HKLM\SYSTEM\Setup — pas sous ControlSet001)
reg add "HKLM\WIM_SYS\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SYS\Setup\MoSetup" /v AllowUpgradesWithUnsupportedTPMOrCPU /t REG_DWORD /d 1 /f >nul 2>&1
:: Connexion sans mot de passe désactivée
reg add "HKLM\WIM_SOFT\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f >nul 2>&1
:: NumLock — ruche DEFAULT (profil service / écran de connexion)
reg add "HKU\WIM_DEFAULT\Control Panel\Keyboard" /v InitialKeyboardIndicators /t REG_DWORD /d 2 /f >nul 2>&1
:: Snap Assist désactivé
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v SnapAssist /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableSnapAssistFlyout /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKU\WIM_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v EnableTaskGroups /t REG_DWORD /d 0 /f >nul 2>&1
:: Menu alimentation
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowHibernateOption /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" /v ShowSleepOption /t REG_DWORD /d 0 /f >nul 2>&1
:: RDP conditionnel
if "%NEED_RDP%"=="0" reg add "HKLM\WIM_SYS\ControlSet001\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f >nul 2>&1
if "%NEED_RDP%"=="0" reg add "HKLM\WIM_SYS\ControlSet001\Services\TermService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 14 : CPU/TCP/LabConfig/PasswordLess/Snap OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 15 — Services Start=4  (win11-setup section 14)
:: NE PAS toucher : WSearch, WinDefend, wuauserv, RpcSs, PlugPlay, WlanSvc
::                  AppXSvc, seclogon, TokenBroker, OneSyncSvc, wlidsvc
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SYS\ControlSet001\Services\DiagTrack" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\dmwappushsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\dmwappushservice" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\diagsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WerSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\wercplsupport" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\NetTcpPortSharing" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\RemoteAccess" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\RemoteRegistry" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SharedAccess" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\TrkWks" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WMPNetworkSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\XblAuthManager" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\XblGameSave" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\XboxNetApiSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\XboxGipSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\BDESVC" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\wbengine" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
if "%NEED_BT%"=="0" reg add "HKLM\WIM_SYS\ControlSet001\Services\BthAvctpSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\Fax" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\RetailDemo" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\ScDeviceEnum" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SCardSvr" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\AJRouter" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\MessagingService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SensorService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\PrintNotify" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\wisvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\lfsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\MapsBroker" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\CDPSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\PhoneSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WalletService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\AIXSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\CscService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\lltdsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SensorDataService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SensrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\BingMapsGeocoder" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\PushToInstall" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\FontCache" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\Ndu" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\FDResPub" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SSDPSRV" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\upnphost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
:: Services 25H2 IA / Recall
reg add "HKLM\WIM_SYS\ControlSet001\Services\Recall" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WindowsAIService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WinMLService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\CoPilotMCPService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\cbdhsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\CDPUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\DevicesFlowUserSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WpnService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WpnUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\BcastDVRUserService" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\DPS" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WdiSystemHost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WdiServiceHost" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\diagnosticshub.standardcollector.service" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\DusmSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\icssvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SEMgrSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WpcMonSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\MixedRealityOpenXRSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\NaturalAuthentication" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\SmsRouter" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\defragsvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\DoSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WbioSrvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\EntAppSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\WManSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
reg add "HKLM\WIM_SYS\ControlSet001\Services\DmEnrollmentSvc" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
if "%NEED_PRINTER%"=="0" reg add "HKLM\WIM_SYS\ControlSet001\Services\Spooler" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
echo [%date% %time%] Section 15 : Services Start=4 ecrits (effectifs au premier boot) >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 16 — GPO AppCompat  (win11-setup section 17a)
:: ═══════════════════════════════════════════════════════════
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppCompat" /v DisableUAR /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppCompat" /v DisableInventory /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppCompat" /v DisablePCA /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\WIM_SOFT\Policies\Microsoft\Windows\AppCompat" /v AITEnable /t REG_DWORD /d 0 /f >nul 2>&1
echo [%date% %time%] Section 16 : AppCompat GPO OK >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 17 — Déchargement ruches
:: (avant DISM pour éviter les conflits de verrous)
:: ═══════════════════════════════════════════════════════════
powershell -NonInteractive -NoProfile -Command "[GC]::Collect(); [GC]::WaitForPendingFinalizers()" >nul 2>&1
ping 127.0.0.1 -n 3 >nul 2>&1
reg unload "HKU\WIM_DEFAULT" >nul 2>&1
reg unload "HKU\WIM_USER"
if errorlevel 1 (
    echo AVERTISSEMENT : Echec decharge HKU\WIM_USER - nouvelle tentative...
    echo [%date% %time%] WARN: reg unload WIM_USER failed, retry >> "%LOG%"
    ping 127.0.0.1 -n 4 >nul 2>&1
    reg unload "HKU\WIM_USER" >nul 2>&1
)
reg unload "HKLM\WIM_SOFT"
if errorlevel 1 echo [%date% %time%] WARN: reg unload WIM_SOFT failed >> "%LOG%"
reg unload "HKLM\WIM_SYS"
if errorlevel 1 echo [%date% %time%] WARN: reg unload WIM_SYS failed >> "%LOG%"
set HIVES_LOADED=0
echo [%date% %time%] Section 17 : Ruches dechargees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 18 — Suppression apps provisionnées (DISM offline)
:: Apps conservées : Edge, Photos, OneDriveSync, Notepad, Terminal,
::                   DesktopAppInstaller, VCLibs.*, UI.Xaml.*, NET.Native.*, ScreenSketch
:: ═══════════════════════════════════════════════════════════
echo Suppression des applications provisionnees (patience)...
set "PS1=%TEMP%\optiwim_apps.ps1"
(
  echo $mount = '%MOUNT_DIR%'
  echo $keep = @(
  echo   'Microsoft.MicrosoftEdge',
  echo   'Microsoft.Windows.Photos',
  echo   'Microsoft.OneDriveSync',
  echo   'Microsoft.WindowsNotepad',
  echo   'Microsoft.WindowsTerminal',
  echo   'Microsoft.DesktopAppInstaller',
  echo   'Microsoft.VCLibs',
  echo   'Microsoft.UI.Xaml',
  echo   'Microsoft.NET.Native',
  echo   'Microsoft.ScreenSketch'
  echo ^)
  echo $remove = @(
  echo   '7EE7776C.LinkedInforWindows', 'Facebook.Facebook', 'MSTeams',
  echo   'Microsoft.3DBuilder', 'Microsoft.3DViewer', 'Microsoft.549981C3F5F10',
  echo   'Microsoft.Advertising.Xaml', 'Microsoft.BingNews', 'Microsoft.BingWeather',
  echo   'Microsoft.BingSearch', 'Microsoft.Copilot', 'Microsoft.GetHelp',
  echo   'Microsoft.Getstarted', 'Microsoft.Messaging', 'Microsoft.Microsoft3DViewer',
  echo   'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
  echo   'Microsoft.MixedReality.Portal', 'Microsoft.NetworkSpeedTest', 'Microsoft.News',
  echo   'Microsoft.Office.OneNote', 'Microsoft.Office.Sway', 'Microsoft.OneConnect',
  echo   'Microsoft.OutlookForWindows', 'Microsoft.People', 'Microsoft.PowerAutomateDesktop',
  echo   'Microsoft.Print3D', 'Microsoft.RemoteDesktop', 'Microsoft.SkypeApp',
  echo   'Microsoft.Todos', 'Microsoft.Wallet', 'Microsoft.Whiteboard',
  echo   'Microsoft.WidgetsPlatformRuntime', 'Microsoft.WindowsAlarms',
  echo   'Microsoft.WindowsCamera', 'Microsoft.WindowsCalculator',
  echo   'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps',
  echo   'Microsoft.WindowsSoundRecorder', 'Microsoft.Windows.DevHome',
  echo   'Microsoft.Windows.NarratorQuickStart', 'Microsoft.Windows.ParentalControls',
  echo   'Microsoft.Windows.SecureAssessmentBrowser', 'Microsoft.XboxApp',
  echo   'Microsoft.Xbox.TCUI', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
  echo   'Microsoft.XboxIdentityProvider', 'Microsoft.XboxSpeechToTextOverlay',
  echo   'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo', 'MicrosoftWindows.CrossDevice',
  echo   'MicrosoftCorporationII.QuickAssist', 'MicrosoftCorporationII.MicrosoftFamily',
  echo   'MicrosoftCorporationII.PhoneLink', 'Microsoft.YourPhone',
  echo   'Microsoft.Windows.Ai.Copilot.Provider', 'Microsoft.WindowsRecall',
  echo   'Microsoft.RecallApp', 'MicrosoftWindows.Client.WebExperience',
  echo   'Microsoft.GamingServices', 'Microsoft.GamingApp', 'Microsoft.LinkedIn',
  echo   'Microsoft.Teams', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.BioEnrollment',
  echo   'Netflix', 'SpotifyAB.SpotifyMusic', 'clipchamp.Clipchamp',
  echo   'king.com', '9WZDNCRFJ4Q7'
  echo ^)
  echo try {
  echo   $pkgs = Get-AppxProvisionedPackage -Path $mount
  echo   foreach ($pkg in $pkgs) {
  echo     $name = $pkg.DisplayName
  echo     $skip = $false
  echo     foreach ($k in $keep) { if ($name -like "$k*") { $skip = $true; break } }
  echo     if ($skip) { Write-Host "Conserve : $name"; continue }
  echo     foreach ($p in $remove) {
  echo       if ($name -like "$p*" -or $name -eq $p) {
  echo         Write-Host "Suppression : $name"
  echo         Remove-AppxProvisionedPackage -Path $mount -PackageName $pkg.PackageName -ErrorAction SilentlyContinue
  echo         break
  echo       }
  echo     }
  echo   }
  echo } catch { Write-Host "Erreur : $_" }
) > "%PS1%"
powershell -NonInteractive -NoProfile -File "%PS1%"
del "%PS1%" >nul 2>&1
echo [%date% %time%] Section 18 : Apps provisionnees supprimees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 19 — Fichier hosts  (win11-setup section 16)
:: ═══════════════════════════════════════════════════════════
set "HOSTSFILE=%MOUNT_DIR%\Windows\System32\drivers\etc\hosts"
if not exist "%HOSTSFILE%" (
    echo # Windows hosts file > "%HOSTSFILE%"
    echo 127.0.0.1 localhost >> "%HOSTSFILE%"
    echo ::1 localhost >> "%HOSTSFILE%"
)
(
  echo # Telemetry blocks - optiwim
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
  echo 0.0.0.0 aria.microsoft.com
  echo 0.0.0.0 settings.data.microsoft.com
  echo 0.0.0.0 msftconnecttest.com
  echo 0.0.0.0 www.msftconnecttest.com
  echo 0.0.0.0 connectivity.microsoft.com
  echo 0.0.0.0 edge-analytics.microsoft.com
  echo 0.0.0.0 analytics.live.com
  echo 0.0.0.0 dc.services.visualstudio.com
  echo 0.0.0.0 nav.smartscreen.microsoft.com
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
) >> "%HOSTSFILE%" 2>nul
if "%BLOCK_ADOBE%"=="1" (
    (
      echo 0.0.0.0 lmlicenses.wip4.adobe.com
      echo 0.0.0.0 lm.licenses.adobe.com
      echo 0.0.0.0 practivate.adobe.com
      echo 0.0.0.0 activate.adobe.com
    ) >> "%HOSTSFILE%" 2>nul
    echo [%date% %time%] Section 19 : Hosts OK (Adobe BLOQUE) >> "%LOG%"
) else (
    echo [%date% %time%] Section 19 : Hosts OK >> "%LOG%"
)

:: ═══════════════════════════════════════════════════════════
:: SECTION 20 — Tâches planifiées XML offline
:: Modifie <Enabled>true</Enabled> dans les fichiers XML des tâches montées.
:: Les tâches absentes du WIM sont ignorées silencieusement.
:: Note: win11-setup.bat complétera via schtasks au premier logon.
:: ═══════════════════════════════════════════════════════════
echo Desactivation taches planifiees (XML)...
set "PS2=%TEMP%\optiwim_tasks.ps1"
(
  echo $root = '%MOUNT_DIR%\Windows\System32\Tasks'
  echo $tasks = @(
  echo   '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
  echo   '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
  echo   '\Microsoft\Windows\Application Experience\StartupAppTask',
  echo   '\Microsoft\Windows\Application Experience\MareBackfill',
  echo   '\Microsoft\Windows\Application Experience\AitAgent',
  echo   '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
  echo   '\Microsoft\Windows\Autochk\Proxy',
  echo   '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
  echo   '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
  echo   '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
  echo   '\Microsoft\Windows\Customer Experience Improvement Program\BthSQM',
  echo   '\Microsoft\Windows\Customer Experience Improvement Program\Uploader',
  echo   '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
  echo   '\Microsoft\Windows\Feedback\Siuf\DmClient',
  echo   '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
  echo   '\Microsoft\Windows\Maps\MapsToastTask',
  echo   '\Microsoft\Windows\Maps\MapsUpdateTask',
  echo   '\Microsoft\Windows\NetTrace\GatherNetworkInfo',
  echo   '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
  echo   '\Microsoft\Windows\Speech\SpeechModelDownloadTask',
  echo   '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
  echo   '\Microsoft\Windows\WindowsUpdate\Automatic App Update',
  echo   '\Microsoft\XblGameSave\XblGameSaveTask',
  echo   '\Microsoft\XblGameSave\XblGameSaveTaskLogon',
  echo   '\Microsoft\Windows\Shell\FamilySafetyMonitor',
  echo   '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
  echo   '\Microsoft\Windows\Defrag\ScheduledDefrag',
  echo   '\Microsoft\Windows\Diagnosis\Scheduled',
  echo   '\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner',
  echo   '\Microsoft\Windows\Device Information\Device',
  echo   '\Microsoft\Windows\Device Information\Device User',
  echo   '\Microsoft\Windows\DiskFootprint\Diagnostics',
  echo   '\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures',
  echo   '\Microsoft\Windows\Flighting\OneSettings\RefreshCache',
  echo   '\Microsoft\Windows\Maintenance\WinSAT',
  echo   '\Microsoft\Windows\PI\Sqm-Tasks',
  echo   '\Microsoft\Windows\UpdateOrchestrator\Report policies',
  echo   '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
  echo   '\Microsoft\Windows\WS\WSTask',
  echo   '\Microsoft\Windows\Clip\License Validation',
  echo   '\Microsoft\Windows\AI\AIXSvcTaskMaintenance',
  echo   '\Microsoft\Windows\Copilot\CopilotDailyReport',
  echo   '\Microsoft\Windows\Recall\IndexerRecoveryTask',
  echo   '\Microsoft\Windows\Recall\RecallScreenshotTask',
  echo   '\Microsoft\Windows\Recall\RecallMaintenanceTask',
  echo   '\Microsoft\Windows\WPN\PushNotificationCleanup',
  echo   '\Microsoft\Windows\BITS\CacheMaintenanceTask',
  echo   '\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan',
  echo   '\Microsoft\Windows\SettingSync\BackgroundUploadTask',
  echo   '\Microsoft\Windows\MUI\LPRemove',
  echo   '\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents',
  echo   '\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic',
  echo   '\Microsoft\Windows\Location\Notifications',
  echo   '\Microsoft\Windows\Location\WindowsActionDialog',
  echo   '\Microsoft\Windows\StateRepository\MaintenanceTask',
  echo   '\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate',
  echo   '\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate',
  echo   '\Microsoft\Windows\DiskCleanup\SilentCleanup'
  echo ^)
  echo $n=0; $m=0
  echo foreach ($t in $tasks) {
  echo   $f = Join-Path $root $t
  echo   if (Test-Path $f) {
  echo     $m++
  echo     try {
  echo       $c = [System.IO.File]::ReadAllText($f)
  echo       if ($c -match '(?i)<Enabled>true</Enabled>') {
  echo         $c = $c -replace '(?i)<Enabled>true</Enabled>','<Enabled>false</Enabled>'
  echo         [System.IO.File]::WriteAllText($f, $c)
  echo         $n++
  echo       }
  echo     } catch {}
  echo   }
  echo }
  echo Write-Host "Taches XML : $n/$m modifiees"
) > "%PS2%"
powershell -NonInteractive -NoProfile -File "%PS2%"
del "%PS2%" >nul 2>&1
echo [%date% %time%] Section 20 : Taches XML desactivees >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 21 — Démontage et commit WIM
:: ═══════════════════════════════════════════════════════════
echo Commit et demontage WIM (patience)...
dism /unmount-wim /mountdir:"%MOUNT_DIR%" /commit
if errorlevel 1 (
    echo ERREUR : Echec commit WIM.
    echo [%date% %time%] ERROR: dism /commit failed >> "%LOG%"
    dism /unmount-wim /mountdir:"%MOUNT_DIR%" /discard >nul 2>&1
    exit /b 1
)
set WIM_MOUNTED=0
echo [%date% %time%] Section 21 : WIM commite et demonte >> "%LOG%"

:: ═══════════════════════════════════════════════════════════
:: SECTION 22 — Résumé
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] === RESUME optiwim === >> "%LOG%"
echo [%date% %time%] Registre  : 350+ cles (SOFT + SYS ControlSet001 + NTUSER.DAT + DEFAULT) >> "%LOG%"
echo [%date% %time%] Services  : 70+ Start=4 (effectifs au premier boot) >> "%LOG%"
echo [%date% %time%] Apps      : provisionnees supprimees (DISM offline) >> "%LOG%"
echo [%date% %time%] Hosts     : 44+ domaines telemetrie bloques >> "%LOG%"
echo [%date% %time%] Taches    : XML modifies (complement : win11-setup.bat au logon) >> "%LOG%"
echo [%date% %time%] optiwim termine avec succes. >> "%LOG%"
echo.
echo Optimisation WIM terminee.
echo Log : %LOG%
exit /b 0

:: ═══════════════════════════════════════════════════════════
:ERROR_EXIT
:: Nettoyage sur erreur — decharger ruches + discard WIM
:: ═══════════════════════════════════════════════════════════
echo [%date% %time%] ERROR_EXIT : nettoyage >> "%LOG%"
if "%HIVES_LOADED%"=="1" (
    powershell -NonInteractive -NoProfile -Command "[GC]::Collect(); [GC]::WaitForPendingFinalizers()" >nul 2>&1
    ping 127.0.0.1 -n 3 >nul 2>&1
    reg unload "HKU\WIM_DEFAULT" >nul 2>&1
    reg unload "HKU\WIM_USER" >nul 2>&1
    reg unload "HKLM\WIM_SOFT" >nul 2>&1
    reg unload "HKLM\WIM_SYS" >nul 2>&1
)
if "%WIM_MOUNTED%"=="1" (
    echo Abandon modifications (discard)...
    dism /unmount-wim /mountdir:"%MOUNT_DIR%" /discard >nul 2>&1
)
echo ECHEC. Log : %LOG%
exit /b 1
