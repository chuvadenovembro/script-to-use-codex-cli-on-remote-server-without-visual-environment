#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# codex-auth-transfer.sh
# Exporta e importa credenciais do Codex CLI entre máquinas.
#
# Uso:
#   Exportar (padrão):
#     ./codex-auth-transfer.sh export [-o arquivo.tar.gz]
#   Importar (no servidor destino, mesmo diretório do .tar.gz):
#     ./codex-auth-transfer.sh import [-f arquivo.tar.gz] [--force]
#
# O script procura e empacota conteúdos sensíveis de:
#   ~/.config/codex
#   ~/.local/share/codex
# (Se existirem). Na importação, faz backup do que existir e aplica permissões seguras.

PROGRAM="codex-auth-transfer"
DEFAULT_BUNDLE="codex-auth-bundle.tar.gz"

log() { printf '[%s] %s\n' "$PROGRAM" "$*"; }
err() { printf '[%s][ERRO] %s\n' "$PROGRAM" "$*" 1>&2; }

usage() {
  cat <<EOF
Uso:
  $0 export [-o arquivo.tar.gz]
  $0 import [-f arquivo.tar.gz] [--force]

Opções:
  export              Empacota credenciais do Codex da máquina atual.
  import              Restaura credenciais no HOST destino (headless).
  -o, --output        Nome do arquivo de saída (default: ${DEFAULT_BUNDLE}).
  -f, --file          Arquivo .tar.gz para importar (default: ${DEFAULT_BUNDLE}).
  --force             Sobrescreve diretórios de destino sem perguntar (faz backup).
  -h, --help          Mostra esta ajuda.

Notas:
  - O bundle contém caminhos relativos (ex.: .config/codex, .local/share/codex).
  - Durante a importação, se existir um destino (ex.: ~/.config/codex), será feito
    backup em <destino>.bak-YYYYmmdd-HHMMSS antes de copiar.
EOF
}

# Coleta caminhos candidatos contendo credenciais do Codex
find_codex_paths() {
  local base_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local base_data="${XDG_DATA_HOME:-$HOME/.local/share}"

  local candidates=(
    "$base_config/codex"
    "$base_data/codex"
    "$HOME/.codex"
  )

  # Se houver um comando para apontar o diretório, tente usá-lo (melhor esforço)
  if command -v codex >/dev/null 2>&1; then
    # Algumas versões podem ter um subcomando que revela config; ignorar erros.
    set +e
    local hinted
    hinted=$(codex config path 2>/dev/null || true)
    set -e
    if [ -n "${hinted:-}" ] && [ -d "$hinted" ]; then
      candidates=("$hinted" "${candidates[@]}")
    fi
  fi

  # Filtra os existentes
  local existing=()
  for p in "${candidates[@]}"; do
    if [ -e "$p" ]; then
      existing+=("$p")
    fi
  done

  printf '%s\n' "${existing[@]}"
}

timestamp() { date +%Y%m%d-%H%M%S; }

