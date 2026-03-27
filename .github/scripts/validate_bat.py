#!/usr/bin/env python3
"""
Validation statique de win11-setup.bat

Toutes les règles métier sont lues depuis prerequis_WIN11.md (source de vérité unique).
Seule la logique de détection (regex, exceptions conditionnelles) reste codée ici.
"""

import re
import sys
from pathlib import Path

SCRIPT_PATH = Path("win11-setup.bat")
PREREQ_PATH = Path("prerequis_WIN11.md")
PASS_MARK = "PASS"
FAIL_MARK = "FAIL"


# ─── Parser prerequis_WIN11.md ────────────────────────────────────────────────

def parse_table_section(content, heading_fragment):
    """
    Extrait toutes les valeurs entre backticks de la première colonne
    d'une section markdown identifiée par heading_fragment.
    """
    lines = content.splitlines()
    in_section = False
    values = []

    for line in lines:
        if line.startswith("## ") and heading_fragment in line:
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if not in_section:
            continue
        stripped = line.strip()
        if not stripped.startswith("|"):
            continue
        # Ignorer les lignes séparateurs (ex: |---|---|)
        if not stripped.replace("|", "").replace("-", "").replace(":", "").replace(" ", ""):
            continue
        cols = stripped.split("|")
        if len(cols) < 2:
            continue
        values.extend(re.findall(r"`([^`]+)`", cols[1]))

    return values


# ─── Exceptions conditionnelles (logique script — pas des règles métier) ──────

# Services conditionnels : présents dans prerequis mais exclus du test mandatory
# car dépendent des variables NEED_* du script, ou en conflit documenté
CONDITIONAL_SERVICES = {
    "BthAvctpSvc",  # conditionnel NEED_BT
    "TermService",  # conditionnel NEED_RDP
    "SessionEnv",   # conditionnel NEED_RDP
    "uhssvc",       # protégé WU (CLAUDE.md) mais listé dans prerequis comme à désactiver
}

# Motifs de tâches WU/WaaSMedic/UpdateOrchestrator — jamais désactivées (règle WU)
# Ces tâches sont filtrées du test mandatory même si présentes dans prerequis
WU_PROTECTED_TASK_RE = [
    r"\\WindowsUpdate\\",
    r"\\WaaSMedic",
    r"\\UpdateOrchestrator\\",
    r"\\sih\\",
]

# Motifs de tâches WU pour le test d'interdiction (test 11)
PROTECTED_TASK_PATTERNS = WU_PROTECTED_TASK_RE


def load_prerequis():
    """Charge prerequis_WIN11.md et retourne toutes les listes de référence."""
    if not PREREQ_PATH.exists():
        print(f"[{FAIL_MARK}] Fichier introuvable : {PREREQ_PATH}")
        sys.exit(1)

    content = PREREQ_PATH.read_text(encoding="utf-8", errors="replace")

    raw_services = parse_table_section(content, "Services TOUJOURS désactivés")
    raw_tasks    = parse_table_section(content, "Tâches planifiées TOUJOURS désactivées")

    return {
        # Apps
        "protected_apps":      parse_table_section(content, "Apps TOUJOURS conservées"),
        "mandatory_apps":      parse_table_section(content, "Apps TOUJOURS supprimées"),
        # Services
        "protected_services":  parse_table_section(content, "Services TOUJOURS conservés"),
        "mandatory_services":  [s for s in raw_services if s not in CONDITIONAL_SERVICES],
        # Tâches
        "mandatory_tasks":     [t for t in raw_tasks
                                if not any(re.search(p, t, re.IGNORECASE)
                                           for p in WU_PROTECTED_TASK_RE)],
        # Hosts
        "mandatory_domains":   parse_table_section(content, "Domaines TOUJOURS bloqués"),
        "wu_host_domains":     parse_table_section(content, "Domaines Windows Update jamais bloqués"),
        # Registre
        "forbidden_reg_values": parse_table_section(content, "Valeurs de registre jamais modifiées"),
        "forbidden_reg_paths":  parse_table_section(content, "Chemins de registre jamais écrits"),
    }


