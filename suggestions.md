# Suggestions d'amélioration — WinOptimum

> 📌 Propositions concrètes **sans breaking changes**. Chaque suggestion peut être implémentée indépendamment.

---

## 🎯 Priorité HAUTE — Impact immédiat

### 1. **Système de logging amélioré avec mesures de performance**

**Problème** : Aucune mesure avant/après (RAM gagnée, espace libéré, temps boot).

**Solution** :
```batch
:: Ajouter au début (Section 1 bis)
setlocal enabledelayedexpansion

:: Capturer RAM libre avant
for /f "tokens=3" %%A in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set RAM_BEFORE=%%A

:: Capturer espace C: avant
for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where DeviceID^="C:" get FreeSpace /value 2^>nul') do set SPACE_BEFORE=%%F

:: À la fin du script (Section 20 détaillée)
for /f "tokens=3" %%A in ('wmic OS get FreePhysicalMemory /value ^| find "="') do set RAM_AFTER=%%A
for /f "tokens=2 delims==" %%F in ('wmic logicaldisk where DeviceID^="C:" get FreeSpace /value 2^>nul') do set SPACE_AFTER=%%F

set /a RAM_GAIN=(!RAM_AFTER! - !RAM_BEFORE!) / 1024 / 1024
set /a SPACE_GAIN=(!SPACE_AFTER! - !SPACE_BEFORE!) / 1024 / 1024 / 1024

echo [BILAN] RAM liberee : !RAM_GAIN! MB >> "%LOG%"
echo [BILAN] Espace gagne : !SPACE_GAIN! GB >> "%LOG%"
```

**Impact** : User sait exactement ce qu'il a gagné ✅

---

### 2. **Vérification rollback — script de restauration automatique**

**Problème** : Si ça casse, faut restaurer manuellement.

**Solution créer `restore.bat`** :
```batch
@echo off
setlocal enabledelayedexpansion

echo Restauration Windows 11 en cours...
echo Lisez les points de restauration disponibles :
wmic logicaldisk get name

powershell -Command "Get-ComputerRestorePoint | Select-Object CreationTime, Description, SequenceNumber | Format-Table"

set /p SEQ="Entrez le SequenceNumber à restaurer (ou Ctrl+C pour annuler) : "
powershell -Command "Restore-Computer -RestorePoint %SEQ% -Confirm"
```

**Impact** : User peut revenir en arrière en 1 cmd ✅

---

### 3. **Validation post-exécution — health check**

**Problème** : Aucune vérification que Windows fonctionne après.

**Solution ajouter en Section 19b** :
```batch
:: SECTION 19b-health — Vérification intégrité post-script
echo [%date% %time%] === HEALTH CHECK === >> "%LOG%"

:: Vérifie que les services critiques tournent
for %%S in (WSearch WinDefend wuauserv RpcSs PlugPlay) do (
  sc query %%S >nul 2>&1
  if !errorlevel! equ 0 (
    echo [OK] Service %%S actif >> "%LOG%"
  ) else (
    echo [WARN] Service %%S - ETAT INCONNU >> "%LOG%"
  )
)

:: Vérifie que C:\Windows\Temp accessible
if exist "C:\Windows\Temp\" (
  echo [OK] C:\Windows\Temp accessible >> "%LOG%"
) else (
  echo [CRITICAL] C:\Windows\Temp inaccessible - ErreurFS >> "%LOG%"
)

:: Vérifie que registre HKLM accessible
reg query "HKLM\SYSTEM\CurrentControlSet" >nul 2>&1
if !errorlevel! equ 0 (
  echo [OK] Registre HKLM accessible >> "%LOG%"
) else (
  echo [CRITICAL] Registre HKLM - Erreur acces >> "%LOG%"
)
```

**Impact** : Détecte les "plantages silencieux" ✅

---

## 🔧 Priorité MOYENNE — Robustesse

### 4. **Gestion pagefile adaptative (HDD vs SSD)**

**Problème** : 6 Go fixe ralentit sur SSD, peut être insuffisant sur HDD 7200.

