#!/bin/bash
# =============================================================================
# update-vai.sh - Atualizador Arch Linux (menu completo, relatório detalhado)
# Autor: Diego Ernani (CapivaraVai)
# Versão: 0.7.0
# =============================================================================

set -Eeuo pipefail

_early_error() { echo "[ERROR] $*" >&2; }
trap 'rc=$?; _early_error "Erro inesperado (linha $LINENO): $BASH_COMMAND (exit=$rc)"; exit $rc' ERR

VERSION="0.7.0"
AUTHOR="Diego Ernani (CapivaraVai)"

LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/arch-update-vai/logs"
mkdir -p "$LOGDIR"
( ls -1t "$LOGDIR"/update-vai-*.log 2>/dev/null | tail -n +31 | xargs -r rm -f -- ) || true
LOGFILE="$LOGDIR/update-vai-$(date '+%Y%m%d-%H%M%S').log"
START_EPOCH=$(date +%s)



ASSUME_YES=false
AUTO=false

REFRESH_KEYS=true
KEY_REFRESH_MODE="fast"   # fast|full

SUCCESS_COUNT=0
WARNING_COUNT=0
ERROR_COUNT=0
FAIL=0
START=$(date +%s)

# Listas de notificações (até 5 aparecem no relatório)
WARNINGS_LIST=()
ERRORS_LIST=()

# Contagem de atualizações por "backend"
UPDATED_PACMAN=0
UPDATED_YAY=0
UPDATED_FLATPAK=0
UPDATED_SNAP=0
UPDATED_FWUPD=0
OUTDATED_PIP=0

# Reboot/relogin
REBOOT_REQUIRED=false
REBOOT_REASONS=()

# -------------------------
# Util: leitura confiável (não quebra com pipes)
# -------------------------
tty_read() { # tty_read "Prompt" var
  local prompt="$1" varname="$2"
  IFS= read -r -p "$prompt" "$varname" < /dev/tty
}

# -------------------------
# Log e mensagens
# -------------------------
# (rotação de logs já foi feita no início do script)


timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

_log_plain() {
  mkdir -p "$LOGDIR" 2>/dev/null || true
  printf "[%s] %s\n" "$(timestamp)" "$*" >> "$LOGFILE" 2>/dev/null || true
}

_log_plain "==== update-vai v$VERSION | $(date) | host=$(hostname) | kernel=$(uname -r) ===="

_print() { printf "%b\n" "$*"; }

info() {
  _print "\033[1;34m[INFO]\033[0m $1"
  _log_plain "[INFO] $1"
  return 0
}

success() {
  ((SUCCESS_COUNT++)) || true
  _print "\033[1;32m[SUCCESS]\033[0m $1"
  _log_plain "[SUCCESS] $1"
  return 0
}

warn() {
  ((WARNING_COUNT++)) || true
  WARNINGS_LIST+=("$1")
  _print "\033[1;33m[WARNING]\033[0m $1"
  _log_plain "[WARNING] $1"
  return 0
}

error() {
  ((ERROR_COUNT++)) || true
  ERRORS_LIST+=("$1")
  _print "\033[1;31m[ERROR]\033[0m $1"
  _log_plain "[ERROR] $1"
  return 0
}

reset_report() {
  SUCCESS_COUNT=0
  WARNING_COUNT=0
  ERROR_COUNT=0
  FAIL=0
  START=$(date +%s)

  WARNINGS_LIST=()
  ERRORS_LIST=()

  UPDATED_PACMAN=0
  UPDATED_YAY=0
  UPDATED_FLATPAK=0
  UPDATED_SNAP=0
  UPDATED_FWUPD=0
  OUTDATED_PIP=0

  REBOOT_REQUIRED=false
  REBOOT_REASONS=()

  info "Log em: $LOGFILE"
}

_add_reboot_reason() {
  local reason="$1"
  REBOOT_REQUIRED=true
  # evita duplicatas
  for r in "${REBOOT_REASONS[@]}"; do
    [[ "$r" == "$reason" ]] && return 0
  done
  REBOOT_REASONS+=("$reason")
  return 0
}

