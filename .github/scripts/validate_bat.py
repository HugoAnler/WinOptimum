#!/usr/bin/env python3
"""
Validation statique de win11-setup.bat
Vérifie le respect des règles absolues définies dans CLAUDE.md
Fonctionne sur linux/macOS — aucune exécution du script Windows requise
"""

import re
import sys
from pathlib import Path

SCRIPT_PATH = Path("win11-setup.bat")
PASS_MARK = "PASS"
FAIL_MARK = "FAIL"


def get_active_lines(content):
    """Retourne les lignes non-commentaires (hors '::') avec leur numéro."""
    result = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped and not stripped.startswith("::"):
            result.append((i, line))
    return result


# ─── Test 1 : Valeurs de registre formellement interdites ────────────────────

FORBIDDEN_REG_VALUES = [
    ("DisableFileSyncNGSC",            "bloque OneDrive au niveau système — formellement interdit"),
    ("SubmitSamplesConsent",            "Windows Defender — règle absolue"),
    ("SpynetReporting",                 "Windows Defender — règle absolue"),
    ("DisableNotificationCenter",       "centre de notifications conservé"),
    ("NoLockScreen",                    "écran de verrouillage conservé"),
    ("NoLockScreenCamera",              "écran de verrouillage conservé"),
    ("NoLockScreenSlideshow",           "écran de verrouillage conservé"),
    ("RotatingLockScreenEnabled",       "écran de verrouillage conservé"),
    ("DisableWindowsSpotlightFeatures", "Spotlight conservé"),
    ("Win32PrioritySeparation",         "jamais modifié — règle absolue"),
    ("BuiltInDnsClientEnabled",         "DNS Edge — choix utilisateur"),
    ("DnsOverHttpsMode",                "DNS Edge — choix utilisateur"),
    ("DnsOverHttpsTemplates",           "DNS Edge — choix utilisateur"),
]


def test_forbidden_reg_values(active_lines):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        for value, reason in FORBIDDEN_REG_VALUES:
            if value.lower() in low:
                errors.append(f"  Ligne {lineno}: valeur interdite '{value}' — {reason}")
                errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 2 : HKCU TaskbarAl interdit (seul HKLM TaskbarAlignment autorisé) ─