do_export() {
  local bundle="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'test -n "${tmpdir:-}" && rm -rf "$tmpdir"' EXIT

  log "Procurando diretórios de credenciais do Codex..."
  mapfile -t paths < <(find_codex_paths)
  if [ "${#paths[@]}" -eq 0 ]; then
    err "Nenhum diretório de credenciais do Codex encontrado. Abortando."
    exit 1
  fi

  log "Diretórios detectados:"; printf '  - %s\n' "${paths[@]}"

  # Monta estrutura relativa ao HOME (.config/.local/...)
  mkdir -p "$tmpdir/stage"

  local listfile="$tmpdir/stage/.codex_auth_paths.txt"
  : > "$listfile"

  for p in "${paths[@]}"; do
    # Converte caminho absoluto para relativo ao HOME quando possível
    local rel
    if [[ "$p" == "$HOME/"* ]]; then
      rel=".${p#"$HOME"}"
    else
      # Se não estiver sob $HOME, coloca em .codex-external/<hash>
      local h
      h=$(printf '%s' "$p" | sha1sum | awk '{print $1}')
      rel=".codex-external/$h"
    fi

    local dest="$tmpdir/stage/$rel"
    mkdir -p "$(dirname "$dest")"

    if command -v rsync >/dev/null 2>&1; then
      rsync -a --chmod=Du+rwx,Fu+rw "$p/" "$dest/"
    else
      # cp -a como fallback
      mkdir -p "$dest"
      cp -a "$p/." "$dest/"
      # Ajuste permissões no staging
      find "$dest" -type d -exec chmod 700 {} +
      find "$dest" -type f -exec chmod 600 {} +
    fi

    printf '%s\n' "$rel" >> "$listfile"
  done

  # Cria manifest simples (sem dados de usuário/host se CODEX_AUTH_TRANSFER_NO_METADATA=1)
  {
    echo "created_at=$(date -Iseconds)"
    echo "paths_file=.codex_auth_paths.txt"
    if [ "${CODEX_AUTH_TRANSFER_NO_METADATA:-0}" != "1" ]; then
      echo "user=$USER"
      echo "host=$(hostname -f 2>/dev/null || hostname)"
    fi
  } > "$tmpdir/stage/.codex_auth_manifest"

  # Empacota para fora da pasta sendo arquivada para evitar loop
  tar -czf "${PWD}/${bundle##*/}" -C "$tmpdir/stage" .
  chmod 600 "${PWD}/${bundle##*/}"
  log "Bundle criado: ${PWD}/${bundle##*/}"
  log "Guarde este arquivo com segurança."
}

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ]; then
    local bkp="${target}.bak-$(timestamp)"
    log "Backup do destino existente: $target -> $bkp"
    mv "$target" "$bkp"
  fi
}

do_import() {
  local bundle="$1"
  local force="$2"

  if [ ! -f "$bundle" ]; then
    err "Arquivo não encontrado: $bundle"
    exit 1
  fi

  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'test -n "${tmpdir:-}" && rm -rf "$tmpdir"' EXIT

  log "Extraindo bundle..."
  tar -xzf "$bundle" -C "$tmpdir"

  # Determina lista de caminhos a restaurar
  local listfile="$tmpdir/.codex_auth_paths.txt"
  if [ ! -f "$listfile" ]; then
    # Fallback: inferir do conteúdo
    log "Lista de caminhos não encontrada no bundle; inferindo..."
    (cd "$tmpdir" && find . -maxdepth 2 -type d \( -path './.config/codex' -o -path './.local/share/codex' -o -path './.codex' -o -path './.codex-external/*' \) | sed 's|^./||' > "$listfile")
  fi

  if [ ! -s "$listfile" ]; then
    err "Nenhum caminho de credencial encontrado para restaurar. Abortando."
    exit 1
  fi

  log "Caminhos a restaurar:"; sed 's/^/  - /' "$listfile"

  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local src="$tmpdir/$rel"
    local dest="$HOME/$rel"

    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ]; then
      if [ "$force" = "1" ]; then
        backup_if_exists "$dest"
      else
        err "Destino já existe: $dest"
        err "Reexecute com --force para fazer backup e sobrescrever."
        exit 1
      fi
    fi

    mkdir -p "$dest"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --chmod=Du+rwx,Fu+rw "$src/" "$dest/"
    else
      cp -a "$src/." "$dest/"
    fi

    # Permissões seguras
    find "$dest" -type d -exec chmod 700 {} +
    find "$dest" -type f -exec chmod 600 {} +
  done < "$listfile"

  log "Credenciais restauradas em $HOME."
  log "Atenção: alguns CLIs atrelam tokens ao host/usuário; se o Codex recusar, use login por device code ou túnel."
}

main() {
  local cmd=""
  local bundle=""
  local force=0

  # Parsing simples
  while [ $# -gt 0 ]; do
    case "$1" in
      export|import)
        cmd="$1"; shift ;;
      -o|--output)
        bundle="${2:-}"; shift 2 ;;
      -f|--file)
        bundle="${2:-}"; shift 2 ;;
      --force)
        force=1; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        err "Opção desconhecida: $1"; usage; exit 1 ;;
    esac
  done

  if [ -z "$cmd" ]; then
    usage; exit 1
  fi

  if [ -z "$bundle" ]; then
    bundle="$DEFAULT_BUNDLE"
  fi

  case "$cmd" in
    export)
      do_export "$bundle" ;;
    import)
      do_import "$bundle" "$force" ;;
  esac
}

main "$@"