# Detecta se algum pacote crítico foi atualizado (lista de nomes)
_check_reboot_from_pkglist() {
  # recebe lista via stdin: nomes de pacotes, um por linha
  while IFS= read -r pkg; do
    [[ -z "$pkg" ]] && continue
    case "$pkg" in
      linux|linux-lts|linux-zen|linux-hardened)
        _add_reboot_reason "Kernel ($pkg) foi atualizado. Reinício necessário para usar o kernel novo."
        ;;
      amd-ucode|intel-ucode)
        _add_reboot_reason "Microcode ($pkg) foi atualizado. Reinício recomendado para aplicar."
        ;;
      systemd)
        _add_reboot_reason "systemd foi atualizado. Reinício recomendado para garantir que serviços usem a nova versão."
        ;;
      glibc)
        _add_reboot_reason "glibc foi atualizada. Reinício recomendado (muitos processos ficam usando bibliotecas antigas)."
        ;;
      linux-firmware)
        _add_reboot_reason "linux-firmware foi atualizado. Reinício recomendado para aplicar firmware em drivers."
        ;;
    esac
  done
}

# Kernel em uso x kernel instalado
_check_kernel_mismatch() {
  local running installed running_norm installed_norm

  running="$(uname -r 2>/dev/null || true)"
  [[ -z "$running" ]] && return 0

  # Normaliza para evitar falso positivo (ex.: 6.18.9.arch1-2 vs 6.18.9-arch1-2)
  # Troca '-' por '.' em ambos e compara por substring.
  running_norm="${running//-/.}"

  # Se o kernel em uso é LTS (uname termina com -lts), compare com linux-lts.
  if [[ "$running" == *"lts"* ]]; then
    if pacman -Q linux-lts >/dev/null 2>&1; then
      installed="$(pacman -Q linux-lts | awk '{print $2}')"
      installed_norm="${installed//-/.}"
      if [[ -n "$installed_norm" && "$running_norm" != *"$installed_norm"* ]]; then
        _add_reboot_reason "Kernel LTS instalado (linux-lts=$installed) difere do kernel em uso ($running). Reinicie para aplicar."
      fi
    fi
    return 0
  fi

  # Kernel "normal" em uso: compare com pacote linux.
  if pacman -Q linux >/dev/null 2>&1; then
    installed="$(pacman -Q linux | awk '{print $2}')"
    installed_norm="${installed//-/.}"
    if [[ -n "$installed_norm" && "$running_norm" != *"$installed_norm"* ]]; then
      _add_reboot_reason "Kernel instalado (linux=$installed) difere do kernel em uso ($running). Reinicie para aplicar."
    fi
  fi
}

