# Optimisation Windows

> Script de post-installation Windows 11 25H2 — optimisé pour systèmes à faibles ressources

---

## Description

**WinOptimum** est un toolkit de debloat et d'optimisation de Windows 11 25H2 conçu pour les machines à ressources limitées. Il supprime les applications inutiles, désactive la télémétrie, optimise la mémoire et applique plus de 70 réglages registre — tout en conservant la sécurité et les fonctionnalités essentielles de Windows.

Le script est pensé pour un **déploiement non assisté** : il s'intègre dans un fichier `autounattend.xml` via la section `FirstLogonCommands`, et s'exécute automatiquement au premier démarrage après installation. Il peut également être lancé manuellement en tant qu'administrateur sur un Windows déjà installé.

Toutes les actions sont journalisées dans `C:\Windows\Temp\win11-setup.log`.

---

## Prérequis système

| Composant | Requis |
|---|---|
| Système d'exploitation | Windows 11 25H2 |
| Firmware | UEFI |
| Sécurité | TPM 2.0 |
| RAM | 1 Go minimum |
| Espace disque libre | 10 Go minimum (pour le pagefile fixe) |
| Droits | Administrateur local |

---

## Fonctionnalités

Le script est organisé en **20 sections** qui s'exécutent séquentiellement :

| Section | Action |
|---|---|
| 1 | Vérification des droits administrateur — arrêt immédiat si non admin |
| 2 | Création d'un point de restauration système (obligatoire avant toute modification) |
| 3 | Suppression des fichiers Panther (`C:\Windows\Panther`) — sécurité : ces fichiers contiennent le mot de passe administrateur en clair |
| 4 | Pagefile fixe à 6 Go sur C: (uniquement si ≥ 10 Go d'espace libre détecté via WMIC) |
| 5 | Optimisation mémoire : compression activée, Prefetch désactivé, SysMain arrêté, opt-out télémétrie PowerShell |
| 6 | Zéro télémétrie : 16+ clés registre pour désactiver Copilot, Recall, DiagTrack, IA générative et la collecte de données Microsoft |
| 7 | AutoLoggers désactivés : DiagTrack, DiagLog, SQMLogger, WiFiSession |
| 8 | Windows Search : désactivation de la recherche web et Bing dans la barre de recherche (le service WSearch reste actif) |
| 9 | Optimisations Edge (désactivation du démarrage anticipé et du mode arrière-plan), GameDVR désactivé, Delivery Optimization désactivé |
| 10 | Politiques Windows Update : redémarrage rapide après mises à jour, réseau mesuré autorisé, notifications conservées |
| 11 | Vie privée & sécurité : Cortana désactivé, ID publicitaire supprimé, historique d'activité désactivé, géolocalisation désactivée, RemoteAssistance désactivé, personnalisation de la saisie désactivée, AutoPlay désactivé, contenu cloud désactivé, cartes hors ligne bloquées, mise à jour du modèle vocal bloquée |
| 12 | Interface style Windows 10 : barre des tâches alignée à gauche, widgets supprimés, boutons Teams/Copilot masqués, menu contextuel classique, "Ce PC" par défaut dans l'explorateur, Galerie et Réseau masqués, son de démarrage désactivé, hibernation désactivée, démarrage rapide désactivé |
| 13 | Priorité CPU : `SystemResponsiveness = 10` (les applications au premier plan obtiennent la priorité) |
| 14 | 39+ services désactivés via registre (`Start=4`) |
| 15 | Arrêt immédiat de tous les services désactivés à la section 14 |
| 16 | Fichier `hosts` : 12 domaines de télémétrie Microsoft bloqués en `0.0.0.0` |
| 17 | 19 tâches planifiées de diagnostic et de collecte de données désactivées |
| 18 | Suppression de 50+ applications bloatware (UWP) via PowerShell |
| 19 | Nettoyage du dossier `C:\Windows\Prefetch` |
| 20 | Fin du script avec log de succès |

---

## Ce qui est toujours conservé

Le script ne touche jamais aux éléments suivants, considérés comme essentiels :

**Applications préservées :**
- Microsoft Edge
- Photos
- OneDrive
- Notepad (Bloc-notes)
- Terminal Windows
- DesktopAppInstaller (winget)
- VCLibs
- UI.Xaml
- NET.Native

**Services toujours actifs :**
- `WSearch` — Windows Search (indexation)
- `WinDefend` — Windows Defender
- `wuauserv` — Windows Update
- `RpcSs` — Remote Procedure Call
- `PlugPlay` — Plug and Play
- `WlanSvc` — Wi-Fi

---

## Configuration

Quatre variables sont disponibles en tête du script pour adapter le comportement selon l'usage :

| Variable | Valeur par défaut | Description |
|---|---|---|
| `LOG` | `C:\Windows\Temp\win11-setup.log` | Chemin du fichier de journal |
| `BLOCK_ADOBE` | `0` | `1` = bloquer les domaines Adobe dans le fichier hosts (désactivé par défaut) |
| `NEED_RDP` | `0` | `1` = conserver l'application RemoteDesktop (sinon supprimée) |
| `NEED_WEBCAM` | `0` | `1` = conserver WindowsCamera (sinon supprimée) |
| `NEED_BT` | `0` | `1` = conserver le service Bluetooth audio `BthAvctpSvc` (sinon désactivé) |

Pour modifier une option, ouvrir `win11-setup.bat` et changer la valeur correspondante dans la section de configuration en tête de fichier.

---

## Utilisation

### Mode 1 — Déploiement automatisé (recommandé)

Intégrer le script dans un fichier `autounattend.xml` via la section `oobeSystem` / `FirstLogonCommands` :

```xml
<FirstLogonCommands>
  <SynchronousCommand wcm:action="add">
    <Order>1</Order>
    <CommandLine>cmd /c "D:\win11-setup.bat"</CommandLine>
    <Description>Optimisation Windows 11</Description>
    <RequiresUserInput>false</RequiresUserInput>
  </SynchronousCommand>
</FirstLogonCommands>
```

Copier `win11-setup.bat` sur la clé USB d'installation et référencer son chemin dans la commande ci-dessus.

### Mode 2 — Exécution manuelle

Sur un Windows 11 déjà installé :

1. Faire un clic droit sur `win11-setup.bat`
2. Sélectionner **"Exécuter en tant qu'administrateur"**
3. Le script s'exécute silencieusement (aucune invite, aucun redémarrage automatique)
4. Consulter le log à la fin : `C:\Windows\Temp\win11-setup.log`

---

## Statistiques

| Catégorie | Quantité |
|---|---|
| Clés registre modifiées | 70+ |
| Services désactivés | 39 |
| Tâches planifiées désactivées | 19 |
| Applications (UWP) supprimées | 50+ |
| Domaines de télémétrie bloqués | 12 |
| Options de configuration | 4 |

---

## Fichiers du projet

| Fichier | Description |
|---|---|
| `win11-setup.bat` | Script principal d'optimisation post-installation (525 lignes) |
| `prerequis_WIN11.md` | Document de spécification : règles de conception, listes d'apps/services/tâches, contraintes techniques (554 lignes) |

---

## Avertissements

- **Point de restauration** : le script en crée un automatiquement en section 2. Ne jamais l'ignorer ou le désactiver.
- **Test en VM** : tester sur une machine virtuelle avant tout déploiement en production.
- **Options conditionnelles** : si vous avez besoin de Bureau à distance, d'une webcam ou du Bluetooth audio, ajuster les variables `NEED_RDP`, `NEED_WEBCAM`, `NEED_BT` avant l'exécution.
- **Contexte FirstLogonCommands** : certaines limitations WMI et PowerShell s'appliquent dans ce contexte d'exécution — le script est conçu pour les contourner proprement.
- **Windows Defender conservé** : aucune modification de la sécurité antivirus n'est effectuée (SubmitSamplesConsent intentionnellement non modifié).
