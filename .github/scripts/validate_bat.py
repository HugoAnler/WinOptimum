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