show_report() {
  local END DURATION
  END=$(date +%s)
  DURATION=$((END - START))

  echo
  echo "=============================================================="
  echo "                    📊 RELATÓRIO"
  echo "=============================================================="
  echo " ✅ Sucessos : $SUCCESS_COUNT"
  echo " ⚠️  Atenções : $WARNING_COUNT"
  echo " ❌ Falhas   : $ERROR_COUNT"
  echo " ⏱ Tempo total: ${DURATION}s"
  echo " 📄 Log: $LOGFILE"
  echo "--------------------------------------------------------------"
  echo " 📦 Atualizações por comando:"
  echo "   - pacman : $UPDATED_PACMAN"
  echo "   - yay    : $UPDATED_YAY"
  echo "   - flatpak: $UPDATED_FLATPAK"
  echo "   - snap   : $UPDATED_SNAP"
  echo "   - fwupd  : $UPDATED_FWUPD"
  echo "   - pip (outdated detectados): $OUTDATED_PIP"
  echo "=============================================================="

  # Mostrar até 5 notificações (warnings + errors)
  local total_notifications=$((WARNING_COUNT + ERROR_COUNT))
  if [[ $total_notifications -gt 0 && $total_notifications -le 5 ]]; then
    echo
    echo "📌 Notificações:"
    for msg in "${ERRORS_LIST[@]}"; do
      echo " ❌ $msg"
    done
    for msg in "${WARNINGS_LIST[@]}"; do
      echo " ⚠️  $msg"
    done
  elif [[ $total_notifications -gt 5 ]]; then
    echo
    echo "📌 Notificações: muitas ($total_notifications). Consulte o log para detalhes."
  fi

  # Reboot?
  _check_kernel_mismatch

  if [[ "$REBOOT_REQUIRED" == true ]]; then
    echo
    echo "🔁 Reinício recomendado:"
    for r in "${REBOOT_REASONS[@]}"; do
      echo " - $r"
    done
  else
    echo
    echo "✅ Reinício: não parece necessário."
  fi

  _log_plain "RELATORIO: success=$SUCCESS_COUNT warnings=$WARNING_COUNT errors=$ERROR_COUNT duration=${DURATION}s"
  _log_plain "UPDATED: pacman=$UPDATED_PACMAN yay=$UPDATED_YAY flatpak=$UPDATED_FLATPAK snap=$UPDATED_SNAP fwupd=$UPDATED_FWUPD pip_outdated=$OUTDATED_PIP"
  _log_plain "REBOOT_REQUIRED=$REBOOT_REQUIRED"
  if [[ "$REBOOT_REQUIRED" == true ]]; then
    for r in "${REBOOT_REASONS[@]}"; do _log_plain "REBOOT_REASON: $r"; done
  fi
  _log_plain "LOGFILE: $LOGFILE"

  if [[ "$ERROR_COUNT" -gt 0 ]]; then
    _print "\033[1;31m⚠️  Concluído com falhas (veja o log).\033[0m"
  elif [[ "$WARNING_COUNT" -gt 0 ]]; then
    _print "\033[1;33m⚠️  Concluído com avisos.\033[0m"
  else
    _print "\033[1;32m🎉 Concluído sem problemas!\033[0m"
  fi

  END_EPOCH=$(date +%s)
  DURATION=$((END_EPOCH - START_EPOCH))
  _log_plain "Tempo total: ${DURATION}s"
}

# -------------------------
# Sudo e segurança
# -------------------------
SUDO_KEEPALIVE_PID=""

