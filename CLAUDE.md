# Instructions pour Stash

## Architecture et Conventions
- **Projet** : Application native iOS en SwiftUI (`Stash/`), ciblée iOS 26.
- **Structure Xcode** : Utilise les `PBXFileSystemSynchronizedRootGroup` (Xcode 16+). Tout nouveau fichier Swift déposé dans `Stash/` ou `StashTests/` est automatiquement inclus à la compilation sans modifier manuellement `project.pbxproj`.
- **Sécurité** :
  - Les métadonnées non sensibles (nom, type, format de code, 4 derniers chiffres) sont persistées en JSON chiffré au repos dans `Application Support` / `Documents`.
  - Les numéros complets de cartes bancaires sont stockés exclusivement dans le Keychain (`SecureVault`), protégés par authentification biométrique et code de l'appareil.
  - Les images de fond personnalisées sont stockées hors sauvegarde dans `ArtVault`.
  - Zéro fuite de données vers des serveurs externes.
- **Tests** : Tests unitaires dans `StashTests/` avec le framework moderne `Testing` (Swift Testing).

## Workflow Git
- Utiliser **Conventional Commits** : `feat:`, `fix:`, `test:`, `refactor:`, `chore:`.
- Commits atomiques et messages descriptifs en français.
- Vérifier `git status` et `git diff` avant tout commit.
- Les tests unitaires et la CI GitHub Actions doivent valider les changements.
