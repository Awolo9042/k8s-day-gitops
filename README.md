# TP Helm 4 et Argo CD sur macOS

Ce dossier complète les fichiers manquants du TP fourni. Le TP utilise Helm 4. Les commandes sont compatibles avec le terminal macOS, sous zsh ou Bash. Elles utilisent le cluster sélectionné dans votre configuration Kubernetes.

## 0. Préparer le Mac

Avec [Homebrew](https://brew.sh/) déjà installé :

```bash
brew install helm argocd
helm version --short
argocd version --client
kubectl version --client
kubectl config current-context
kubectl get nodes
```

Si `kubectl` est absent : `brew install kubernetes-cli`.

La formule Homebrew `helm` installe Helm 4. Si Helm 4 est déjà installé, conservez cette installation ; vous pouvez installer seulement la CLI manquante avec `brew install argocd`. Vérifiez que `helm version --short` affiche une version commençant par `v4`. Les charts au format `apiVersion: v2`, comme `hello-web`, restent compatibles avec Helm 4. [Homebrew Helm](https://formulae.brew.sh/formula/helm), [compatibilité Helm 4](https://helm.sh/docs/overview/), [Argo CD](https://formulae.brew.sh/formula/argocd).

Si un ancien ajout au `PATH` sélectionne encore une autre version, et que la formule Homebrew `helm` est installée, sélectionnez son binaire dans le terminal courant :

```bash
export PATH="$(brew --prefix helm)/bin:$PATH"
hash -r
helm version --short
```

Le cluster doit être joignable et ses nœuds prêts avant les installations. Si plusieurs contextes existent, choisissez celui du TP avec `kubectl config use-context NOM_DU_CONTEXTE`.

Téléchargez `k8s-day-macos.zip`. Si le fichier ZIP se trouve dans Téléchargements sous ce nom, extrayez-le dans votre dossier personnel :

```bash
unzip "$HOME/Downloads/k8s-day-macos.zip" -d "$HOME"
```

Si le navigateur a déjà décompressé l'archive, utilisez le Finder pour déplacer le dossier `k8s-day-macos` directement dans votre dossier personnel. Dans le Finder, le menu **Aller > Départ** ouvre ce dossier. Si le ZIP porte un autre nom, adaptez son chemin dans la commande précédente.

Vérifiez ensuite le dossier avant de poursuivre :

```bash
cd "$HOME/k8s-day-macos" && ls hello-web/Chart.yaml argocd
```

La commande doit afficher `hello-web/Chart.yaml` et les fichiers du dossier `argocd`. Si `cd` échoue, arrêtez-vous et retrouvez le dossier extrait avant de lancer Helm : un `cd` échoué vous laisse dans le répertoire précédent. `tree` n'est pas nécessaire ; ce guide utilise `ls`, disponible sur macOS.

Le texte collé d'origine contient des caractères d'échappement Markdown. Copiez les commandes de ce guide telles quelles : les chemins utilisent `$HOME` ou `~/`, sans antislash avant le tilde.

## A2. Explorer un chart généré

Dans un répertoire temporaire pour ne pas mélanger l'exemple et votre chart :

```bash
HELM_EXAMPLE_DIR="$(mktemp -d)"
helm create "$HELM_EXAMPLE_DIR/scratch"
ls -R "$HELM_EXAMPLE_DIR/scratch"
helm template demo "$HELM_EXAMPLE_DIR/scratch" | less
```

Examinez `values.yaml` et `templates/deployment.yaml`. Cherchez par exemple `replicaCount`, `image.repository` et `resources`. La touche `q` quitte `less`.

Après cette exploration, vous pouvez supprimer uniquement le répertoire temporaire créé :

```bash
rm -r "$HELM_EXAMPLE_DIR"
unset HELM_EXAMPLE_DIR
```

## A3. Comprendre et vérifier le chart hello-web

Les fichiers sont déjà fournis dans `hello-web/` :

| Fichier | Rôle |
| --- | --- |
| `Chart.yaml` | Métadonnées : chart `0.1.0`, application `0.4`. |
| `values.yaml` | Deux réplicas, image, port, ressources et message par défaut. |
| `values-prod.yaml` | Quatre réplicas et valeurs de production pour l'exercice. |
| `templates/_helpers.tpl` | Noms, labels standard et labels de sélection stables. |
| `templates/deployment.yaml` | Pods web, variable `GREETING`, disponibilité et ressources. |
| `templates/service.yaml` | Service `ClusterIP` qui cible le port HTTP des pods. |
| `templates/NOTES.txt` | Commandes d'accès affichées après une installation Helm. |

Une valeur vide pour `image.tag` utilise `Chart.appVersion`, donc `nginxdemos/hello:0.4`. Les images du TP sont figées ; aucun tag `latest` n'est employé.

```bash
helm lint ./hello-web
helm lint ./hello-web -f hello-web/values-prod.yaml
helm template hello-web ./hello-web
helm template hello-web ./hello-web --set replicaCount=5 | grep 'replicas:'
helm template hello-web ./hello-web --set-string image.tag=0.4-plain-text | grep 'image:'
```

`helm template` rend les modèles localement. Il permet de lire les objets produits, mais ne valide pas toutes les règles du serveur Kubernetes. Pour une validation côté serveur sans créer ces objets, utilisez un namespace existant :

```bash
helm template hello-web ./hello-web --namespace default |
  kubectl apply --server-side --dry-run=server --validate=strict -n default -f -
```

La validation serveur requiert un accès au cluster et les autorisations correspondantes. [Documentation Helm lint](https://helm.sh/docs/helm/helm_lint/), [validation Kubernetes](https://kubernetes.io/docs/reference/using-api/api-concepts/#field-validation).

## A4. Installer, mettre à jour et revenir en arrière

```bash
helm install hello-web ./hello-web -n helm-demo --create-namespace --wait --timeout 5m
helm list -n helm-demo
kubectl get all -n helm-demo
```

Dans un deuxième terminal, laissez tourner :

```bash
kubectl -n helm-demo port-forward svc/hello-web 8081:80
```

Dans le premier terminal :

```bash
open http://localhost:8081
kubectl -n helm-demo exec deploy/hello-web -- printenv GREETING
```

La variable doit contenir `Bonjour depuis Helm sur macOS !`. Elle est bien injectée dans le conteneur ; l'image de démonstration ne garantit pas son affichage dans la page web. Le contrôle de cet exercice est donc `printenv GREETING`.

Effectuez deux mises à jour :

```bash
helm upgrade hello-web ./hello-web -n helm-demo -f hello-web/values-prod.yaml --wait --timeout 5m
helm upgrade hello-web ./hello-web -n helm-demo -f hello-web/values-prod.yaml --set-string image.tag=0.4-plain-text --wait --timeout 5m
helm history hello-web -n helm-demo
```

Dans le déroulement normal, les révisions 1, 2 et 3 correspondent à l'installation, aux valeurs de production puis à l'image texte. Pour revenir à la première :

```bash
helm rollback hello-web 1 -n helm-demo --wait --timeout 5m
helm history hello-web -n helm-demo
kubectl -n helm-demo get deploy hello-web -o wide
kubectl -n helm-demo get secrets -l owner=helm
```

Vous devez retrouver deux réplicas et l'image `nginxdemos/hello:0.4`. Le retour arrière produit une nouvelle révision Helm. Il ne modifie pas vos fichiers locaux. Si le pod utilisé par `port-forward` a été remplacé, relancez la redirection.

## A5. Comprendre les erreurs

Faites une seule modification volontaire à la fois et rétablissez-la avant de poursuivre.

### Bloc de template non fermé

Dans `templates/deployment.yaml`, retirez le `{{- end }}` du bloc `resources`, puis lancez `helm lint ./hello-web`. Le rendu doit signaler une erreur de template. Remettez la ligne.

### Indentation YAML incorrecte

Remplacez le `nindent 12` situé sous `resources` par `nindent 6`. Examinez :

```bash
helm template hello-web ./hello-web
helm upgrade hello-web ./hello-web -n helm-demo --dry-run=server
```

Les champs `limits` et `requests` sont alors placés au mauvais niveau dans le PodSpec. Le YAML peut rester syntaxiquement valide. Contrairement à l'affirmation catégorique du texte d'origine, il ne faut pas supposer que `helm upgrade --dry-run=server` accepte forcément cette erreur : le résultat dépend des versions et validations activées.

Vérifiez explicitement les objets avec une validation stricte :

```bash
helm template hello-web ./hello-web --namespace helm-demo |
  kubectl apply --server-side --dry-run=server --validate=strict -n helm-demo -f -
```

Vous devez obtenir une erreur de validation pour les champs mal placés. Remettez ensuite `nindent 12`. [Options de validation Helm](https://helm.sh/docs/helm/helm_upgrade/).

### Modification d'un sélecteur

Ajoutez `tier: web` dans le helper `hello-web.selectorLabels` et tentez une mise à jour. Le sélecteur d'un Deployment existant est immuable ; examinez le message et `helm history hello-web -n helm-demo`. Remettez le helper d'origine. Une tentative qui atteint l'étape de mise à jour peut être enregistrée comme révision `failed` ; une erreur de rendu précoce ne crée pas nécessairement une révision. [Deployments Kubernetes](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#label-selector-updates).

## A6. Passer à la gestion par Argo CD

Arrêtez le terminal `port-forward` avec `Ctrl+C`, puis :

```bash
helm uninstall hello-web -n helm-demo
kubectl delete namespace helm-demo
```

Le chart reste présent sur votre Mac pour la suite.

## B1–B2. Installer Argo CD

La CLI a été installée à l'étape 0. Ajoutez le dépôt de charts et inspectez la version retenue :

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm search repo argo/argo-cd --versions
helm show chart argo/argo-cd --version 10.20.0
helm show values argo/argo-cd --version 10.20.0 | less
```

Ce kit fige le chart `10.20.0`, publié par le projet Argo. Installez-le avec les valeurs fournies :

```bash
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --version 10.20.0 -f argocd/values.yaml --wait --timeout 10m
kubectl -n argocd get pods
kubectl get crds | grep argoproj
```

Les valeurs conservent HTTPS, un Service `ClusterIP`, Redis et le contrôleur ApplicationSet. Le suivi des ressources utilise des annotations afin de conserver les labels du chart lorsque le nom de release Helm et le nom d'Application diffèrent. [Version du chart](https://github.com/argoproj/argo-helm/releases/tag/argo-cd-10.20.0), [suivi des ressources Argo CD](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_tracking/).

## B3. Ouvrir Argo CD

Dans un terminal dédié :

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Dans un autre terminal :

```bash
open https://localhost:8080
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure --grpc-web
argocd app list
```

Utilisez le compte `admin` et saisissez le mot de passe affiché par la commande précédente. L'interface utilise le certificat auto-signé de cette installation de TP ; `--insecure` concerne cette connexion locale à Argo CD. Le mot de passe n'a pas besoin d'être enregistré dans un fichier ou dans Git. [Démarrage Argo CD](https://argo-cd.readthedocs.io/en/stable/getting_started/).

## B4. Mettre le chart dans Git

Créez dans votre compte GitHub un dépôt vide nommé `k8s-day-gitops`, sans README. Pour le TP, un dépôt public simplifie la lecture par Argo CD. Si vous choisissez un dépôt privé, configurez ses identifiants dans Argo CD avant l'étape B5.

Dans le dossier de ce kit, remplacez `ton-identifiant` par votre identifiant GitHub :

```bash
GITOPS_USER='ton-identifiant'
bash scripts/configure-repo.sh "$GITOPS_USER"
git init -b main
git add hello-web argocd README.md scripts .gitignore
git commit -m "Ajout du chart hello-web et des manifests Argo CD"
git remote add origin "https://github.com/$GITOPS_USER/k8s-day-gitops.git"
git push -u origin main
```

Le script remplace le marqueur `GITHUB_USER` dans les manifestes Argo CD, sans créer de dépôt ni envoyer de contenu. Il utilise la syntaxe `sed` compatible avec macOS. Les commandes Git suivantes sont à exécuter une fois pour ce nouveau dossier. L'authentification GitHub se fait avec votre méthode habituelle, par exemple le gestionnaire d'identifiants de Git.

## B5. Créer l'Application

```bash
kubectl apply -f argocd/application.yaml
argocd app get hello-web-dev --refresh
argocd app wait hello-web-dev --sync --health --timeout 300
kubectl get applications -n argocd
kubectl get all -n hello-dev
```

L'Application utilise le dossier `hello-web` de la branche `main`. Elle crée les ressources dans `hello-dev` et utilise le nom de release Helm `hello-web`, donc le Deployment et le Service s'appellent `hello-web`.

Pour ouvrir cette nouvelle instance, dans un terminal dédié :

```bash
kubectl -n hello-dev port-forward svc/hello-web 8081:80
```

Puis `open http://localhost:8081` dans un autre terminal. Vérifiez aussi :

```bash
helm list -A
```

Argo CD utilise Helm pour rendre le chart et gère ensuite les objets. Il ne crée pas une release Helm `hello-web` visible dans `helm list`. La release `argocd`, installée avec Helm, y figure. D'autres releases préexistantes peuvent également apparaître. [Argo CD et Helm](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/).

## B6. Déployer en committant

Dans `hello-web/values.yaml`, mettez `replicaCount: 3` et changez `greeting`. Puis :

```bash
git add hello-web/values.yaml
git commit -m "Passage de hello-web à trois réplicas"
git push
argocd app get hello-web-dev --refresh
argocd app wait hello-web-dev --sync --health --timeout 300
kubectl -n hello-dev get deploy hello-web
kubectl -n hello-dev exec deploy/hello-web -- printenv GREETING
argocd app history hello-web-dev
```

L'interrogation est réglée à 30 secondes sans jitter dans ce kit, mais le rendu et le déploiement prennent aussi du temps. Le résultat attendu est trois réplicas et le nouveau message dans `GREETING`.

Pour la deuxième livraison, changez `image.tag` en `"0.4-plain-text"`, puis refaites `git add`, `git commit`, `git push` et observez la synchronisation.

## B7. Tester la réconciliation

### Auto-réparation

```bash
kubectl -n hello-dev scale deploy hello-web --replicas=10
kubectl -n hello-dev get deploy hello-web -w
```

Argo CD doit rétablir le nombre décrit dans Git grâce à `selfHeal: true`. La modification peut être corrigée avant même que tous les pods supplémentaires démarrent. Quittez l'observation avec `Ctrl+C`.

### Suppression d'une ressource et retour arrière Git

```bash
git rm hello-web/templates/service.yaml
git commit -m "Suppression du Service hello-web"
git push
argocd app get hello-web-dev --refresh
argocd app wait hello-web-dev --sync --timeout 300
kubectl -n hello-dev get services
```

Après synchronisation, `prune: true` retire le Service. Sans élagage automatique, Argo CD peut signaler l'écart et conserver la ressource. L'affichage « orphaned » dépend d'une fonctionnalité distincte de surveillance des ressources orphelines ; ce statut n'est pas garanti par le simple arrêt du prune.

Pour annuler le commit qui vient de supprimer le Service :

```bash
git revert --no-edit HEAD
git push
argocd app get hello-web-dev --refresh
```

### Image invalide

Mettez temporairement `image.tag: "does-not-exist"`, committez et poussez. `Synced` indique l'accord de la configuration avec Git ; `Healthy` décrit la santé des ressources. Une Application peut donc être synchronisée tout en restant `Progressing` ou en devenant `Degraded`. Les pods peuvent afficher `ImagePullBackOff`. Annulez le dernier commit avec `git revert --no-edit HEAD`, puis poussez.

### Synchronisation manuelle

Cette manipulation concerne l'Application autonome, avant la création de l'ApplicationSet :

```bash
argocd app set hello-web-dev --sync-policy none
```

Modifiez une valeur, committez et poussez. Après actualisation, examinez **App Diff**, puis synchronisez :

```bash
argocd app get hello-web-dev --refresh
argocd app diff hello-web-dev
argocd app sync hello-web-dev
argocd app set hello-web-dev --sync-policy automated --auto-prune --self-heal
```

Une fois l'Application gérée par un ApplicationSet, modifiez la politique dans le modèle de l'ApplicationSet, car son contrôleur peut rétablir la configuration des Applications générées. [Synchronisation automatisée](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/).

## B8. Utiliser deux environnements avec ApplicationSet

Le fichier `values-prod.yaml` est déjà fourni et a été committé à l'étape B4. Il fixe quatre réplicas pour prod, tandis que dev utilise les valeurs de base.

Supprimez d'abord l'Application autonome. Son finalizer supprime les ressources qu'elle gère :

```bash
kubectl delete -f argocd/application.yaml
kubectl apply -f argocd/applicationset.yaml
kubectl -n argocd wait --for=create application/hello-web-dev --timeout=120s
kubectl -n argocd wait --for=create application/hello-web-prod --timeout=120s
kubectl get applications -n argocd
argocd app wait hello-web-dev --sync --health --timeout 300
argocd app wait hello-web-prod --sync --health --timeout 300
kubectl get deploy -A -l app.kubernetes.io/name=hello-web
```

| Application | Namespace | Valeurs |
| --- | --- | --- |
| `hello-web-dev` | `hello-dev` | `values.yaml` |
| `hello-web-prod` | `hello-prod` | Valeurs de base, puis `values-prod.yaml` |

Le fichier de valeurs indiqué dans `valueFiles` surcharge les valeurs par défaut du chart. Ajoutez staging en insérant un élément dans `spec.generators[0].list.elements` :

```yaml
- environment: staging
  namespace: hello-staging
  valueFile: values.yaml
```

Réappliquez `argocd/applicationset.yaml`. Un seul élément de trois lignes suffit ici. L'ApplicationSet est appliqué manuellement à cette étape ; modifier son fichier dans Git seul ne le met pas à jour tant qu'aucune Application racine ne gère ce fichier.

Le contrôleur crée les Applications de façon asynchrone. Les deux commandes `kubectl wait --for=create` attendent leur existence avant de vérifier leur synchronisation avec la CLI Argo CD. [Documentation kubectl wait](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_wait/).

## B9. Point d'étape

À la fin du parcours, vous devez pouvoir :

- Lire le YAML produit par `helm template` et distinguer rendu et validation serveur.
- Installer une release Helm, la mettre à jour et revenir à une révision antérieure.
- Expliquer comment une modification committée et poussée devient une modification du cluster.
- Distinguer `Synced` (configuration conforme à Git) et `Healthy` (ressources en bonne santé).
- Observer `selfHeal`, `prune` et le retour arrière par `git revert`.
- Déployer le même chart dans deux namespaces avec des valeurs différentes via un ApplicationSet.

## Extension fournie : Argo CD se gère lui-même

Le fichier `argocd/argocd-self-managed.yaml` est optionnel. Il utilise le chart officiel figé et le fichier `argocd/values.yaml` de votre dépôt Git. Assurez-vous d'avoir committé et poussé ce fichier de valeurs avant de l'appliquer :

```bash
kubectl apply -f argocd/argocd-self-managed.yaml
```

Ce manifeste n'a pas de finalizer de suppression en cascade : sa suppression permet de retirer cette gestion GitOps avant la désinstallation Helm. Les autres extensions du texte d'origine restent des exercices distincts.

## Nettoyage ciblé du TP

Arrêtez les `port-forward` avec `Ctrl+C`. Supprimez les Applications tant que leurs contrôleurs fonctionnent :

```bash
kubectl delete -f argocd/argocd-self-managed.yaml --ignore-not-found
kubectl delete -f argocd/applicationset.yaml --ignore-not-found
kubectl delete -f argocd/application.yaml --ignore-not-found
kubectl get applications -n argocd
```

Attendez que les Applications du TP aient disparu et que leurs ressources soient nettoyées avant de désinstaller Argo CD :

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
kubectl delete namespace hello-dev hello-prod hello-staging --ignore-not-found
```

Ces namespaces sont ceux réservés à ce TP. Les CRD Argo CD restent en place ; le nettoyage courant ne supprime pas globalement toutes les CRD `argoproj.io`, car elles peuvent appartenir à d'autres installations.

## Repères et dépannage

| Situation | Vérification |
| --- | --- |
| `helm` n'annonce pas v4 | Vérifier `command -v helm`, puis utiliser l'export PATH de l'étape 0 si la formule Homebrew `helm` est installée. |
| `cd: no such file or directory` | Télécharger et extraire l'archive, puis vérifier l'emplacement réel du dossier dans le Finder. |
| `hello-web/Chart.yaml` introuvable | Revenir à la racine du dossier extrait et vérifier `ls hello-web/Chart.yaml` avant de lancer Helm. |
| `tree: command not found` | Utiliser `ls hello-web argocd` ; l'installation de `tree` est facultative. |
| `repository not found` | Vérifier `repoURL`, l'existence du dépôt et les accès configurés dans Argo CD. |
| `app path does not exist` | Le chemin doit être `hello-web`, relatif à la racine du dépôt. |
| Pas de changement après un commit | Vérifier `git push`, la branche `main`, puis utiliser `--refresh`. |
| `ImagePullBackOff` | Lire `kubectl describe pod` et vérifier le tag, l'accès au registre et l'architecture des nœuds. |
| `field is immutable` | Rétablir les labels de sélection du Deployment. |
| `port-forward` se termine | Relancer la même commande après le remplacement du pod cible. |
| Port déjà utilisé sur le Mac | Examiner `lsof -nP -iTCP:8080 -sTCP:LISTEN` ou le port 8081 ; utiliser un port local libre. |

Les fichiers YAML statiques et la syntaxe du script ont été vérifiés lors de la préparation. Helm et l'accès à votre cluster ne sont pas disponibles dans cet environnement de préparation : `helm lint`, le rendu Helm et les validations serveur restent à exécuter sur votre Mac avec les commandes ci-dessus.
