# ATVRemote — Télécommande Android TV pour iPhone

Une télécommande iPhone qui parle **directement** à ta TV Android (Sony, TCL, Philips, Nvidia Shield…)
via le protocole officieux *Android TV Remote v2* — le même que l'appli « Google TV ».
Pas de pub, pas d'abonnement. La lib fait le gros du travail (pairing, TLS, protobuf) ;
toi tu fournis juste un certificat auto-signé.

> ⚠️ **Tu viens de cloner le repo ?** Les certificats (`cert.der`, `cert.p12`, `key.pem`)
> ne sont **volontairement pas fournis** : ce sont des clés privées, chacun génère les
> siennes. Fais l'**étape 3** ci-dessous *avant* le premier build, sinon l'app ne compilera
> pas (les fichiers sont référencés dans *Copy Bundle Resources*).

---

## Prérequis

- Un **Mac** avec **Xcode** (gratuit sur le Mac App Store).
- Ton iPhone et ta TV sur le **même réseau Wi-Fi**.
- Sur la TV : le service « Android TV Remote Service » (préinstallé sur la quasi-totalité
  des Android TV / Google TV). Vérif : *Paramètres > Apps > Voir toutes les apps*.
- L'**IP de ta TV** : *Paramètres > Réseau et Internet > (ton Wi-Fi)*, ou dans ton routeur.
  Exemple : `192.168.1.42`.

---

## 1. Créer le projet Xcode

1. Xcode → *File > New > Project… > iOS > App*.
2. Nom : `ATVRemote`. Interface : **SwiftUI**. Language : **Swift**.
3. Supprime le `ContentView.swift` généré, puis glisse dans le projet les 3 fichiers fournis :
   `ATVRemoteApp.swift`, `ContentView.swift`, `TVRemote.swift`
   (coche bien *Copy items if needed* et la *target* ATVRemote).
   > Si tu gardes le `App.swift` généré, supprime celui-ci pour éviter deux `@main`.

## 2. Ajouter la librairie

*File > Add Package Dependencies…* → colle l'URL :

```
https://github.com/odyshewroman/AndroidTVRemoteControl
```

Choisis la dernière version et ajoute le package à la target `ATVRemote`.

## 3. Générer ton certificat (3 commandes)

Dans le Terminal, sur ton Mac :

```bash
# 1) Clé privée + certificat auto-signé (valable 10 ans)
openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout key.pem -out cert.pem -days 3650 -subj "/CN=ATVRemote"

# 2) Version DER du certificat public  ->  cert.der
openssl x509 -in cert.pem -outform der -out cert.der

# 3) Identité PKCS#12 avec mot de passe VIDE  ->  cert.p12
openssl pkcs12 -export -inkey key.pem -in cert.pem -out cert.p12 -passout pass:
```

> ⚠️ Si l'app plante au lancement avec une erreur d'import du `.p12`
> (`secPKCS12Import Not Success`), c'est qu'OpenSSL 3 chiffre trop fort pour iOS.
> Refais l'étape 3 avec l'option `-legacy` :
> `openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out cert.p12 -passout pass:`

Le mot de passe vide est volontaire : il correspond au `CertManager().cert(url, "")` dans `TVRemote.swift`.

## 4. Embarquer le certificat dans l'app

Glisse **`cert.der`** et **`cert.p12`** dans le projet Xcode (coche *Copy items if needed*
et la target `ATVRemote`). Vérifie qu'ils apparaissent dans
*Target > Build Phases > Copy Bundle Resources*.

## 5. Autoriser le réseau local (obligatoire iOS 14+)

Dans *Target > Info* (ou `Info.plist`), ajoute **deux** clés :

- **Privacy - Local Network Usage Description**
  (`NSLocalNetworkUsageDescription`) → valeur : `Pour contrôler la TV sur le réseau local`.
- **Bonjour services** (`NSBonjourServices`) → un tableau (Array) avec **un** élément :
  `_androidtvremote2._tcp`

> ⚠️ Sans la clé `NSBonjourServices`, le **scan automatique ne renvoie rien** sur un vrai
> iPhone (ça marche au simulateur, ce qui trompe tout le monde). C'est *le* piège classique.

Au premier lancement, iOS demandera l'autorisation « réseau local » : accepte, sinon
ni le scan ni la connexion ne fonctionneront.

En XML brut dans l'Info.plist, ça donne :

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Pour contrôler la TV sur le réseau local</string>
<key>NSBonjourServices</key>
<array>
    <string>_androidtvremote2._tcp</string>
</array>
```

## 6. Compiler sur ton iPhone (Apple ID gratuit)

1. Branche l'iPhone. Sélectionne-le comme destination en haut de Xcode.
2. *Target > Signing & Capabilities* : coche *Automatically manage signing*,
   et dans *Team* ajoute ton **Apple ID** (« Add an Account… »), même gratuit.
   Mets un *Bundle Identifier* unique, p.ex. `com.tonnom.atvremote`.
3. Sur l'iPhone (iOS 16+) : *Réglages > Confidentialité et sécurité > Mode développeur* → **activé**.
4. Appuie sur ▶︎ (Run). À la première install, *Réglages > Général > VPN et gestion de
   l'appareil* → fais confiance à ton profil de développeur.

## 7. Première utilisation

1. Ouvre l'app, tape l'**IP de la TV**, appuie sur **Connect**.
2. Un **code de 6 caractères** (chiffres 0-9 et lettres A-F) s'affiche sur la TV.
3. Saisis-le dans l'app → **Pair**. C'est appairé pour de bon.
4. Le D-pad, le volume, Home/Back/Power deviennent actifs. 🎉

À partir de là, l'appairage est mémorisé côté TV : tu te reconnectes direct, sans recode.

---

## Le truc des 7 jours (compte gratuit)

Avec un Apple ID gratuit, l'app **cesse de fonctionner après 7 jours**. Pour la relancer :
soit tu rebranches l'iPhone et tu recliques sur ▶︎ dans Xcode, soit tu installes
**AltStore** (altstore.io) qui re-signe automatiquement tes apps tant qu'un ordi est
allumé sur le même Wi-Fi de temps en temps. Le compte développeur Apple à 99 $/an
supprime cette contrainte (validité 1 an) — pas obligatoire.

## Personnaliser

- Ajouter une touche : appelle `tv.press(.KEYCODE_XXX)` (toutes les touches Android
  sont dans l'enum `Key` de la lib : `KEYCODE_CHANNEL_UP`, `KEYCODE_SETTINGS`,
  `KEYCODE_ASSIST`, `KEYCODE_MEDIA_NEXT`, etc.).
- Lancer une app TV : `tv.openApp("https://www.youtube.com")` ou tout *deep link*
  reconnu par l'app cible.

## Si ça ne se connecte pas

- TV et iPhone bien sur le **même** sous-réseau Wi-Fi (pas un Wi-Fi invité isolé).
- Autorisation « réseau local » accordée (sinon désinstalle / réinstalle pour reprovoquer la demande).
- IP de la TV correcte et à jour (les IP en DHCP changent : pense à une réservation dans le routeur).
- `cert.der` ET `cert.p12` bien présents dans *Copy Bundle Resources*.
- Erreur d'import `.p12` → refaire l'étape 3 avec `-legacy`.
