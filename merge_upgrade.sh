#!/usr/bin/env bash
set -euxo pipefail

readonly MAIN_REPO="csi-aio-test"

readonly REPOS_TO_MERGE=(
  "external-attacher"
  "external-resizer"
)

readonly PREP_BRANCH="monorepo-prep"

readonly FILES_TO_EXCLUDE=(
  ".git"
  ".github"
  "packages"
  "vendor"
  "release-tools"
  "go.mod"
  "go.sum"
  "Dockerfile"
  ".cloudbuild.sh"
  "cloudbuild.yaml"
  ".prow.sh"
  "OWNER_ALIASES"
  "Makefile"
)

readonly FILES_TO_REMOVE=(
  "vendor"
  ".prow.sh"
  "Dockerfile"
  "Makefile"
  "SECURITY_CONTACTS"
  "release-tools"
  "go.mod"
  "go.sum"
  "CONTRIBUTING.md"
  "LICENSE"
  "code-of-conduct.md"
)

log_info() {
  echo -e "\033[34m[INFO]\033[0m $1"
}

log_success() {
  echo -e "\033[32m[SUCCESS]\033[0m $1"
}

log_warn() {
  echo -e "\033[33m[WARN]\033[0m $1"
}

log_error() {
  echo -e "\033[31m[ERROR]\033[0m $1" >&2
  exit 1
}

prepare_repo() {
  local repo_name=$1
  log_info "--- start with  $repo_name ---"

  if [ ! -d "$repo_name" ]; then
    log_error "repo '$repo_name' not exists"
  fi

  cd "$repo_name"

  local primary_branch
  primary_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@')
  if [ -z "$primary_branch" ]; then
      primary_branch=$(git branch -r | grep -E 'origin/(main|master)$' | head -n 1 | sed 's@^origin/@@')
  fi
  

  log_info "create path '$PREP_BRANCH'..."
  git switch -C "$PREP_BRANCH" "origin/$primary_branch"

  local target_dir="packages/$repo_name"

  if [ -d "$target_dir" ] && [ -n "$(ls -A "$target_dir")" ]; then
      log_warn "dir '$target_dir' exists, skip "
      cd ..
      return
  fi

  mkdir -p "$target_dir"
  for item in "${FILES_TO_REMOVE[@]}"; do
    if [ -e "$item" ]; then
      log_info "  -> deleting $item"
      git rm -r --ignore-unmatch "$item"
      items_removed=true
    else
      log_warn "  -> $item not exists，skip deleting。"
    fi
  done

  local find_args=()
  for item in "${FILES_TO_EXCLUDE[@]}"; do
    find_args+=(-o -name "$item")
  done
  find . -mindepth 1 -maxdepth 1 ! \( "${find_args[@]:1}" \) | xargs -I {} git mv -k {} "$target_dir/";

  if ! git diff --quiet --cached; then
    git commit -m "feat($repo_name): move content to subdirectory for monorepo migration"
  else
    log_warn "no change"
  fi

  cd ..
  log_success "--- finished: $repo_name ---\n"
}

merge_repo_to_main() {
  local repo_name=$1
  local remote_name="temp-$repo_name"
  
  log_info "--- merging: $repo_name -> $MAIN_REPO ---"

  if git remote | grep -q "^${remote_name}$"; then
    log_warn "remote repo '$remote_name' exist"
  else
    git remote add "$remote_name" "../$repo_name"
  fi
  
  log_info "fetching from '$remote_name'"
  git fetch "$remote_name"

  log_info "start merging '$PREP_BRANCH'..."
  git merge --no-ff --allow-unrelated-histories -m "feat: merge $repo_name into monorepo" "$remote_name/$PREP_BRANCH"

  log_info "remove remote branch '$remote_name'..."
  git remote remove "$remote_name"

  log_success "--- merge success: $repo_name ---\n"
}


main() {
  cd "$(dirname -- "${BASH_SOURCE[0]}")"

  for repo in "${REPOS_TO_MERGE[@]}"; do
    prepare_repo "$repo"
  done

  if [ ! -d "$MAIN_REPO" ]; then
    log_error "repo '$MAIN_REPO' not exists"
  fi
  cd "$MAIN_REPO"
  
  local main_primary_branch
  main_primary_branch=$(git symbolic-ref --short HEAD)

  for repo in "${REPOS_TO_MERGE[@]}"; do
    merge_repo_to_main "$repo"
  done

  log_success "all repo success '$MAIN_REPO'！"
}

main "$@"