def get_active_lines(content):
    """Retourne les lignes non-commentaires (hors '::') avec leur numéro."""
    result = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped and not stripped.startswith("::"):
            result.append((i, line))
    return result


# ─── Logique de détection codée en dur (pas des règles métier) ────────────────
# Ces éléments sont des patterns de détection — ils ne peuvent pas être exprimés
# sous forme de simples valeurs dans un tableau markdown.

FORBIDDEN_COMMANDS = [
    (r"\bPAUSE\b",                        "PAUSE (script silencieux)"),
    (r"\bshutdown\b.*?/r(?!\w)",          "shutdown /r (pas de redémarrage automatique)"),
    (r"\bSet-WmiInstance\b",              "WMI write — token COM absent en FirstLogonCommands"),
    (r"Win32_ComputerSystem.*?\.Put\(\)", "WMI Put() — interdit"),
]

MANDATORY_OPTIMIZATIONS = [
    ("AllowTelemetry=0",                 r"AllowTelemetry.*?/d\s+0"),
    ("AllowRecallEnablement=0",          r"AllowRecallEnablement.*?/d\s+0"),
    ("TurnOffWindowsCopilot=1",          r"TurnOffWindowsCopilot.*?/d\s+1"),
    ("DisableAIDataAnalysis=1",          r"DisableAIDataAnalysis.*?/d\s+1"),
    ("EnableMemoryCompression=1",        r"EnableMemoryCompression.*?/d\s+1"),
    ("HiberbootEnabled=0",               r"HiberbootEnabled.*?/d\s+0"),
    ("TaskbarAlignment=0 (HKLM)",        r"HKLM.*TaskbarAlignment.*?/d\s+0"),
    ("AllowClipboardHistory=1",          r"AllowClipboardHistory.*?/d\s+1"),
    ("DODownloadMode=0",                 r"DODownloadMode.*?/d\s+0"),
    ("BingSearchEnabled=0",              r"BingSearchEnabled.*?/d\s+0"),
    ("DisableWindowsConsumerFeatures=1", r"DisableWindowsConsumerFeatures.*?/d\s+1"),
    ("EnableActivityFeed=0",             r"EnableActivityFeed.*?/d\s+0"),
    ("GameDVR desactive",                r"(?:GameDVR_Enabled|AllowGameDVR).*?/d\s+0"),
    ("powercfg /h off",                  r"\bpowercfg\b.*?/h\s+off"),
    ("Prefetch desactive",               r"EnablePrefetcher.*?/d\s+0"),
    ("SysMain desactive",                r"Services\\SysMain.*?/d\s+4"),
]


# ─── Tests ────────────────────────────────────────────────────────────────────

def test_forbidden_reg_values(active_lines, forbidden_reg_values):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        for value in forbidden_reg_values:
            if value.lower() in low:
                errors.append(f"  Ligne {lineno}: valeur de registre interdite '{value}'")
                errors.append(f"    > {line.strip()}")
    return errors


