#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf '%s\n' 'Usage : bash scripts/configure-repo.sh VOTRE_IDENTIFIANT_GITHUB' >&2
  exit 2
fi

gitops_user="$1"
case "$gitops_user" in
  ''|*[!A-Za-z0-9-]*|GITHUB_USER|ton-identifiant)
    printf '%s\n' 'Indiquez votre identifiant GitHub réel (lettres, chiffres et tirets).' >&2
    exit 2
    ;;
esac

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
project_dir="$(CDPATH= cd -- "$script_dir/.." && pwd)"

for manifest in "$project_dir"/argocd/*.yaml; do
  [ -f "$manifest" ] || continue
  if grep -q 'GITHUB_USER' "$manifest"; then
    case "$(uname -s)" in
      Darwin) sed -i '' "s/GITHUB_USER/$gitops_user/g" "$manifest" ;;
      *) sed -i "s/GITHUB_USER/$gitops_user/g" "$manifest" ;;
    esac
    printf 'Mis à jour : %s\n' "${manifest##*/}"
  fi
done

printf 'Dépôt configuré : https://github.com/%s/k8s-day-gitops.git\n' "$gitops_user"
printf '%s\n' 'Aucun dépôt créé, aucun fichier envoyé. Vérifiez les repoURL avant de continuer.'