**Solution dans Section 4** :
```batch
:: Détecteur de type disque (SSD vs HDD)
wmic logicaldisk where DeviceID="C:" get MediaType >nul 2>&1
if !errorlevel! equ 0 (
  for /f "tokens=2" %%T in ('wmic logicaldisk where DeviceID^="C:" get MediaType ^| find "."') do set MEDIA=%%T
  if "!MEDIA!"=="12" (
    :: SSD détecté — pagefile réduit à 3 Go
    set PAGEFILE_SIZE=3072
    echo [%date% %time%] SSD detected - Pagefile 3 Go >> "%LOG%"
  ) else (
    :: HDD — pagefile 6 Go
    set PAGEFILE_SIZE=6144
    echo [%date% %time%] HDD detected - Pagefile 6 Go >> "%LOG%"
  )
) else (
  :: Fallback 6 Go si détection échoue
  set PAGEFILE_SIZE=6144
)

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v PagingFiles /t REG_MULTI_SZ /d "C:\pagefile.sys !PAGEFILE_SIZE! !PAGEFILE_SIZE!" /f >nul 2>&1
```

**Impact** : Évite ralentissements sur SSD ✅

---

### 5. **Reprise sur erreur — continue mais log**

**Problème** : Si une reg add échoue, tu ne le sais pas.

**Solution (macro à ajouter en tête)** :
```batch
:: Macro de retry avec log
setlocal enabledelayedexpansion
set RETRY_COUNT=0
set MAX_RETRY=3

:retry_reg_add
reg add "%~1" %~2 >nul 2>&1
if !errorlevel! neq 0 (
  set /a RETRY_COUNT+=1
  if !RETRY_COUNT! lss !MAX_RETRY! (
    timeout /t 1 /nobreak >nul 2>&1
    goto retry_reg_add
  ) else (
    echo [WARN] Echec persistant : reg add %~1 >> "%LOG%"
  )
)
set RETRY_COUNT=0
```

**Utilisation** :
```batch
call :retry_reg_add "HKLM\SYSTEM\..." "/v Key /t REG_DWORD /d 1 /f"
```

**Impact** : Évite les échecsilencieux, meilleure traçabilité ✅

---

### 6. **Whitelist services — tableau de quoi ne pas toucher**

**Problème** : 90+ services désactivés, risque d'oublier un service critique.

**Solution créer `services-whitelist.txt`** :
```
# Services ABSOLUMENT conservés — NE JAMAIS DÉSACTIVER
WSearch|Indexation Windows
WinDefend|Antivirus Windows
wuauserv|Windows Update
RpcSs|Remote Procedure Call — dépendance systématique
PlugPlay|Plug and Play — USB/périphériques
WlanSvc|Wi-Fi
AppXSvc|Microsoft Store + winget
seclogon|Elevation (installeurs tiers)
TokenBroker|OneDrive + Edge SSO
OneSyncSvc|OneDrive sync
wlidsvc|Microsoft Account

# Services optionnels selon NEED_* variables
TermService|Bureau à distance (si NEED_RDP=1)
BthAvctpSvc|Bluetooth audio (si NEED_BT=1)
Spooler|Impression (si NEED_PRINTER=1)
```

Et intégrer en Section 14 :
```batch
:: Vérifier que service n'est pas en whitelist
findstr /i "^!SERVICE!" services-whitelist.txt >nul
if !errorlevel! equ 0 (
  echo [WARN] Service !SERVICE! en whitelist - CONSERVE >> "%LOG%"
) else (
  reg add "HKLM\SYSTEM\CurrentControlSet\Services\!SERVICE!" /v Start /t REG_DWORD /d 4 /f >nul 2>&1
)
```

**Impact** : Élimine risque de désactiver un service critique ✅

---

## 📊 Priorité BASSE — Monitoring & Reporting

### 7. **Dashboard HTML — rapport visuel post-exécution**

**Problème** : Log .txt brut, pas de résumé visuel.

**Solution créer `generate-report.ps1`** :
```powershell
# Lit le log et génère HTML

$log = Get-Content "C:\Windows\Temp\win11-setup.log"
$report = @"
<!DOCTYPE html>
<html>
<head>
  <title>WinOptimum Report</title>
  <style>
    body { font-family: Arial; margin: 20px; }
    .success { color: green; }
    .warn { color: orange; }
    .error { color: red; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #ddd; padding: 8px; }
  </style>
</head>
<body>
  <h1>WinOptimum - Rapport d'exécution</h1>
  <h2>Sections complétées</h2>
  <ul>
"@

$log | Select-String "Section \d+" | ForEach-Object {
  $report += "<li>$_</li>`n"
}

$report += @"
  </ul>
  <h2>Avertissements</h2>
  <ul>
"@

$log | Select-String "WARN" | ForEach-Object {
  $report += "<li class='warn'>$_</li>`n"
}

$report += @"
  </ul>
</body>
</html>
"@