def test_hkcu_taskbaral(active_lines):
    errors = []
    for lineno, line in active_lines:
        if "reg add" not in line.lower():
            continue
        if re.search(r"\bHKCU\b", line, re.IGNORECASE) and \
           re.search(r"/v\s+TaskbarAl\b", line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: HKCU TaskbarAl interdit — utiliser HKLM TaskbarAlignment")
            errors.append(f"    > {line.strip()}")
    return errors


def test_forbidden_reg_paths(active_lines, forbidden_reg_paths):
    """Vérifie qu'aucun chemin de registre interdit n'apparaît dans reg add/delete."""
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "reg add" not in low and "reg delete" not in low:
            continue
        for path in forbidden_reg_paths:
            if path.lower() in low:
                errors.append(f"  Ligne {lineno}: chemin de registre interdit '{path}'")
                errors.append(f"    > {line.strip()}")
    return errors


def test_forbidden_commands(active_lines):
    errors = []
    for lineno, line in active_lines:
        for pattern, label in FORBIDDEN_COMMANDS:
            if re.search(pattern, line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: commande interdite — {label}")
                errors.append(f"    > {line.strip()}")
    return errors


def test_protected_services_not_disabled(content, active_lines, protected_services):
    errors = []

    for lineno, line in active_lines:
        if "reg add" not in line.lower():
            continue
        if "/d 4" not in line and "/d  4" not in line:
            continue
        for svc in protected_services:
            if re.search(rf"\\Services\\{re.escape(svc)}(\\|\"|\s)", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' désactivé (Start=4)")
                errors.append(f"    > {line.strip()}")

    for lineno, line in active_lines:
        for svc in protected_services:
            if re.search(rf"\bsc\s+stop\s+{re.escape(svc)}\b", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' arrêté (sc stop)")
                errors.append(f"    > {line.strip()}")
            if re.search(rf"\bsc\s+config\s+{re.escape(svc)}\b", line, re.IGNORECASE):
                errors.append(f"  Ligne {lineno}: service protégé '{svc}' configuré (sc config)")
                errors.append(f"    > {line.strip()}")

    for m in re.finditer(r"for\s+%%S\s+in\s+\(([^)]+)\)", content, re.IGNORECASE):
        loop_services = [s.strip() for s in m.group(1).split() if s.strip()]
        line_no = content[: m.start()].count("\n") + 1
        for svc in protected_services:
            for s in loop_services:
                if s.lower() == svc.lower():
                    errors.append(f"  Ligne ~{line_no}: service protégé '{svc}' dans une boucle for %%S")

    return errors


def test_protected_apps_not_removed(content, active_lines, protected_apps):
    errors = []
    for lineno, line in active_lines:
        low = line.lower()
        if "remove-appxpackage" not in low and "remove-appxprovisionedpackage" not in low:
            continue
        for app in protected_apps:
            if app.startswith("*"):
                continue
            search = app.rstrip("*").lower()
            if search in low:
                errors.append(f"  Ligne {lineno}: app protégée '{app}' dans Remove-AppxPackage")
                errors.append(f"    > {line.strip()}")

    m = re.search(r'set\s+"APPLIST=([^"]+)"', content, re.IGNORECASE)
    if m:
        applist = m.group(1).lower()
        for app in protected_apps:
            if app.startswith("*"):
                continue
            search = app.rstrip("*").lower()
            if search in applist:
                errors.append(f"  APPLIST contient l'app protégée '{app}'")

    return errors


def test_wu_domains_not_blocked(content, wu_host_domains):
    errors = []
    for i, line in enumerate(content.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("::"):
            continue
        if "0.0.0.0" not in stripped and "127.0.0.1" not in stripped:
            continue
        for domain in wu_host_domains:
            if domain.lower() in stripped.lower():
                errors.append(f"  Ligne {i}: domaine Windows Update bloqué dans hosts — {domain}")
                errors.append(f"    > {stripped}")
    return errors


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


def test_section_structure(content):
    errors = []
    for i in range(1, 21):
        if not re.search(rf"SECTION\s+{i}(?!\d)", content):
            errors.append(f"  Section {i} introuvable dans le script")
    return errors


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


def test_powershell_noninteractive(active_lines):
    errors = []
    for lineno, line in active_lines:
        if not re.search(r"(?:^|&&|\()\s*powershell\b", line.strip(), re.IGNORECASE):
            continue
        if not re.search(r"-NonInteractive\b|-noni\b", line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: powershell sans -NonInteractive (risque exit code ≠ 0)")
            errors.append(f"    > {line.strip()}")
    return errors


def test_no_wmic_write(active_lines):
    errors = []
    for lineno, line in active_lines:
        if not re.search(r"\bwmic\b", line, re.IGNORECASE):
            continue
        if re.search(r"^\s*echo\b", line, re.IGNORECASE):
            continue
        if re.search(r"\bwmic\s+logicaldisk\b.*\bget\b", line, re.IGNORECASE):
            continue
        errors.append(f"  Ligne {lineno}: wmic interdit sauf logicaldisk read-only")
        errors.append(f"    > {line.strip()}")
    return errors


def test_hosts_antiduplicate_marker(content):
    errors = []
    marker = "Telemetry blocks - win11-setup"
    if not re.search(r"findstr\b.*Telemetry blocks - win11-setup", content, re.IGNORECASE):
        errors.append(f'  Marqueur anti-doublon hosts absent (findstr /C:"{marker}")')
    if not re.search(r"echo.*Telemetry blocks - win11-setup", content, re.IGNORECASE):
        errors.append(f"  En-tête hosts absent (echo # {marker})")
    return errors


def test_section_log_lines(content):
    errors = []
    for i in range(1, 20):
        if not re.search(rf"echo\b.*\bSection\s+{i}\b", content, re.IGNORECASE):
            errors.append(f"  Section {i} : ligne de log echo manquante")
    return errors


def test_no_schtasks_delete(active_lines):
    errors = []
    for lineno, line in active_lines:
        if re.search(r"\bschtasks\b.*?/Delete\b", line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: schtasks /Delete interdit — utiliser /Change /Disable")
            errors.append(f"    > {line.strip()}")
    return errors


def test_no_sc_delete(active_lines):
    errors = []
    for lineno, line in active_lines:
        if re.search(r"\bsc\s+delete\b", line, re.IGNORECASE):
            errors.append(f"  Ligne {lineno}: sc delete interdit (suppression permanente du service)")
            errors.append(f"    > {line.strip()}")
    return errors


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


def test_config_variables(content):
    errors = []
    required = ["LOG", "NEED_RDP", "NEED_WEBCAM", "NEED_BT", "NEED_PRINTER", "BLOCK_ADOBE"]
    for var in required:
        if not re.search(rf"^set\s+{re.escape(var)}=", content, re.MULTILINE | re.IGNORECASE):
            errors.append(f"  Variable '{var}' non définie en tête de script")
    return errors


def test_admin_check_present(active_lines):
    errors = []
    found = any(re.search(r"\bopenfiles\b", line, re.IGNORECASE) for _, line in active_lines)
    if not found:
        errors.append("  Vérification admin manquante (openfiles absent)")
    return errors


def test_clean_exit(content):
    errors = []
    if not re.search(r"\bexit\s+/b\s+0\b", content, re.IGNORECASE):
        errors.append("  exit /b 0 absent — le script ne se termine pas proprement")
    return errors


def test_batch_header(content):
    errors = []
    lines = content.splitlines()
    first_active = next((l.strip() for l in lines if l.strip()), "")
    if not first_active.lower().startswith("@echo off"):
        errors.append(f"  Première ligne non '@echo off' : {first_active[:60]}")
    if not re.search(r"\bsetlocal\s+enabledelayedexpansion\b", content, re.IGNORECASE):
        errors.append("  'setlocal enabledelayedexpansion' absent (requis pour !variables!)")
    return errors


def test_mandatory_apps_in_applist(content, mandatory_apps):
    errors = []
    m = re.search(r'set\s+"APPLIST=([^"]+)"', content, re.IGNORECASE)
    if not m:
        errors.append("  Variable APPLIST introuvable")
        return errors
    applist = m.group(1).lower()
    for app in mandatory_apps:
        if app.startswith("*"):
            continue
        search = app.rstrip("*").lower()
        if search and search not in applist:
            errors.append(f"  App mandatory absente de APPLIST : '{app}'")
    return errors


def test_mandatory_services_disabled(content, mandatory_services):
    errors = []
    loop_services: set = set()
    for m in re.finditer(r"for\s+%%S\s+in\s+\(([^)]+)\)", content, re.IGNORECASE):
        for s in m.group(1).split():
            loop_services.add(s.strip().lower())

    for svc in mandatory_services:
        in_reg = bool(re.search(
            rf"\\Services\\{re.escape(svc)}(\\|\"|\s).*?/d\s+4",
            content, re.IGNORECASE
        ))
        in_loop = svc.lower() in loop_services
        if not in_reg and not in_loop:
            errors.append(f"  Service mandatory absent du script : '{svc}' (ni Start=4 ni sc stop loop)")
    return errors


def test_mandatory_tasks_disabled(content, mandatory_tasks):
    errors = []
    content_lower = content.lower()
    for task in mandatory_tasks:
        if task.lower() not in content_lower:
            errors.append(f"  Tâche mandatory absente du script : '{task}'")
    return errors


def test_mandatory_telemetry_hosts(content, mandatory_domains):
    errors = []
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
    for domain in mandatory_domains:
        if domain.lower() not in hosts_lower:
            errors.append(f"  Domaine télémétrie absent des hosts : '{domain}'")
    return errors


def test_mandatory_optimizations(content):
    errors = []
    for description, pattern in MANDATORY_OPTIMIZATIONS:
        if not re.search(pattern, content, re.IGNORECASE):
            errors.append(f"  Optimisation manquante : {description}")
    return errors


def test_panther_deletion(active_lines):
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


def test_no_schtasks_in_for_loop(content):
    errors = []
    if re.search(
        r"for\s+%%(\w)\s+in\s+\([^)]+\).*schtasks\s+/Change\s+/TN\s+%%\1",
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
        print(f"[{FAIL_MARK}] Fichier introuvable : {SCRIPT_PATH}")
        sys.exit(1)

    prereq = load_prerequis()

    content = SCRIPT_PATH.read_text(encoding="utf-8", errors="replace")
    active_lines = get_active_lines(content)
    total_lines = len(content.splitlines())

    print(f"Validation statique : {SCRIPT_PATH} ({total_lines} lignes)")
    print(f"Référence           : {PREREQ_PATH}")
    print(f"  {len(prereq['protected_services'])} services protégés, "
          f"{len(prereq['mandatory_services'])} à désactiver, "
          f"{len(prereq['mandatory_apps'])} apps à supprimer, "
          f"{len(prereq['mandatory_tasks'])} tâches, "
          f"{len(prereq['mandatory_domains'])} domaines télémétrie")
    print(f"  {len(prereq['forbidden_reg_values'])} valeurs registre interdites, "
          f"{len(prereq['forbidden_reg_paths'])} chemins interdits, "
          f"{len(prereq['wu_host_domains'])} domaines WU protégés")
    print("=" * 65)

    tests = [
        # ── Registre ──────────────────────────────────────────────
        ("01 Valeurs de registre interdites",
            test_forbidden_reg_values(active_lines, prereq["forbidden_reg_values"])),
        ("02 HKCU TaskbarAl interdit (HKLM TaskbarAlignment seul autorise)",
            test_hkcu_taskbaral(active_lines)),
        ("03 Chemins de registre jamais ecrits",
            test_forbidden_reg_paths(active_lines, prereq["forbidden_reg_paths"])),
        ("14 Section 10 strictement vide (Windows Update intouche)",
            test_section10_empty(content)),
        # ── Services ──────────────────────────────────────────────
        ("05 Services proteges jamais desactives",
            test_protected_services_not_disabled(content, active_lines, prereq["protected_services"])),
        ("08 Pas de doublons dans les boucles for %%S",
            test_no_duplicate_services_in_loops(content)),
        ("09 Pas de doublons dans les reg add Start=4",
            test_no_duplicate_service_start4(active_lines)),
        ("20 sc delete absent",
            test_no_sc_delete(active_lines)),
        # ── Apps ──────────────────────────────────────────────────
        ("06 Apps protegees absentes de la liste de suppression",
            test_protected_apps_not_removed(content, active_lines, prereq["protected_apps"])),
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
        ("07 Domaines Windows Update jamais bloques dans hosts",
            test_wu_domains_not_blocked(content, prereq["wu_host_domains"])),
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
        # ── Prérequis (lus depuis prerequis_WIN11.md) ──────────────
        ("26 Apps mandatory presentes dans APPLIST",
            test_mandatory_apps_in_applist(content, prereq["mandatory_apps"])),
        ("27 Services mandatory desactives (Start=4 ou sc stop)",
            test_mandatory_services_disabled(content, prereq["mandatory_services"])),
        ("28 Taches planifiees mandatory desactivees",
            test_mandatory_tasks_disabled(content, prereq["mandatory_tasks"])),
        ("29 Domaines telemetrie bloques dans hosts",
            test_mandatory_telemetry_hosts(content, prereq["mandatory_domains"])),
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