ensure_sudo() {
  if ! sudo -v; then
    error "Não foi possível obter sudo."
    return 1
  fi

  # já está rodando? não cria outro
  if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    return 0
  fi

  ( while true; do sudo -n true; sleep 60; done ) >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!

  # mata no final do script
  cleanup() {
    [[ -n "${SUDO_KEEPALIVE_PID:-}" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  }
  trap cleanup EXIT

  return 0
}


check_pacman_lock() { [[ -f /var/lib/pacman/db.lck ]]; }

# -------------------------
# Executor de etapas (foreground + log)
# -------------------------
run_step() {
  local name="$1"; shift
  local warn_after="$1"; shift
  local timeout_d="$1"; shift

  _strip_ansi() { sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'; }

  info "➡️  $name"
  _log_plain "COMMAND: $*"
  local start end duration status
  start=$(date +%s)

  local warn_pid=""
  if [[ "$warn_after" -gt 0 ]]; then
    (
      sleep "$warn_after"
      _print "\n\033[1;33m⚠️  Ainda rodando: $name (pode demorar)...\033[0m"
    ) &
    warn_pid=$!
  fi

  if [[ "$timeout_d" != "0" ]] && command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_d" "$@" 2>&1 | _strip_ansi >> "$LOGFILE"
    status=${PIPESTATUS[0]}
  else
    "$@" 2>&1 | _strip_ansi >> "$LOGFILE"
    status=${PIPESTATUS[0]}
  fi


  [[ -n "$warn_pid" ]] && kill "$warn_pid" 2>/dev/null || true

  end=$(date +%s)
  duration=$((end - start))

  if [[ $status -eq 0 ]]; then
    success "⏱ $name concluído em ${duration}s"
    return 0
  else
    FAIL=1
    error "⏱ $name falhou em ${duration}s (status=$status)"
    return $status
  fi
}

# -------------------------
# Helpers de contagem (pré-update)
# -------------------------
_count_lines() { # conta linhas não vazias do stdin
  local c
  c=$(grep -cve '^[[:space:]]*$' 2>/dev/null || true)
  echo "${c:-0}"
}

_count_pacman_updates() {
  # pacman -Qu: lista atualizáveis (repo). Conta linhas.
  local out
  out="$(pacman -Qu 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    echo 0
    return 0
  fi
  printf "%s\n" "$out" | _count_lines
}

_pkglist_pacman_updates() {
  # imprime só o nome do pacote de cada linha do pacman -Qu
  pacman -Qu 2>/dev/null | awk '{print $1}' || true
}

_count_yay_updates() {
  command -v yay >/dev/null 2>&1 || { echo 0; return 0; }
  local out
  out="$(yay -Qu 2>/dev/null || true)"
  [[ -z "$out" ]] && { echo 0; return 0; }
  printf "%s\n" "$out" | _count_lines
}

_pkglist_yay_updates() {
  command -v yay >/dev/null 2>&1 || return 0
  yay -Qu 2>/dev/null | awk '{print $1}' || true
}

_count_flatpak_updates() {
  command -v flatpak >/dev/null 2>&1 || { echo 0; return 0; }
  # flatpak remote-ls --updates: lista atualizáveis; remove cabeçalho ausente.
  local out
  out="$(flatpak remote-ls --updates --columns=application 2>/dev/null || true)"
  [[ -z "$out" ]] && { echo 0; return 0; }
  printf "%s\n" "$out" | _count_lines
}

_count_snap_updates() {
  command -v snap >/dev/null 2>&1 || { echo 0; return 0; }
  # snap refresh --list: header em 1-2 linhas, então conta linhas a partir da 2ª
  local out
  out="$(snap refresh --list 2>/dev/null || true)"
  [[ -z "$out" ]] && { echo 0; return 0; }
  # remove header (primeira linha) e linhas vazias
  printf "%s\n" "$out" | tail -n +2 | _count_lines
}

_count_fwupd_updates() {
  command -v fwupdmgr >/dev/null 2>&1 || { echo 0; return 0; }
  local out
  out="$(fwupdmgr get-updates 2>/dev/null || true)"
  # Conta bullets "•"
  printf "%s\n" "$out" | grep -c "•" 2>/dev/null || echo 0
}

_count_pip_outdated() {
  local py="python"
  command -v python >/dev/null 2>&1 || py="python3"
  command -v "$py" >/dev/null 2>&1 || { echo 0; return 0; }
  "$py" -m pip --version >/dev/null 2>&1 || { echo 0; return 0; }
  local out
  out="$("$py" -m pip list --outdated --format=columns 2>/dev/null || true)"
  # formato columns tem 2 linhas de cabeçalho; remove-as e conta o resto
  printf "%s\n" "$out" | tail -n +3 | _count_lines
}

# -------------------------
# Funções do menu
# -------------------------
update_pacman() {
  ensure_sudo || return 1
  if check_pacman_lock; then
    error "Pacman lock detectado: /var/lib/pacman/db.lck"
    return 1
  fi

  local cnt
  cnt="$(_count_pacman_updates)"
  UPDATED_PACMAN="$cnt"

  # reboot heuristic: checa pacotes críticos que estavam para atualizar
  _pkglist_pacman_updates | _check_reboot_from_pkglist

  run_step "Atualizar pacotes oficiais (pacman) [itens: $cnt]" 20 "2h" sudo pacman -Syu --noconfirm
}

update_yay() {
  command -v yay >/dev/null 2>&1 || { warn "yay não está instalado."; return 0; }

  local cnt
  cnt="$(_count_yay_updates)"
  UPDATED_YAY="$cnt"

  _pkglist_yay_updates | _check_reboot_from_pkglist

  run_step "Atualizar AUR (yay) [itens: $cnt]" 20 "3h" yay -Syu --noconfirm
}

update_flatpak() {
  command -v flatpak >/dev/null 2>&1 || { warn "flatpak não está instalado."; return 0; }

  local cnt
  cnt="$(_count_flatpak_updates)"
  UPDATED_FLATPAK="$cnt"

  run_step "Atualizar Flatpak [itens: $cnt]" 20 "2h" flatpak update -y
}

update_snap() {
  command -v snap >/dev/null 2>&1 || { warn "snap não está instalado."; return 0; }

  local cnt
  cnt="$(_count_snap_updates)"
  UPDATED_SNAP="$cnt"

  ensure_sudo || return 1
  run_step "Atualizar Snap [itens: $cnt]" 20 "2h" sudo snap refresh
}

update_fwupd() {
  command -v fwupdmgr >/dev/null 2>&1 || { warn "fwupd (fwupdmgr) não está instalado."; return 0; }
  ensure_sudo || return 1

  local cnt
  cnt="$(_count_fwupd_updates)"
  UPDATED_FWUPD="$cnt"

  run_step "fwupd: refresh" 15 "45m" sudo fwupdmgr refresh --force || true

  info "➡️  fwupd: get-updates"
  if sudo fwupdmgr get-updates >> "$LOGFILE" 2>&1; then
    success "fwupd: get-updates ok"
  else
    warn "fwupd: get-updates retornou status não-zero (informativo, ignorado)."
  fi

  run_step "fwupd: update [itens: $cnt]" 15 "90m" sudo fwupdmgr update -y || true
  success "fwupd finalizado."
}

verifica_update_pip() {
  local py="python"
  command -v python >/dev/null 2>&1 || py="python3"
  command -v "$py" >/dev/null 2>&1 || { warn "Python não instalado."; return 0; }
  "$py" -m pip --version >/dev/null 2>&1 || { warn "pip não encontrado para $py."; return 0; }

  OUTDATED_PIP="$(_count_pip_outdated)"

  # aqui é só checagem, não atualiza nada
  run_step "Checar pacotes pip (outdated) [itens: $OUTDATED_PIP]" 10 "10m" "$py" -m pip list --outdated --format=columns || true
  success "Checagem do pip concluída."
}

install_pipx_audit() {
  local py="python"
  command -v python >/dev/null 2>&1 || py="python3"
  command -v "$py" >/dev/null 2>&1 || { error "Python não instalado."; return 1; }

  if ! "$py" -m pip --version >/dev/null 2>&1; then
    warn "pip não encontrado. Tentando instalar python-pip via pacman..."
    ensure_sudo || return 1
    run_step "Instalar python-pip (pacman)" 10 "30m" sudo pacman -S --noconfirm python-pip || true
  fi

  if command -v pipx >/dev/null 2>&1; then
    info "pipx já instalado."
  else
    ensure_sudo || return 1
    run_step "Instalar pipx (pacman)" 10 "30m" sudo pacman -S --noconfirm python-pipx || true
  fi

  if command -v pipx >/dev/null 2>&1; then
    run_step "pipx ensurepath" 5 "5m" pipx ensurepath || true
    run_step "Instalar/atualizar pip-audit (pipx)" 10 "20m" pipx install pip-audit || pipx upgrade pip-audit || true
    success "pipx + pip-audit prontos."
  else
    error "pipx não ficou disponível no PATH. Abra um novo terminal."
    return 1
  fi
}

update_keys() {
  [[ "$REFRESH_KEYS" == true ]] || { warn "Atualização de chaves GPG desativada."; return 0; }
  ensure_sudo || return 1

  if [[ "$KEY_REFRESH_MODE" == "fast" ]]; then
    run_step "GPG (fast): archlinux-keyring" 10 "15m" sudo pacman -Sy --noconfirm archlinux-keyring || true
    run_step "GPG (fast): populate" 10 "15m" sudo pacman-key --populate archlinux || true
    success "Keyring atualizado (fast)."
  else
    run_step "GPG (full): archlinux-keyring" 10 "15m" sudo pacman -Sy --noconfirm archlinux-keyring || true
    run_step "GPG (full): init" 10 "15m" sudo pacman-key --init || true
    run_step "GPG (full): populate" 10 "15m" sudo pacman-key --populate archlinux || true
    run_step "GPG (full): refresh-keys" 15 "45m" sudo pacman-key --refresh-keys || true
    success "Chaves GPG sincronizadas (full)."
  fi
}

update_mirrors() {
  command -v reflector >/dev/null 2>&1 || { warn "reflector não está instalado."; return 0; }
  ensure_sudo || return 1
  run_step "Atualizar mirrors (Brasil, últimas 12h)" 10 "20m" \
    sudo reflector -c Brazil -a 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  success "Mirrors atualizados (Brasil)."
}

update_fonts() {
  command -v fc-cache >/dev/null 2>&1 || { warn "fc-cache não encontrado."; return 0; }
  run_step "Recarregar cache de fontes (fc-cache)" 10 "15m" fc-cache -fv || true
  success "Cache de fontes reconstruído."
}

update_icons() {
  command -v gtk-update-icon-cache >/dev/null 2>&1 || { warn "gtk-update-icon-cache não encontrado."; return 0; }
  ensure_sudo || true
  run_step "Atualizar cache de ícones" 10 "20m" bash -c '
    for icondir in /usr/share/icons/*; do
      [ -d "$icondir" ] || continue
      sudo gtk-update-icon-cache -f "$icondir" >/dev/null 2>&1 || true
    done
  ' || true
  success "Cache de ícones atualizado."
}

remove_orphans_pacman() {
  ensure_sudo || return 1

  local -a orphans=()
  mapfile -t orphans < <(pacman -Qdtq 2>/dev/null || true)
  ((${#orphans[@]})) || { info "Nenhum órfão encontrado (pacman)."; return 0; }

  if [[ "$ASSUME_YES" == true ]]; then
    run_step "Remover órfãos (pacman) [itens: ${#orphans[@]}]" 5 "30m" \
      sudo pacman -Rns --noconfirm "${orphans[@]}" || true
    success "Órfãos removidos."
    return 0
  fi

  local answer=""
  tty_read "Remover pacotes órfãos (${#orphans[@]})? [S/n]: " answer
  if [[ "$answer" =~ ^[SsYy]$ || -z "$answer" ]]; then
    run_step "Remover órfãos (pacman) [itens: ${#orphans[@]}]" 5 "30m" \
      sudo pacman -Rns --noconfirm "${orphans[@]}" || true
    success "Órfãos removidos."
  else
    warn "Remoção de órfãos cancelada."
  fi
}

remove_orphans_yay() {
  command -v yay >/dev/null 2>&1 || { warn "yay não está instalado."; return 0; }
  run_step "Limpar yay (yay -Yc)" 10 "30m" yay -Yc --noconfirm || true
  success "Limpeza do yay finalizada."
}

verifica_pacman_integridade() {
  ensure_sudo || return 1
  run_step "Verificar integridade (pacman -Qk)" 10 "45m" sudo pacman -Qk || true
}

verifica_pacman_dependencias() {
  ensure_sudo || return 1
  run_step "Verificar dependências (pacman -Dk)" 10 "45m" sudo pacman -Dk || true
}

check_kernel() {
  local pkg="$1"
  pacman -Q "$pkg" >/dev/null 2>&1 || { warn "Pacote não instalado: $pkg"; return 0; }
  local installed running
  installed=$(pacman -Q "$pkg" | awk '{print $2}')
  running=$(uname -r)
  info "Kernel instalado ($pkg): $installed"
  info "Kernel em uso:           $running"
  success "Resumo do kernel exibido."
}

show_last_log() {
  if [[ -f "$LOGFILE" ]]; then
    tail -n 200 "$LOGFILE"
    success "Últimas linhas do log exibidas."
  else
    warn "Log não encontrado: $LOGFILE"
  fi
}

update_all() {
  ensure_sudo || true

  update_mirrors || true
  update_keys || true

  update_pacman || true
  update_yay || true

  update_flatpak || true
  update_snap || true
  update_fwupd || true
  verifica_update_pip || true

  update_fonts || true
  update_icons || true

  remove_orphans_pacman || true
  remove_orphans_yay || true

  verifica_pacman_integridade || true
  verifica_pacman_dependencias || true
}

# -------------------------
# Menu
# -------------------------
show_menu() {
  set +e
  while true; do
    clear || true
    cat <<EOF
==============================================================
           ATUALIZADOR ARCH LINUX  $VERSION
           Autor: $AUTHOR
==============================================================
 1  🔄 Atualizar tudo
 2  📦 Atualizar pacman
 3  🎩 Atualizar AUR (yay)
 4  📦 Atualizar Flatpak
 5  🐧 Atualizar Snap
 6  🤖 Atualizar firmware (fwupd)
 7  🐍 Checar pacotes Python (pip)
 8  ✨ Instalar pipx + pip-audit
 9  🗝️ Atualizar chaves GPG (executar agora)
10  🌍 Atualizar mirrors (reflector)
11  🔤 Recarregar cache de fontes
12  🖼️ Atualizar cache de ícones
13  🧹 Remover órfãos (pacman)
14  🧹 Limpar yay
15  ✔️ Verificar integridade (pacman -Qk)
16  🔗 Verificar dependências (pacman -Dk)
17  🖥️ Ver resumo do kernel
18  📝 Ver últimas do log
19  🎚️ Alternar atualização de chaves GPG (atual: $REFRESH_KEYS)
20  🛠️ Alterar modo de chaves (atual: $KEY_REFRESH_MODE)
 q  🚪 Sair
==============================================================
EOF

    local opt=""
    tty_read "Escolha uma opção: " opt

    case "$opt" in
      1) reset_report; update_all; show_report ;;
      2) reset_report; update_pacman; show_report ;;
      3) reset_report; update_yay; show_report ;;
      4) reset_report; update_flatpak; show_report ;;
      5) reset_report; update_snap; show_report ;;
      6) reset_report; update_fwupd; show_report ;;
      7) reset_report; verifica_update_pip; show_report ;;
      8) reset_report; install_pipx_audit; show_report ;;
      9) reset_report; update_keys; show_report ;;
      10) reset_report; update_mirrors; show_report ;;
      11) reset_report; update_fonts; show_report ;;
      12) reset_report; update_icons; show_report ;;
      13) reset_report; remove_orphans_pacman; show_report ;;
      14) reset_report; remove_orphans_yay; show_report ;;
      15) reset_report; verifica_pacman_integridade; show_report ;;
      16) reset_report; verifica_pacman_dependencias; show_report ;;
      17) reset_report; check_kernel linux; check_kernel linux-lts; show_report ;;
      18) reset_report; show_last_log; show_report ;;
      19)
        if [[ "$REFRESH_KEYS" == true ]]; then REFRESH_KEYS=false; else REFRESH_KEYS=true; fi
        success "Atualização de chaves GPG agora: $REFRESH_KEYS"
        ;;
      20)
        local mode=""
        info "Modo atual: $KEY_REFRESH_MODE"
        tty_read "Escolha modo (fast/full): " mode
        if [[ "$mode" == "fast" || "$mode" == "full" ]]; then
          KEY_REFRESH_MODE="$mode"
          success "Modo GPG agora: $KEY_REFRESH_MODE"
        else
          warn "Modo inválido."
        fi
        ;;
      q|Q) break ;;
      *) warn "Opção inválida!" ;;
    esac

    echo
    local dummy=""
    tty_read "Pressione Enter para voltar ao menu..." dummy
  done
  return 0
}

# -------------------------
# Args
# -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--auto) AUTO=true; shift ;;
    -y|--yes)  ASSUME_YES=true; shift ;;
    -h|--help)
      echo "Uso: $0 [opções]"
      echo "  -a, --auto    Executa atualização completa sem menu"
      echo "  -y, --yes     Assume 'yes' para confirmações (órfãos)"
      echo "  -h, --help    Mostra esta ajuda"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1"; exit 1 ;;
  esac
done

if [[ "$AUTO" == true ]]; then
  reset_report
  update_all
  show_report
else
  reset_report
  show_menu
fi
