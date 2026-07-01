# ATVRemote 📺📱

Une **télécommande iPhone pour Android TV / Google TV**, écrite en SwiftUI.
L'app parle **directement** à ta TV sur le réseau local via le protocole officieux
*Android TV Remote v2* — le même que l'application « Google TV ».
Pas de cloud, pas de pub, pas d'abonnement.

> Compatible Sony, TCL, Philips, Nvidia Shield et la quasi-totalité des
> Android TV / Google TV embarquant le service « Android TV Remote Service ».

---

## ✨ Fonctionnalités

- 🔍 **Découverte automatique** des TV sur le Wi-Fi (Bonjour / mDNS), ou saisie manuelle de l'IP.
- 🔐 **Appairage sécurisé** par code à 6 caractères affiché sur la TV (TLS mutuel, certificat auto-signé). Mémorisé côté TV : pas besoin de recoder ensuite.
- 🕹️ **D-pad** complet : haut / bas / gauche / droite + **OK**.
- ⚡ Touches **Home**, **Back**, **Menu**, **Power**.
- 🔊 **Volume +/−**, **Mute**, et **Play/Pause**.
- 🧩 Extensible : ajout de touches (`tv.press(.KEYCODE_…)`) et lancement d'apps par *deep link* (`tv.openApp(…)`).

## 📋 Prérequis

- Un **Mac** avec **Xcode** (gratuit).
- iPhone et TV sur le **même réseau Wi-Fi**.
- Le service *Android TV Remote Service* actif sur la TV (préinstallé sur la plupart).
- Un **Apple ID** (même gratuit) pour signer et installer l'app sur ton iPhone.

## 🚀 Installation

Le guide pas à pas est dans **[`ATVRemote/SETUP.md`](ATVRemote/SETUP.md)** — création du projet Xcode, ajout de la librairie, **génération du certificat**, réglages réseau, signature et premier appairage.

> ⚠️ **Certificats non fournis.** `cert.der`, `cert.p12` et `key.pem` sont des **clés privées** :
> chacun génère les siennes (3 commandes `openssl`, voir SETUP.md § 3) **avant le premier build**.

## 🔧 Comment ça marche

L'app enveloppe la librairie **[AndroidTVRemoteControl](https://github.com/odyshewroman/AndroidTVRemoteControl)** (pairing, TLS, protobuf) dans un `ObservableObject` SwiftUI :

- **`TVRemote.swift`** — découverte Bonjour (`NWBrowser`), résolution d'IP, connexion, appairage et envoi des commandes.
- **`ContentView.swift`** — l'interface (statut, liste des TV, champ de code, D-pad, volume).
- La TV et l'app s'authentifient mutuellement en **TLS** : l'app présente son identité (`cert.p12`), la TV présente la sienne, et le code à 6 caractères scelle l'appairage.

## 🗂️ Structure

```
ATVRemote/
├─ ATVRemoteApp.swift    # point d'entrée SwiftUI
├─ ContentView.swift     # UI (D-pad, volume, appairage)
├─ TVRemote.swift        # logique réseau / appairage / commandes
├─ Info.plist            # permissions réseau local + Bonjour
└─ SETUP.md              # guide d'installation détaillé
```

## 🙏 Crédits

Construit sur [odyshewroman/AndroidTVRemoteControl](https://github.com/odyshewroman/AndroidTVRemoteControl), qui implémente le protocole *Android TV Remote v2*.

## 📄 Licence

Projet personnel, fourni tel quel, sans garantie. Ajoute une licence (MIT recommandé) si tu souhaites clarifier les droits de réutilisation.
