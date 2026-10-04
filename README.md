# Stash

Portefeuille local sécurisé pour cartes de fidélité, cartes bancaires et autres cartes sur iOS.

## Fonctionnalités
- **Protection totale** : Stockage 100 % local. Aucun serveur distant, aucune télémétrie.
- **Cartes bancaires** : Les numéros complets sont conservés dans le Keychain avec protection biométrique (Face ID / Touch ID) et code de secours de l'appareil. Affichage réaliste et masquage automatique.
- **Cartes de fidélité & codes-barres** : Génération instantanée et nette de codes-barres (EAN-13, EAN-8, Code 128, QR Code, PDF417, Aztec).
- **Aperçus réalistes & Card Art** : Personnalisation avec photos ou designs intégrés de cartes bancaires.
- **Sauvegarde chiffrée** : Export et import avec chiffrement fort AES-256-GCM et dérivation de clé PBKDF2.

## Prérequis de compilation
- **macOS** 15+ (Sequoia) avec **Xcode 26+** (SDK iOS 26).
- Cible : iOS 26.0+ (compatible iPhone).

## Tests
Exécuter les tests unitaires :
```bash
xcodebuild test -project Stash.xcodeproj -scheme Stash -destination 'platform=iOS Simulator,name=iPhone 16'
```
