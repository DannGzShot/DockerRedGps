#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  git-tools.sh commit --repo RUTA --message MENSAJE [--remote REMOTO]
  git-tools.sh update-repos --workspace RUTA [--repos "repo1 repo2"] [--remote REMOTO]
  git-tools.sh update-repo --workspace RUTA --name REPO [--remote REMOTO]
  git-tools.sh create-branch --repo RUTA --branch RAMA [--base RAMA] [--remote REMOTO]
  git-tools.sh create-branch-repo --workspace RUTA --name REPO --branch RAMA [--base RAMA] [--remote REMOTO]
  git-tools.sh reset-repo --workspace RUTA --name REPO [--remote REMOTO] [--yes]
  git-tools.sh shell-help

Compatibilidad: gc, update_repos, update_repo, create_branch,
create_branch_repo y reset_repo aceptan sus argumentos posicionales anteriores.
EOF
}

shell_help() {
  cat <<'EOF'
Comandos Git de Bash:
  gc "[FIX] Mensaje"                    Prepara, crea y publica un commit del repo actual.
  update_repos                          Actualiza solo los repos REDGPS configurados dentro de la carpeta actual.
  update_repo commons                   Actualiza un repositorio configurado dentro de la carpeta actual.
  create_branch nueva-rama              Actualiza BASE_BRANCH y crea/publica una rama en el repo actual.
  create_branch_repo commons nueva-rama Crea/publica una rama en un repositorio configurado de la carpeta actual.
  reset_repo commons                    Pide RESET y restaura cambios rastreados contra la rama remota.
  git_help                              Muestra esta ayuda.

Variables opcionales: WORKSPACE, REPOS, BASE_BRANCH y REMOTE.
update_repos no recorre directorios arbitrarios: solo usa REPOS, que por defecto es
alertas partners redgps reportes commons atomic api.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
}

require_option_value() {
  if [[ "$#" -lt 2 || -z "$2" ]]; then
    fail "Falta el valor de $1"
    exit 2
  fi
}

require_repository() {
  local repo_path="$1"

  if [[ ! -d "$repo_path" ]]; then
    fail "No existe el repositorio: $repo_path"
    return 1
  fi

  if ! git -C "$repo_path" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "No es un repositorio Git valido: $repo_path"
    return 1
  fi
}

current_branch() {
  git -C "$1" symbolic-ref --quiet --short HEAD
}

require_branch() {
  local repo_path="$1"

  if ! current_branch "$repo_path" >/dev/null 2>&1; then
    fail "El repositorio esta en detached HEAD: $repo_path"
    return 1
  fi
}

require_remote() {
  local repo_path="$1"
  local remote="$2"

  if ! git -C "$repo_path" remote get-url "$remote" >/dev/null 2>&1; then
    fail "No existe el remoto '$remote' en $repo_path"
    return 1
  fi
}

remote_branch_exists() {
  local repo_path="$1"
  local remote="$2"
  local branch="$3"

  git -C "$repo_path" show-ref --verify --quiet "refs/remotes/$remote/$branch"
}