def test_hkcu_taskbaral(active_lines):
    errors = []
    for lineno, line in active_lines:
        if "reg add" not in line.lower():
            continue
        if re.search(r'\bHKCU\b', line, re.IGNORECASE) and \
           re.search(r'/v\s+TaskbarAl\b', line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: HKCU TaskbarAl interdit — utiliser HKLM TaskbarAlignment")
            errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 3 : Chemins Edge policy interdits ───────────────────────────────────

FORBIDDEN_EDGE_PATHS = [
    r"HKLM\SOFTWARE\Policies\Microsoft\Edge",
    r"HKLM\SOFTWARE\Policies\Microsoft\MicrosoftEdge",
]


def test_edge_policy_paths(active_lines):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        for path in FORBIDDEN_EDGE_PATHS:
            if path.lower() in low:
                errors.append(f"  Ligne {lineno}: chemin Edge policy interdit — affiche 'géré par une organisation'")
                errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 4 : Commandes formellement interdites ───────────────────────────────

FORBIDDEN_COMMANDS = [
    (r"\bPAUSE\b",                        "PAUSE (script silencieux)"),
    (r"\bshutdown\b.*?/r(?!\w)",          "shutdown /r (pas de redémarrage automatique)"),
    (r"\bSet-WmiInstance\b",              "WMI write — token COM absent en FirstLogonCommands"),
    (r"Win32_ComputerSystem.*?\.Put\(\)", "WMI Put() — interdit"),
]


def test_forbidden_commands(active_lines):
    errors = []
    for lineno, line in active_lines:
        for pattern, label in FORBIDDEN_COMMANDS:
            if re.search(pattern, line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: commande interdite — {label}")
                errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 5 : Services protégés jamais désactivés ────────────────────────────

PROTECTED_SERVICES = [
    # Règle absolue CLAUDE.md
    "WSearch", "WinDefend", "wuauserv", "RpcSs", "PlugPlay", "WlanSvc",
    "AppXSvc", "seclogon", "TokenBroker", "OneSyncSvc", "wlidsvc",
    # COM requis par Windows Update (0x80004002 si désactivés)
    "DPS", "WdiSystemHost", "WdiServiceHost",
    # Presse-papiers Win+V local
    "cbdhsvc",
    # Windows Update / Defender
    "BITS", "WaaSMedicSvc", "uhssvc",
    "SecurityHealthService", "wscsvc",
]


def test_protected_services_not_disabled(content, active_lines):
    errors = []

    for lineno, line in active_lines:
        if "reg add" not in line.lower():
            continue
        if "/d 4" not in line and "/d  4" not in line:
            continue
        for svc in PROTECTED_SERVICES:
            if re.search(rf"\\Services\\{re.escape(svc)}(\\|\"|\s)", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' désactivé (Start=4)")
                errors.append(f"    > {line.strip()}")

    for lineno, line in active_lines:
        for svc in PROTECTED_SERVICES:
            if re.search(rf"\bsc\s+stop\s+{re.escape(svc)}\b", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' arrêté (sc stop)")
                errors.append(f"    > {line.strip()}")
            if re.search(rf"\bsc\s+config\s+{re.escape(svc)}\b", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' configuré (sc config)")
                errors.append(f"    > {line.strip()}")

    for m in re.finditer(r"for\s+%%S\s+in\s+\(([^)]+)\)", content, re.IGNORECASE):
        loop_services = [s.strip() for s in m.group(1).split() if s.strip()]
        line_no = content[: m.start()].count("\n") + 1
        for svc in PROTECTED_SERVICES:
            for s in loop_services:
                if s.lower() == svc.lower():
                    errors.append(f"  Ligne ~{line_no}: service protégé '{svc}' dans une boucle for %%S")

    return errors


# ─── Test 6 : Apps protégées absentes de la liste de suppression ─────────────

PROTECTED_APPS = [
    "MicrosoftEdge",
    "Windows.Photos",
    "OneDriveSync",
    "WindowsNotepad",
    "WindowsTerminal",
    "DesktopAppInstaller",
    "VCLibs",
    "UI.Xaml",
    "NET.Native",
    "ScreenSketch",
]


def test_protected_apps_not_removed(content, active_lines):
    errors = []

    for lineno, line in active_lines:
        low = line.lower()
        if "remove-appxpackage" not in low and "remove-appxprovisionedpackage" not in low:
            continue
        for app in PROTECTED_APPS:
            if app.lower() in low:
                errors.append(f"  Ligne {lineno}: app protégée '{app}' dans Remove-AppxPackage")
                errors.append(f"    > {line.strip()}")

    m = re.search(r'set\s+"APPLIST=([^"]+)"', content, re.IGNORECASE)
    if m:
        applist = m.group(1)
        for app in PROTECTED_APPS:
            if app.lower() in applist.lower():
                errors.append(f"  APPLIST contient l'app protégée '{app}'")

    return errors


# ─── Test 7 : Domaines Windows Update non bloqués dans hosts ─────────────────

WU_DOMAINS = [
    "windowsupdate.com",
    "update.microsoft.com",
    "download.windowsupdate.com",
    "wu.microsoft.com",
    "wustat.windows.com",
    "ntservicepack.microsoft.com",
    "windowsupdate.microsoft.com",
]


def test_wu_domains_not_blocked(content):
    errors = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("::"):
            continue
        if "0.0.0.0" not in stripped and "127.0.0.1" not in stripped:
            continue
        for domain in WU_DOMAINS:
            if domain.lower() in stripped.lower():
                errors.append(f"  Ligne {i}: domaine Windows Update bloqué dans hosts — {domain}")
                errors.append(f"    > {stripped}")
    return errors


# ─── Test 8 : Pas de doublons dans les boucles for %%S ───────────────────────

def test_no_duplicate_services_in_loops(content):
    errors = []
    all_services = []

    for m in re.finditer(r"for\s+%%S\s+in\s+\(([^)]+)\)", content, re.IGNORECASE):
        services = [s.strip() for s in m.group(1).split() if s.strip()]
        all_services.extend(services)

    seen: dict = {}
    for svc in all_services:
        key = svc.lower()
        if key in seen:
            errors.append(f"  Service '{svc}' dupliqué dans les boucles for %%S")
        else:
            seen[key] = svc

    return errors


# ─── Test 9 : Pas de doublons dans les reg add Services Start=4 ──────────────

def test_no_duplicate_service_start4(active_lines):
    errors = []
    seen: dict = {}

    for lineno, line in active_lines:
        if "reg add" not in line.lower():
            continue
        if r"\services\\" not in line.lower():
            continue
        if "/d 4" not in line.lower():
            continue
        m = re.search(r"\\Services\\(\w+)", line, re.IGNORECASE)
        if m:
            svc = m.group(1)
            key = svc.lower()
            if key in seen:
                prev_lineno, _ = seen[key]
                errors.append(f"  Service '{svc}' dupliqué en Start=4 (lignes {prev_lineno} et {lineno})")
            else:
                seen[key] = (lineno, svc)

    return errors


# ─── Test 10 : Structure — 20 sections présentes ─────────────────────────────

def test_section_structure(content):
    errors = []
    for i in range(1, 21):
        if not re.search(rf"SECTION\s+{i}(?!\d)", content):
            errors.append(f"  Section {i} introuvable dans le script")
    return errors


# ─── Test 11 : Tâches Windows Update jamais désactivées ──────────────────────

PROTECTED_TASK_PATTERNS = [
    r"\\WindowsUpdate\\",
    r"\\WaaSMedic",
    r"\\UpdateOrchestrator\\",
    r"\\sih\\",
]


def test_wu_tasks_not_disabled(active_lines):
    errors = []
    for lineno, line in active_lines:
        if "schtasks" not in line.lower():
            continue
        if "/disable" not in line.lower():
            continue
        for pattern in PROTECTED_TASK_PATTERNS:
            if re.search(re.escape(pattern), line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: tâche Windows Update désactivée")
                errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 12 : Clés registre Windows Update jamais modifiées ─────────────────

WU_REG_PATH_PATTERNS = [
    r"\WindowsUpdate",
    r"\WaaSMedic",
    r"\UpdateOrchestrator",
]


def test_wu_reg_paths_untouched(active_lines):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        for path in WU_REG_PATH_PATTERNS:
            if path.lower() in low:
                errors.append(f"  Ligne {lineno}: clé registre Windows Update modifiée")
                errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 13 : Clés registre Windows Defender jamais modifiées ───────────────

def test_defender_reg_paths_untouched(active_lines):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        if r"\windows defender" in low:
            errors.append(f"  Ligne {lineno}: clé registre Windows Defender modifiée")
            errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 14 : Section 10 strictement vide ───────────────────────────────────

def test_section10_empty(content):
    errors = []
    lines = content.splitlines()
    in_s10 = False

    for i, line in enumerate(lines, 1):
        if "SECTION 10" in line:
            in_s10 = True
            continue
        if in_s10:
            if "SECTION 11" in line:
                break
            stripped = line.strip()
            if stripped.startswith("::") or not stripped:
                continue
            if stripped.lower().startswith("echo") and "section 10" in stripped.lower():
                continue
            errors.append(f"  Ligne {i}: commande active dans Section 10 (doit être vide)")
            errors.append(f"    > {stripped}")

    return errors


# ─── Test 15 : PowerShell toujours avec -NonInteractive ──────────────────────

def test_powershell_noninteractive(active_lines):
    errors = []
    for lineno, line in active_lines:
        # Cherche powershell invoqué comme commande (pas dans une chaîne PS entre guillemets)
        if not re.search(r'(?:^|&&|\()\s*powershell\b', line.strip(), re.IGNORECASE):
            continue
        if not re.search(r'-NonInteractive\b|-noni\b', line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: powershell sans -NonInteractive (risque exit code ≠ 0)")
            errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 16 : wmic write interdit (seul wmic logicaldisk get autorisé) ──────

def test_no_wmic_write(active_lines):
    errors = []
    for lineno, line in active_lines:
        if not re.search(r'\bwmic\b', line, re.IGNORECASE):
            continue
        # Ignorer les lignes echo (wmic mentionné dans un message de log, pas invoqué)
        if re.search(r'^\s*echo\b', line, re.IGNORECASE):
            continue
        # Exception documentée : wmic logicaldisk ... get (lecture seule, section 4)
        if re.search(r'\bwmic\s+logicaldisk\b.*\bget\b', line, re.IGNORECASE):
            continue
        errors.append(f"  Ligne {lineno}: wmic interdit sauf logicaldisk read-only")
        errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 17 : Marqueur anti-doublon hosts présent ───────────────────────────

def test_hosts_antiduplicate_marker(content):
    errors = []
    marker = "Telemetry blocks - win11-setup"
    # Vérifier que le marqueur est utilisé dans un findstr (garde anti-doublon)
    if not re.search(r'findstr\b.*Telemetry blocks - win11-setup', content, re.IGNORECASE):
        errors.append(f"  Marqueur anti-doublon hosts absent (findstr /C:\"{marker}\")")
    # Vérifier que le marqueur est aussi présent dans l'echo (en-tête de bloc hosts)
    if not re.search(r'echo.*Telemetry blocks - win11-setup', content, re.IGNORECASE):
        errors.append(f"  En-tête hosts absent (echo # {marker})")
    return errors


# ─── Test 18 : Lignes de log présentes pour les sections 1–19 ────────────────

def test_section_log_lines(content):
    """Chaque section 1-19 doit avoir au moins une ligne echo ... Section N."""
    errors = []
    for i in range(1, 20):
        # Cherche echo ... Section N : (dans les branches if/else aussi)
        if not re.search(rf'echo\b.*\bSection\s+{i}\b', content, re.IGNORECASE):
            errors.append(f"  Section {i} : ligne de log echo manquante")
    return errors


# ─── Test 19 : schtasks /Delete absent ───────────────────────────────────────

def test_no_schtasks_delete(active_lines):
    errors = []
    for lineno, line in active_lines:
        if re.search(r'\bschtasks\b.*?/Delete\b', line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: schtasks /Delete interdit — utiliser /Change /Disable")
            errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 20 : sc delete absent ──────────────────────────────────────────────

def test_no_sc_delete(active_lines):
    errors = []
    for lineno, line in active_lines:
        if re.search(r'\bsc\s+delete\b', line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: sc delete interdit (suppression permanente du service)")
            errors.append(f"    > {line.strip()}")
    return errors


# ─── Test 21 : Ordre des sections (1 → 20 séquentiel) ────────────────────────

def test_section_order(content):
    errors = []
    positions = []
    for i in range(1, 21):
        m = re.search(rf"SECTION\s+{i}(?!\d)", content)
        if m:
            positions.append((i, m.start()))

    for j in range(1, len(positions)):
        if positions[j][1] < positions[j - 1][1]:
            errors.append(
                f"  Section {positions[j][0]} apparaît avant Section {positions[j - 1][0]} "
                f"(ordre invalide)"
            )
    return errors


# ─── Test 22 : Variables de configuration définies ───────────────────────────

def test_config_variables(content):
    errors = []
    required = ["LOG", "NEED_RDP", "NEED_WEBCAM", "NEED_BT", "NEED_PRINTER", "BLOCK_ADOBE"]
    for var in required:
        if not re.search(rf'^set\s+{re.escape(var)}=', content, re.MULTILINE | re.IGNORECASE):
            errors.append(f"  Variable '{var}' non définie en tête de script")
    return errors


# ─── Test 23 : Vérification admin (openfiles) présente ───────────────────────

def test_admin_check_present(active_lines):
    errors = []
    found = any(re.search(r'\bopenfiles\b', line, re.IGNORECASE) for _, line in active_lines)
    if not found:
        errors.append("  Vérification admin manquante (openfiles absent)")
    return errors


# ─── Test 24 : Script se termine avec exit /b 0 ──────────────────────────────

def test_clean_exit(content):
    errors = []
    if not re.search(r'\bexit\s+/b\s+0\b', content, re.IGNORECASE):
        errors.append("  exit /b 0 absent — le script ne se termine pas proprement")
    return errors


# ─── Test 25 : En-tête batch valide (@echo off + setlocal) ───────────────────

def test_batch_header(content):
    errors = []
    lines = content.splitlines()
    first_active = next((l.strip() for l in lines if l.strip()), "")
    if not first_active.lower().startswith("@echo off"):
        errors.append(f"  Première ligne non '@echo off' : {first_active[:60]}")
    if not re.search(r'\bsetlocal\s+enabledelayedexpansion\b', content, re.IGNORECASE):
        errors.append("  'setlocal enabledelayedexpansion' absent (requis pour !variables!)")
    return errors


# ─── Test 26 : Apps mandatory présentes dans APPLIST ─────────────────────────

# Apps que le prerequis impose de supprimer (vérification présence dans APPLIST)
MANDATORY_APPS_TO_REMOVE = [
    "7EE7776C.LinkedInforWindows",
    "Facebook.Facebook",
    "MSTeams",
    "Microsoft.Teams",
    "Microsoft.3DBuilder",
    "Microsoft.3DViewer",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.549981C3F5F10",
    "Microsoft.Advertising.Xaml",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingSearch",
    "Microsoft.Copilot",
    "Microsoft.WindowsRecall",
    "Microsoft.RecallApp",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.GamingApp",
    "Microsoft.Messaging",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.NetworkSpeedTest",
    "Microsoft.News",
    "Microsoft.Office.OneNote",
    "Microsoft.Office.Sway",
    "Microsoft.OneConnect",
    "Microsoft.OutlookForWindows",
    "Microsoft.People",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.Print3D",
    "Microsoft.BioEnrollment",
    "Microsoft.RemoteDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.Todos",
    "Microsoft.Wallet",
    "Microsoft.Whiteboard",
    "Microsoft.WidgetsPlatformRuntime",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Windows.DevHome",
    "Microsoft.Windows.NarratorQuickStart",
    "Microsoft.Windows.ParentalControls",
    "Microsoft.Windows.SecureAssessmentBrowser",
    "Microsoft.XboxApp",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftWindows.CrossDevice",
    "MicrosoftCorporationII.QuickAssist",
    "MicrosoftCorporationII.MicrosoftFamily",
    "MicrosoftCorporationII.PhoneLink",
    "Microsoft.YourPhone",
    "Microsoft.Windows.Ai.Copilot.Provider",
    "Microsoft.LinkedIn",
    "Netflix",
    "SpotifyAB.SpotifyMusic",
    "clipchamp.Clipchamp",
    "king.com.",
    "Microsoft.WindowsCommunicationsApps",
    "Microsoft.Windows.HolographicFirstRun",
    "Microsoft.GamingServices",
    "MicrosoftWindows.Client.WebExperience",
]


def test_mandatory_apps_in_applist(content):
    errors = []
    m = re.search(r'set\s+"APPLIST=([^"]+)"', content, re.IGNORECASE)
    if not m:
        errors.append("  Variable APPLIST introuvable")
        return errors
    applist = m.group(1).lower()

    for app in MANDATORY_APPS_TO_REMOVE:
        if app.lower() not in applist:
            errors.append(f"  App mandatory absente de APPLIST : '{app}'")

    return errors


# ─── Test 27 : Services mandatory désactivés ─────────────────────────────────

# Services que le prerequis impose de désactiver
# Exclus : BthAvctpSvc (conditionnel NEED_BT), TermService/SessionEnv (conditionnel NEED_RDP),
#          Spooler (conditionnel NEED_PRINTER), uhssvc (conflit CLAUDE.md — protégé WU)
MANDATORY_SERVICES_DISABLED = [
    "DiagTrack", "dmwappushsvc", "dmwappushservice", "diagsvc",
    "WerSvc", "wercplsupport", "NetTcpPortSharing", "RemoteAccess",
    "RemoteRegistry", "SharedAccess", "TrkWks", "WMPNetworkSvc",
    "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc",
    "BDESVC", "wbengine", "Fax", "RetailDemo", "ScDeviceEnum", "SCardSvr",
    "AJRouter", "MessagingService", "SensorService", "PrintNotify", "wisvc",
    "lfsvc", "MapsBroker", "CDPSvc", "PhoneSvc", "WalletService", "AIXSvc",
    "CscService", "lltdsvc", "SensorDataService", "SensrSvc",
    "BingMapsGeocoder", "PushToInstall", "SysMain", "FontCache",
    "WpnService", "WpnUserService", "CDPUserSvc", "DevicesFlowUserSvc",
    "BcastDVRUserService", "diagnosticshub.standardcollector.service",
    "DusmSvc", "icssvc", "SEMgrSvc", "WpcMonSvc", "MixedRealityOpenXRSvc",
    "NaturalAuthentication", "SmsRouter", "Ndu", "FDResPub", "SSDPSRV",
    "upnphost", "Recall", "WindowsAIService", "WinMLService",
    "CoPilotMCPService", "DoSvc", "WbioSrvc", "EntAppSvc", "WManSvc",
    "DmEnrollmentSvc", "tzautoupdate", "wmiApSrv", "SDRSVC", "spectrum",
    "SharedRealitySvc", "p2pimsvc", "p2psvc", "PNRPsvc", "PNRPAutoReg",
    "PcaSvc", "stisvc", "TapiSrv", "WFDSConMgrSvc", "defragsvc",
]


def test_mandatory_services_disabled(content):
    """Vérifie que chaque service mandatory apparaît dans reg add Start=4 OU dans le for loop sc stop."""
    errors = []

    # Extraire la liste des services dans les boucles for %%S
    loop_services: set = set()
    for m in re.finditer(r"for\s+%%S\s+in\s+\(([^)]+)\)", content, re.IGNORECASE):
        for s in m.group(1).split():
            loop_services.add(s.strip().lower())

    for svc in MANDATORY_SERVICES_DISABLED:
        key = svc.lower()
        # Cherche reg add Services\NOM ... /d 4
        in_reg = bool(re.search(
            rf"\\Services\\{re.escape(svc)}(\\|\"|\s).*?/d\s+4",
            content, re.IGNORECASE
        ))
        # Cherche dans les boucles for %%S
        in_loop = key in loop_services

        if not in_reg and not in_loop:
            errors.append(f"  Service mandatory absent du script : '{svc}' (ni Start=4 ni sc stop loop)")

    return errors


# ─── Test 28 : Tâches planifiées mandatory désactivées ───────────────────────

# Tâches mandatory à désactiver (hors tâches protégées par CLAUDE.md :
# \WindowsUpdate\, \WaaSMedic\, \UpdateOrchestrator\, \BITS\)
MANDATORY_TASKS = [
    r"\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    r"\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    r"\Microsoft\Windows\Application Experience\StartupAppTask",
    r"\Microsoft\Windows\Application Experience\MareBackfill",
    r"\Microsoft\Windows\Application Experience\AitAgent",
    r"\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    r"\Microsoft\Windows\Autochk\Proxy",
    r"\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    r"\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
    r"\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    r"\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
    r"\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
    r"\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    r"\Microsoft\Windows\Feedback\Siuf\DmClient",
    r"\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    r"\Microsoft\Windows\Maps\MapsToastTask",
    r"\Microsoft\Windows\Maps\MapsUpdateTask",
    r"\Microsoft\Windows\NetTrace\GatherNetworkInfo",
    r"\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
    r"\Microsoft\Windows\Speech\SpeechModelDownloadTask",
    r"\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    r"\Microsoft\XblGameSave\XblGameSaveTask",
    r"\Microsoft\XblGameSave\XblGameSaveTaskLogon",
    r"\Microsoft\Windows\Shell\FamilySafetyMonitor",
    r"\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
    r"\Microsoft\Windows\Defrag\ScheduledDefrag",
    r"\Microsoft\Windows\Diagnosis\Scheduled",
    r"\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner",
    r"\Microsoft\Windows\Device Information\Device",
    r"\Microsoft\Windows\Device Information\Device User",
    r"\Microsoft\Windows\DiskFootprint\Diagnostics",
    r"\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures",
    r"\Microsoft\Windows\Flighting\OneSettings\RefreshCache",
    r"\Microsoft\Windows\Maintenance\WinSAT",
    r"\Microsoft\Windows\PI\Sqm-Tasks",
    r"\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
    r"\Microsoft\Windows\WS\WSTask",
    r"\Microsoft\Windows\Clip\License Validation",
    r"\Microsoft\Windows\AI\AIXSvcTaskMaintenance",
    r"\Microsoft\Windows\Copilot\CopilotDailyReport",
    r"\Microsoft\Windows\Recall\IndexerRecoveryTask",
    r"\Microsoft\Windows\Recall\RecallScreenshotTask",
    r"\Microsoft\Windows\Recall\RecallMaintenanceTask",
    r"\Microsoft\Windows\WPN\PushNotificationCleanup",
    r"\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan",
    r"\Microsoft\Windows\SettingSync\BackgroundUploadTask",
    r"\Microsoft\Windows\MUI\LPRemove",
    r"\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",
    r"\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic",
    r"\Microsoft\Windows\Location\Notifications",
    r"\Microsoft\Windows\Location\WindowsActionDialog",
    r"\Microsoft\Windows\StateRepository\MaintenanceTask",
    r"\Microsoft\Windows\ErrorDetails\EnableErrorDetailsUpdate",
    r"\Microsoft\Windows\ErrorDetails\ErrorDetailsUpdate",
    r"\Microsoft\Windows\DiskCleanup\SilentCleanup",
    r"\Microsoft\Windows\PushToInstall\LoginCheck",
    r"\Microsoft\Windows\PushToInstall\Registration",
    r"\Microsoft\Windows\License Manager\TempSignedLicenseExchange",
    r"\Microsoft\Windows\UNP\RunUpdateNotificationMgmt",
    r"\Microsoft\Windows\ApplicationData\CleanupTemporaryState",
    r"\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup",
    r"\Microsoft\Windows\RetailDemo\CleanupOfflineContent",
    r"\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization",
    r"\Microsoft\Windows\Workplace Join\Automatic-Device-Join",
    r"\Microsoft\Windows\DUSM\dusmtask",
    r"\Microsoft\Windows\Management\Provisioning\Cellular",
    r"\Microsoft\Windows\Management\Provisioning\Logon",
]


def test_mandatory_tasks_disabled(content):
    errors = []
    content_lower = content.lower()
    for task in MANDATORY_TASKS:
        if task.lower() not in content_lower:
            errors.append(f"  Tâche mandatory absente du script : '{task}'")
    return errors


# ─── Test 29 : Domaines télémétrie bloqués dans hosts ────────────────────────

MANDATORY_TELEMETRY_DOMAINS = [
    "telemetry.microsoft.com",
    "vortex.data.microsoft.com",
    "settings-win.data.microsoft.com",
    "watson.telemetry.microsoft.com",
    "sqm.telemetry.microsoft.com",
    "compat.smartscreen.microsoft.com",
    "browser.pipe.aria.microsoft.com",
    "activity.windows.com",
    "v10.events.data.microsoft.com",
    "v20.events.data.microsoft.com",
    "self.events.data.microsoft.com",
    "pipe.skype.com",
    "copilot.microsoft.com",
    "sydney.bing.com",
    "feedback.windows.com",
    "oca.microsoft.com",
    "watson.microsoft.com",
    "bingads.microsoft.com",
    "eu-mobile.events.data.microsoft.com",
    "us-mobile.events.data.microsoft.com",
    "mobile.events.data.microsoft.com",
    "edge.activity.windows.com",
    "browser.events.data.msn.com",
    "telecommand.telemetry.microsoft.com",
    "storeedge.operationmanager.microsoft.com",
    "checkappexec.microsoft.com",
    "inference.location.live.net",
    "location.microsoft.com",
    "watson.ppe.telemetry.microsoft.com",
    "umwatson.telemetry.microsoft.com",
    "config.edge.skype.com",
    "tile-service.weather.microsoft.com",
    "outlookads.live.com",
    "dl.delivery.mp.microsoft.com",
    "fp.msedge.net",
    "nexus.officeapps.live.com",
]


def test_mandatory_telemetry_hosts(content):
    """Vérifie que chaque domaine télémétrie mandatory est bloqué dans la section hosts."""
    errors = []
    # Isoler la section hosts (section 16)
    hosts_section = ""
    in_s16 = False
    for line in content.splitlines():
        if "SECTION 16" in line:
            in_s16 = True
        if in_s16 and "SECTION 17" in line:
            break
        if in_s16:
            hosts_section += line + "\n"

    if not hosts_section:
        errors.append("  Section 16 (hosts) introuvable")
        return errors

    hosts_lower = hosts_section.lower()
    for domain in MANDATORY_TELEMETRY_DOMAINS:
        if domain.lower() not in hosts_lower:
            errors.append(f"  Domaine télémétrie absent des hosts : '{domain}'")

    return errors


# ─── Test 30 : Optimisations clés appliquées ─────────────────────────────────

MANDATORY_OPTIMIZATIONS = [
    # (description, pattern à chercher dans le contenu actif)
    ("AllowTelemetry=0",           r'AllowTelemetry.*?/d\s+0'),
    ("AllowRecallEnablement=0",    r'AllowRecallEnablement.*?/d\s+0'),
    ("TurnOffWindowsCopilot=1",    r'TurnOffWindowsCopilot.*?/d\s+1'),
    ("DisableAIDataAnalysis=1",    r'DisableAIDataAnalysis.*?/d\s+1'),
    ("EnableMemoryCompression=1",  r'EnableMemoryCompression.*?/d\s+1'),
    ("HiberbootEnabled=0",         r'HiberbootEnabled.*?/d\s+0'),
    ("TaskbarAlignment=0 (HKLM)", r'HKLM.*TaskbarAlignment.*?/d\s+0'),
    ("AllowClipboardHistory=1",    r'AllowClipboardHistory.*?/d\s+1'),
    ("DODownloadMode=0",           r'DODownloadMode.*?/d\s+0'),
    ("BingSearchEnabled=0",        r'BingSearchEnabled.*?/d\s+0'),
    ("DisableWindowsConsumerFeatures=1", r'DisableWindowsConsumerFeatures.*?/d\s+1'),
    ("EnableActivityFeed=0",       r'EnableActivityFeed.*?/d\s+0'),
    ("GameDVR desactive",          r'(?:GameDVR_Enabled|AllowGameDVR).*?/d\s+0'),
    ("powercfg /h off",            r'\bpowercfg\b.*?/h\s+off'),
    ("Prefetch desactive",         r'EnablePrefetcher.*?/d\s+0'),
    ("SysMain desactive",          r'Services\\SysMain.*?/d\s+4'),
]


def test_mandatory_optimizations(content):
    errors = []
    for description, pattern in MANDATORY_OPTIMIZATIONS:
        if not re.search(pattern, content, re.IGNORECASE):
            errors.append(f"  Optimisation manquante : {description}")
    return errors


# ─── Test 31 : Suppression fichiers Panther (sécurité 25H2) ──────────────────

def test_panther_deletion(active_lines):
    """Vérifie que les fichiers Panther sont supprimés (mot de passe en clair 25H2)."""
    errors = []
    found_unattend = False
    found_original = False
    for _, line in active_lines:
        if "panther" in line.lower() and "unattend.xml" in line.lower() and "del" in line.lower():
            found_unattend = True
        if "panther" in line.lower() and "unattend-original.xml" in line.lower() and "del" in line.lower():
            found_original = True
    if not found_unattend:
        errors.append("  del Panther\\unattend.xml absent (mot de passe admin en clair 25H2)")
    if not found_original:
        errors.append("  del Panther\\unattend-original.xml absent")
    return errors


# ─── Test 32 : schtasks jamais dans une boucle for (chemins avec espaces) ────

def test_no_schtasks_in_for_loop(content):
    """schtasks /Change /TN ne doit jamais passer par une boucle for (espaces dans les chemins)."""
    errors = []
    # Cherche : for %%[A-Z] in (...) do ... schtasks /Change /TN %%[A-Z]
    # Indique que le TN vient d'une variable de boucle (dangereux avec espaces)
    if re.search(
        r'for\s+%%(\w)\s+in\s+\([^)]+\).*schtasks\s+/Change\s+/TN\s+%%\1',
        content, re.IGNORECASE | re.DOTALL
    ):
        errors.append("  schtasks /Change /TN dans une boucle for — chemins avec espaces seront tronqués")
    return errors


# ─── Exécution ────────────────────────────────────────────────────────────────

def run_test(name, errors):
    if errors:
        print(f"[{FAIL_MARK}] {name}")
        for e in errors:
            print(e)
        return False
    print(f"[{PASS_MARK}] {name}")
    return True


def main():
    if not SCRIPT_PATH.exists():
        print(f"[{FAIL_MARK}] Fichier introuvable: {SCRIPT_PATH}")
        sys.exit(1)

    content = SCRIPT_PATH.read_text(encoding="utf-8", errors="replace")
    active_lines = get_active_lines(content)
    total_lines = len(content.splitlines())

    print(f"Validation statique : {SCRIPT_PATH} ({total_lines} lignes)")
    print("=" * 65)

    tests = [
        # ── Registre ──────────────────────────────────────────────
        ("01 Valeurs de registre interdites",
            test_forbidden_reg_values(active_lines)),
        ("02 HKCU TaskbarAl interdit (HKLM TaskbarAlignment seul autorise)",
            test_hkcu_taskbaral(active_lines)),
        ("03 Chemins Edge policy interdits",
            test_edge_policy_paths(active_lines)),
        ("12 Registre Windows Update jamais modifie",
            test_wu_reg_paths_untouched(active_lines)),
        ("13 Registre Windows Defender jamais modifie",
            test_defender_reg_paths_untouched(active_lines)),
        ("14 Section 10 strictement vide (Windows Update intouche)",
            test_section10_empty(content)),
        # ── Services ──────────────────────────────────────────────
        ("05 Services proteges jamais desactives",
            test_protected_services_not_disabled(content, active_lines)),
        ("08 Pas de doublons dans les boucles for %%S",
            test_no_duplicate_services_in_loops(content)),
        ("09 Pas de doublons dans les reg add Start=4",
            test_no_duplicate_service_start4(active_lines)),
        ("20 sc delete absent",
            test_no_sc_delete(active_lines)),
        # ── Apps ──────────────────────────────────────────────────
        ("06 Apps protegees absentes de la liste de suppression",
            test_protected_apps_not_removed(content, active_lines)),
        # ── Commandes / syntaxe ────────────────────────────────────
        ("04 Commandes interdites (PAUSE / shutdown /r / WMI write)",
            test_forbidden_commands(active_lines)),
        ("15 PowerShell toujours avec -NonInteractive",
            test_powershell_noninteractive(active_lines)),
        ("16 wmic write interdit (seul logicaldisk read-only autorise)",
            test_no_wmic_write(active_lines)),
        ("19 schtasks /Delete absent",
            test_no_schtasks_delete(active_lines)),
        # ── Tâches planifiées ──────────────────────────────────────
        ("11 Taches Windows Update jamais desactivees",
            test_wu_tasks_not_disabled(active_lines)),
        # ── Hosts ─────────────────────────────────────────────────
        ("07 Domaines Windows Update non bloques dans hosts",
            test_wu_domains_not_blocked(content)),
        ("17 Marqueur anti-doublon hosts present",
            test_hosts_antiduplicate_marker(content)),
        # ── Structure ─────────────────────────────────────────────
        ("10 Structure : 20 sections presentes",
            test_section_structure(content)),
        ("18 Lignes de log presentes sections 1-19",
            test_section_log_lines(content)),
        ("21 Ordre des sections 1-20 sequentiel",
            test_section_order(content)),
        ("22 Variables de configuration definies",
            test_config_variables(content)),
        ("23 Verification admin (openfiles) presente",
            test_admin_check_present(active_lines)),
        ("24 Script termine avec exit /b 0",
            test_clean_exit(content)),
        ("25 En-tete batch valide (@echo off + setlocal)",
            test_batch_header(content)),
        # ── Prerequis — exhaustif ──────────────────────────────────
        ("26 Apps mandatory presentes dans APPLIST",
            test_mandatory_apps_in_applist(content)),
        ("27 Services mandatory desactives (Start=4 ou sc stop)",
            test_mandatory_services_disabled(content)),
        ("28 Taches planifiees mandatory desactivees",
            test_mandatory_tasks_disabled(content)),
        ("29 Domaines telemetrie bloques dans hosts",
            test_mandatory_telemetry_hosts(content)),
        ("30 Optimisations cles appliquees",
            test_mandatory_optimizations(content)),
        ("31 Suppression fichiers Panther (securite 25H2)",
            test_panther_deletion(active_lines)),
        ("32 schtasks jamais dans une boucle for",
            test_no_schtasks_in_for_loop(content)),
    ]

    passed = 0
    failed = 0
    for name, errors in tests:
        if run_test(name, errors):
            passed += 1
        else:
            failed += 1

    print("=" * 65)
    if failed == 0:
        print(f"OK : {passed}/{passed + failed} tests passes")
    else:
        print(f"ECHEC : {failed} test(s) echoue(s), {passed} passes")

    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
