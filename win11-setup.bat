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