validate_repo_name() {
  local repo_name="$1"

  case "$repo_name" in
    ''|.|..|*/*)
      fail "Nombre de repositorio invalido: $repo_name"
      return 1
      ;;
  esac
}

validate_branch() {
  local branch="$1"

  if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
    fail "Nombre de rama invalido: $branch"
    return 1
  fi
}

emoji_for() {
  local tag="$1"
  local text="${2^^}"

  case "$tag" in
    SECURITY|SEGURIDAD|SEC) printf '🔒'; return ;;
    UI|UX|DESIGN|STYLE) printf '🎨'; return ;;
    A11Y|ACCESSIBILITY|ACCESIBILIDAD) printf '♿'; return ;;
    PERF|PERFORMANCE|RENDIMIENTO) printf '⚡'; return ;;
    REFACTOR) printf '♻️'; return ;;
    DOC|DOCS|DOCUMENTATION) printf '📝'; return ;;
    BUILD) printf '🏗️'; return ;;
    CI|CD) printf '🤖'; return ;;
    TEST|TESTS) printf '🧪'; return ;;
    FIX|HOTFIX|PATCH) printf '🔧'; return ;;
    FEAT|FEATURE) printf '🚀'; return ;;
    DEPS|DEPENDENCIES|UPDATE|CHORE) printf '📦'; return ;;
    REVERT|ROLLBACK) printf '⏪'; return ;;
    RELEASE|VERSION|TAG) printf '🔖'; return ;;
    DB|DATABASE|SCHEMA) printf '🗃️'; return ;;
    INFRA|DEVOPS) printf '🛠️'; return ;;
    CONFIG) printf '⚙️'; return ;;
    LOGGING|MONITORING|OBSERVABILITY) printf '📈'; return ;;
    I18N|L10N) printf '🌐'; return ;;
    DATA|ANALYTICS) printf '📊'; return ;;
    CLEANUP|LINT|FORMAT) printf '🧹'; return ;;
    MERGE) printf '🔀'; return ;;
    WIP) printf '🚧'; return ;;
    BREAKING) printf '💥'; return ;;
    DEPRECATED) printf '🗑️'; return ;;
    SEO|DUMP) printf '🔎'; return ;;
    DEBUG|BUG) printf '🪳'; return ;;
    EMAIL|MAIL) printf '✉️'; return ;;
    MOBILE) printf '📱'; return ;;
    PAYMENT) printf '💳'; return ;;
  esac

  case "$text" in
    *SECURITY*|*SEGURIDAD*|*CVE*|*XSS*|*CSRF*|*AUTH*|*OAUTH*|*HACK*) printf '🔒' ;;
    *DESIGN*|*DISEÑO*|*INTERFAZ*|*STYLE*|*ESTILO*|*LOOK*) printf '🎨' ;;
    *ACCESSIBILITY*|*ACCESIBILIDAD*) printf '♿' ;;
    *PERFORMANCE*|*RENDIMIENTO*|*OPTIMIZA*) printf '⚡' ;;
    *REFACTOR*|*REESTRUCTUR*|*RESTRUCTURE*) printf '♻️' ;;
    *DOCS*|*DOCUMENTA*|*README*|*CHANGELOG*|*GUÍA*|*GUIA*) printf '📝' ;;
    *BUILD*|*COMPIL*|*BUNDLE*) printf '🏗️' ;;
    *PIPELINE*|*WORKFLOW*|*ACTIONS*|*TRUNK*) printf '🤖' ;;
    *TEST*|*PRUEBA*|*UNIT*|*INTEGRAT*|*E2E*) printf '🧪' ;;
    *FIX*|*CORRECCION*|*HOTFIX*|*PATCH*|*REPAR*) printf '🔧' ;;
    *FEAT*|*FEATURE*|*FUNCIONALIDAD*|*CARACTER*|*CAPACIDAD*) printf '🚀' ;;
    *DEPS*|*DEPENDENC*|*PAQUETE*|*MODULE*|*UPDATE*|*UPGRADE*|*BUMP*|*CHORE*|*GENERAL*) printf '📦' ;;
    *REVERT*|*ROLLBACK*) printf '⏪' ;;
    *RELEASE*|*VERSION*|*TAG*) printf '🔖' ;;
    *DATABASE*|*SCHEMA*|*ESQUEMA*|*MIGRACI*|*SQL*) printf '🗃️' ;;
    *INFRA*|*DEVOPS*|*K8S*|*KUBERNETES*|*DOCKER*|*TERRAFORM*|*HELM*) printf '🛠️' ;;
    *CONFIG*|*ENV*|*SETTINGS*|*AJUSTE*) printf '⚙️' ;;
    *LOGGING*|*MONITOR*|*OBSERVAB*|*METRICAS*|*SENTRY*|*DATADOG*) printf '📈' ;;
    *I18N*|*L10N*|*TRADUCC*|*TRANSLATION*|*LOCALE*|*LOCALIZACI*) printf '🌐' ;;
    *DATA*|*DATOS*|*ANALYTICS*|*ANALITICA*) printf '📊' ;;
    *CLEANUP*|*LIMPIEZA*|*FORMAT*|*LINT*|*ORDENAR*) printf '🧹' ;;
    *MERGE*|*INTEGRAR*|*FUSIONAR*) printf '🔀' ;;
    *WIP*|*'EN PROGRESO'*|*'WORK IN PROGRESS'*) printf '🚧' ;;
    *BREAKING*|*ROMP*|*INCOMPATIBLE*|*'API CHANGE'*) printf '💥' ;;
    *DEPRECAT*|*OBSOLE*) printf '🗑️' ;;
    *SEO*|*DUMP*|*CONSOLE*|*ERRORLOG*) printf '🔎' ;;
    *DEBUG*|*BUG*) printf '🪳' ;;
    *EMAIL*|*CORREO*|*MAIL*) printf '✉️' ;;
    *MOBILE*|*ANDROID*|*IOS*|*'REACT NATIVE'*) printf '📱' ;;
    *PAYMENT*|*PAGO*|*STRIPE*|*CHECKOUT*|*PAYPAL*) printf '💳' ;;
    *) printf '📦' ;;
  esac
}

format_commit_message() {
  local message="$1"
  local tag body emoji now_date now_time

  if [[ "$message" =~ ^[[:space:]]*\[([^][]+)\][[:space:]]*(.*)$ ]]; then
    tag="${BASH_REMATCH[1]}"
    body="${BASH_REMATCH[2]}"
  else
    tag="UPDATE"
    body="$message"
  fi

  tag="${tag^^}"
  body="${body#"${body%%[![:space:]]*}"}"
  body="${body%"${body##*[![:space:]]}"}"
  emoji="$(emoji_for "$tag" "$body")"
  now_date="$(date +'%d-%m-%Y')"
  now_time="$(date +'%H:%M')"

  printf '%s [%s] %s %s - %s' "$emoji" "$tag" "$now_date" "$now_time" "$body"
}

update_path() {
  local repo_path="$1"
  local remote="$2"
  local status_only="$3"
  local label="$4"
  local branch upstream

  require_repository "$repo_path" || return 1
  require_branch "$repo_path" || return 1
  require_remote "$repo_path" "$remote" || return 1
  branch="$(current_branch "$repo_path")"

  printf '\n==> %s\n' "${label:-$repo_path}"
  printf 'Rama: %s\n' "$branch"
  upstream="$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  printf 'Upstream: %s\n' "${upstream:-sin configurar}"
  git -C "$repo_path" status --short

  if [[ "$status_only" == '1' ]]; then
    return 0
  fi

  if ! git -C "$repo_path" fetch --prune "$remote"; then
    fail "No se pudo ejecutar fetch --prune en $repo_path"
    return 1
  fi

  if [[ -n "$upstream" ]]; then
    if ! git -C "$repo_path" pull --rebase --autostash; then
      fail "No se pudo actualizar $repo_path; revisa los conflictos"
      return 1
    fi
  elif remote_branch_exists "$repo_path" "$remote" "$branch"; then
    if ! git -C "$repo_path" branch --set-upstream-to="$remote/$branch" "$branch"; then
      fail "No se pudo configurar el upstream de $branch en $repo_path"
      return 1
    fi
    if ! git -C "$repo_path" pull --rebase --autostash; then
      fail "No se pudo actualizar $repo_path; revisa los conflictos"
      return 1
    fi
  else
    fail "La rama remota no existe: $remote/$branch en $repo_path"
    return 1
  fi

  git -C "$repo_path" status --short
}

update_repositories() {
  local workspace="$1"
  local repo_list="$2"
  local remote="$3"
  local status_only="$4"
  local repo_name
  local -a names=()
  local failed=0

  read -r -a names <<< "$repo_list"
  if [[ "${#names[@]}" -eq 0 ]]; then
    fail 'No se configuraron repositorios para actualizar'
    return 1
  fi

  for repo_name in "${names[@]}"; do
    if ! validate_repo_name "$repo_name" || ! update_path "$workspace/$repo_name" "$remote" "$status_only" "$workspace/$repo_name"; then
      failed=1
    fi
  done

  return "$failed"
}

commit_changes() {
  local repo_path="$1"
  local remote="$2"
  local message="$3"
  local upstream final

  require_repository "$repo_path" || return 1
  require_branch "$repo_path" || return 1
  require_remote "$repo_path" "$remote" || return 1

  if ! git -C "$repo_path" fetch --prune "$remote"; then
    fail "No se pudo ejecutar fetch --prune en $repo_path"
    return 1
  fi

  upstream="$(git -C "$repo_path" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [[ -n "$upstream" ]] && ! git -C "$repo_path" pull --rebase --autostash; then
    fail "No se pudo actualizar $repo_path; revisa los conflictos"
    return 1
  fi

  if ! git -C "$repo_path" add -A; then
    fail "No se pudo preparar los cambios en $repo_path"
    return 1
  fi

  if git -C "$repo_path" diff --cached --quiet; then
    printf 'No hay cambios para crear un commit en %s.\n' "$repo_path"
    return 0
  fi

  final="$(format_commit_message "$message")"
  printf 'Commit: %s\n' "$final"
  if ! git -C "$repo_path" commit -m "$final"; then
    return 1
  fi

  if [[ -n "$upstream" ]]; then
    if git -C "$repo_path" push; then
      return 0
    fi
  fi

  if ! git -C "$repo_path" push -u "$remote" HEAD; then
    fail "No se pudo publicar la rama actual de $repo_path"
    return 1
  fi
}

create_branch() {
  local repo_path="$1"
  local remote="$2"
  local base_branch="$3"
  local branch="$4"

  require_repository "$repo_path" || return 1
  require_branch "$repo_path" || return 1
  validate_branch "$branch" || return 1
  validate_branch "$base_branch" || return 1
  require_remote "$repo_path" "$remote" || return 1

  if ! git -C "$repo_path" fetch --prune "$remote"; then
    fail "No se pudo ejecutar fetch --prune en $repo_path"
    return 1
  fi

  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
    fail "La rama local ya existe: $branch"
    return 1
  fi

  if remote_branch_exists "$repo_path" "$remote" "$branch"; then
    fail "La rama remota ya existe: $remote/$branch"
    return 1
  fi

  if ! remote_branch_exists "$repo_path" "$remote" "$base_branch"; then
    fail "La rama base remota no existe: $remote/$base_branch"
    return 1
  fi

  if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$base_branch"; then
    if ! git -C "$repo_path" switch "$base_branch"; then
      fail "No se pudo cambiar a la rama base $base_branch"
      return 1
    fi
  elif ! git -C "$repo_path" switch --track -c "$base_branch" "$remote/$base_branch"; then
    fail "No se pudo crear la rama base local $base_branch"
    return 1
  fi

  if ! git -C "$repo_path" pull --rebase --autostash "$remote" "$base_branch"; then
    fail "No se pudo actualizar la rama base $base_branch"
    return 1
  fi

  if ! git -C "$repo_path" switch -c "$branch"; then
    fail "No se pudo crear la rama $branch"
    return 1
  fi

  if ! git -C "$repo_path" push -u "$remote" "$branch"; then
    fail "No se pudo publicar la rama $branch"
    return 1
  fi

  printf 'Rama creada y publicada: %s\n' "$branch"
}

reset_repository() {
  local repo_path="$1"
  local remote="$2"
  local assume_yes="$3"
  local branch answer

  require_repository "$repo_path" || return 1
  require_branch "$repo_path" || return 1
  require_remote "$repo_path" "$remote" || return 1
  branch="$(current_branch "$repo_path")"

  if ! git -C "$repo_path" fetch --prune "$remote"; then
    fail "No se pudo ejecutar fetch --prune en $repo_path"
    return 1
  fi

  if ! remote_branch_exists "$repo_path" "$remote" "$branch"; then
    fail "La rama remota no existe: $remote/$branch en $repo_path"
    return 1
  fi

  printf 'Se descartaran los cambios locales rastreados en %s para igualar %s/%s.\n' "$repo_path" "$remote" "$branch"
  if [[ "$assume_yes" != '1' ]]; then
    if [[ ! -t 0 ]]; then
      fail 'Se requiere confirmacion interactiva. Usa --yes solo si confirmas explicitamente el reset.'
      return 1
    fi
    read -r -p 'Escribe RESET para confirmar: ' answer
    if [[ "$answer" != 'RESET' ]]; then
      printf 'Reset cancelado.\n'
      return 1
    fi
  fi

  if ! git -C "$repo_path" reset --hard "$remote/$branch"; then
    fail "No se pudo restablecer $repo_path"
    return 1
  fi
}

command_name="${1:-help}"
if [[ "$#" -gt 0 ]]; then
  shift
fi

repo_path="${GIT_REPO:-$PWD}"
workspace="${WORKSPACE:-$PWD}"
repo_list="${REPOS:-alertas partners redgps reportes commons atomic api}"
remote="${REMOTE:-origin}"
base_branch="${BASE_BRANCH:-master}"
message=''
branch=''
repo_name=''
status_only=0
assume_yes=0
label=''

case "$command_name" in
  gc)
    command_name='commit'
    message="${1:-}"
    [[ "$#" -gt 0 ]] && shift
    ;;
  update_repos)
    command_name='update-repos'
    ;;
  update_repo)
    command_name='update-repo'
    repo_name="${1:-}"
    [[ "$#" -gt 0 ]] && shift
    ;;
  create_branch)
    command_name='create-branch'
    branch="${1:-}"
    [[ "$#" -gt 0 ]] && shift
    ;;
  create_branch_repo)
    command_name='create-branch-repo'
    repo_name="${1:-}"
    branch="${2:-}"
    [[ "$#" -gt 0 ]] && shift
    [[ "$#" -gt 0 ]] && shift
    ;;
  reset_repo)
    command_name='reset-repo'
    repo_name="${1:-}"
    [[ "$#" -gt 0 ]] && shift
    ;;
esac

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --repo)
      require_option_value "$@"
      repo_path="$2"
      shift 2
      ;;
    --workspace)
      require_option_value "$@"
      workspace="$2"
      shift 2
      ;;
    --repos)
      require_option_value "$@"
      repo_list="$2"
      shift 2
      ;;
    --name)
      require_option_value "$@"
      repo_name="$2"
      shift 2
      ;;
    --remote)
      require_option_value "$@"
      remote="$2"
      shift 2
      ;;
    --base)
      require_option_value "$@"
      base_branch="$2"
      shift 2
      ;;
    --branch)
      require_option_value "$@"
      branch="$2"
      shift 2
      ;;
    --message)
      require_option_value "$@"
      message="$2"
      shift 2
      ;;
    --label)
      require_option_value "$@"
      label="$2"
      shift 2
      ;;
    --status)
      status_only=1
      shift
      ;;
    --yes)
      assume_yes=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Opcion o comando desconocido: $1"
      usage >&2
      exit 2
      ;;
  esac
done

case "$command_name" in
  help|-h|--help)
    usage
    ;;
  shell-help)
    shell_help
    ;;
  commit)
    if [[ -z "$message" ]]; then
      fail 'Falta el mensaje de commit'
      exit 2
    fi
    commit_changes "$repo_path" "$remote" "$message"
    ;;
  update-path)
    update_path "$repo_path" "$remote" "$status_only" "$label"
    ;;
  update-repos)
    update_repositories "$workspace" "$repo_list" "$remote" "$status_only"
    ;;
  update-repo)
    validate_repo_name "$repo_name"
    update_path "$workspace/$repo_name" "$remote" "$status_only" "$workspace/$repo_name"
    ;;
  create-branch)
    if [[ -z "$branch" ]]; then
      fail 'Falta el nombre de la rama'
      exit 2
    fi
    create_branch "$repo_path" "$remote" "$base_branch" "$branch"
    ;;
  create-branch-repo)
    validate_repo_name "$repo_name"
    if [[ -z "$branch" ]]; then
      fail 'Falta el nombre de la rama'
      exit 2
    fi
    create_branch "$workspace/$repo_name" "$remote" "$base_branch" "$branch"
    ;;
  reset-repo)
    validate_repo_name "$repo_name"
    reset_repository "$workspace/$repo_name" "$remote" "$assume_yes"
    ;;
  *)
    fail "Comando desconocido: $command_name"
    usage >&2
    exit 2
    ;;
esac