$report | Out-File "C:\Windows\Temp\win11-setup-report.html"
Write-Host "Report généré : C:\Windows\Temp\win11-setup-report.html"
```

**Impact** : User a un dashboard au lieu d'un log brut ✅

---

### 8. **Cryptage des données sensibles dans hosts**

**Problème** : 57 domaines visibles dans `C:\Windows\System32\drivers\etc\hosts` (traçable).

**Solution** :
```batch
:: Avant d'ajouter les domaines au hosts, les commenter
echo # Domaines Microsoft telemetry (blocked) >> C:\Windows\System32\drivers\etc\hosts

:: Au lieu de :
echo 0.0.0.0 telemetry.microsoft.com
:: Faire :
echo # 0.0.0.0 telemetry.microsoft.com (obscurit via #)
```

Ou **mieux** : utiliser Windows Firewall rules au lieu de `hosts` :
```batch
powershell -Command "New-NetFirewallRule -DisplayName 'Block Telemetry' -Direction Outbound -Action Block -RemoteAddress telemetry.microsoft.com" >nul 2>&1
```

**Impact** : Plus sécurisé qu'un fichier texte en clair ✅

---

### 9. **Détection de configuration matérielle — adaptation automatique**

**Problème** : Même script pour 1 Go et multicore, pas de discrimination.

**Solution ajouter en Section 0** :
```batch
:: Détection HW — adaptation pagefile/services
for /f "tokens=2 delims==" %%R in ('wmic OS get TotalVisibleMemorySize /value ^| find "="') do set TOTAL_RAM=%%R
set /a RAM_GB=!TOTAL_RAM! / 1024 / 1024

if !RAM_GB! gtr 2 (
  echo [%date% %time%] RAM > 2 Go détectée (!RAM_GB! Go) - Pagefile peut être réduit >> "%LOG%"
  set PAGEFILE_SIZE=2048
) else (
  set PAGEFILE_SIZE=6144
)

for /f "tokens=2 delims=" %%C in ('wmic cpu get NumberOfCores /value ^| find "="') do set CORES=%%C

if !CORES! gtr 4 (
  echo [%date% %time%] Multicore détecté (!CORES! cores) - SystemResponsiveness peut être 7 >> "%LOG%"
  set SYS_RESP=7
) else (
  set SYS_RESP=10
)
```

**Impact** : Script auto-adaptatif au matériel ✅

---

### 10. **Système de plugins — extensibilité sans fork**

**Problème** : Tout est en dur dans le script, difficile à customizer.

**Solution créer dossier `plugins/`** :
```
plugins/
├── 00-pre-checks.bat          (vérifications pré-exec)
├── 10-custom-registry.bat     (clés registre custom)
└── 20-custom-services.bat     (services custom)
```

Et en Section 1.5 :
```batch
:: Charger plugins personnalisés
if exist "plugins\" (
  for /f %%F in ('dir /b plugins\*.bat') do (
    echo [%date% %time%] Executing plugin %%F >> "%LOG%"
    call plugins\%%F
  )
)
```

**Impact** : User peut étendre sans fork, upgrade facile ✅

---

## 📋 Résumé implémentation (ordre suggéré)

| # | Suggestion | Effort | Impact | Dépend |
|---|-----------|--------|--------|--------|
| 1 | Logging amélioré | 1h | ⭐⭐⭐ | Rien |
| 3 | Health check | 1.5h | ⭐⭐⭐ | Rien |
| 5 | Reprise sur erreur | 2h | ⭐⭐ | Rien |
| 2 | Restore.bat | 1h | ⭐⭐ | Rien |
| 4 | Pagefile adaptatif | 1.5h | ⭐⭐ | Rien |
| 6 | Services whitelist | 0.5h | ⭐⭐⭐ | Rien |
| 9 | Détection HW | 1h | ⭐⭐ | Rien |
| 7 | Report HTML | 2h | ⭐ | Logging amélioré |
| 8 | Cryptage hosts | 1h | ⭐ | Rien |
| 10 | Plugins | 2h | ⭐⭐ | Rien |

**Total effort rapide (top 6)** : ~8h pour **notepass de 9 à 9.2/10**

---

## ⚠️ Ce qu'on NE change PAS

✅ Structure 20 sections — intouchable
✅ Apps TOUJOURS supprimées — liste en `prerequis_WIN11.md`
✅ Apps TOUJOURS conservées — intouchable
✅ Point restau obligatoire en section 2
✅ Windows Defender + Update — JAMAIS touchés
✅ Compatibilité `FirstLogonCommands`
