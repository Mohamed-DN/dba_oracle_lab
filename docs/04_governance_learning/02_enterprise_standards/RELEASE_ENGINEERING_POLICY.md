# Release Engineering Policy

## Versioning Semantico
- Sorgente di verità: file `VERSION`.
- Formato obbligatorio: `MAJOR.MINOR.PATCH` (+ pre-release/build opzionali).

## Changelog rigoroso
- File obbligatorio: `CHANGELOG.md`.
- Sezione `Unreleased` sempre presente.
- Ogni PR che cambia comportamento utente deve aggiornare il changelog.

## Processo release
1. Congelamento modifiche e passaggio quality/security gates.
2. Aggiornamento `VERSION` e sezione release in `CHANGELOG.md`.
3. Pubblicazione release con note di compatibilità e rollback.
4. Archiviazione evidenze CI/DR della release.

## Compatibility notes
- Ogni release deve includere note esplicite su Oracle/OS/Ansible/VirtualBox supportati.
