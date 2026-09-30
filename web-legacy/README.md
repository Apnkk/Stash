# web-legacy

Ancienne version de Stash en **PWA** (application web progressive), conservée ici
pour référence. Elle n'est plus utilisée : le projet est désormais une **app iOS
native SwiftUI** (dossiers `Stash/` et `Stash.xcodeproj/`).

## Contenu

- `index.html` — structure de l'interface
- `app.js` — logique (stockage local des cartes, génération code-barres / QR)
- `styles.css` — styles
- `sw.js` — service worker (mode hors-ligne)
- `manifest.webmanifest` — manifeste PWA (installation sur l'écran d'accueil)
- `icon.svg` — icône

## Tester l'ancienne PWA

Depuis ce dossier, sers les fichiers en local (le service worker exige HTTP, pas `file://`) :
