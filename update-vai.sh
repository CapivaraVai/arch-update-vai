#!/bin/bash
# ============================================================
# update.sh - Script de atualização para Arch Linux
# Autor: Diego Ernani (CapivaraVai)
# Versão: 0.2.1
# Última atualização: 2026-02-03
# ============================================================
# Licença: GNU GPL v3 ou superior
# ============================================================

set -euo pipefail

VERSION="0.2.1"
AUTHOR="Diego Ernani (CapivaraVai)"
LOGDIR="$HOME/arch-update-script-vai/logs"
mkdir -p "$LOGDIR"
LOGFILE="$LOGDIR/update-vai-$(date '+%Y%m%d-%H%M%S').log"
START=$(date +%s)

# Flags configuráveis via CLI
ASSUME_YES=false
AUTO=false

# Controle da atualização de chaves GPG
# REFRESH_KEYS=true  -> faz refresh (padrão; pode ser lento)
# REFRESH_KEYS=false -> pula atualização de chaves
REFRESH_KEYS=true
# KEY_REFRESH_MODE: "full" (consulta keyservers) ou "fast" (somente popula localmente)
KEY_REFRESH_MODE="full"

# -------------------------
# Registro: manter cores no terminal mas limpar o log
# remove códigos ANSI e backspaces do que vai para o log
exec > >(tee >(perl -pe 's/\e\[[\d;]*[A-Za-z]//g; s/\x08//g' >> "$LOGFILE")) 2>&1

# -------------------------
# Mensagens coloridas
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

highlight_green()  { echo -e "\033[1;32m$1\033[0m"; }
highlight_yellow() { echo -e "\033[1;33m$1\033[0m"; }
highlight_red()    { echo -e "\033[1;31m$1\033[0m"; }

echo -e "\033[1;36m=== Atualizador Arch Linux ===\033[0m"
echo "Autor: $AUTHOR | Versão: $VERSION"
echo "Data: $(date '+%d/%m/%Y %H:%M:%S')"
echo "Log: $LOGFILE"
echo "------------------------------------------------------------"

# -------------------------
# Spinner simples (usa \r e limpa a linha)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local ch=${spinstr:0:1}
        printf "\r [%c] " "$ch"
        spinstr=${spinstr#?}$ch
        sleep "$delay"
    done
    # limpa a linha do spinner
    printf "\r\033[K"
}

# -------------------------
# Função auxiliar para executar comandos com spinner e log limpo
# Uso: run_with_spinner cmd arg1 arg2 ...
# Retorna o exit code do comando
run_with_spinner() {
    if [ $# -eq 0 ]; then
        return 0
    fi
    local tmp
    tmp=$(mktemp) || { warn "mktemp falhou"; return 1; }
    # Executa o comando e guarda saída no temporário
    "$@" >"$tmp" 2>&1 &
    local pid=$!
    spinner "$pid"
    wait "$pid"
    local rc=$?
    # Filtra sequências ANSI e backspace e anexa ao log já limpo
    perl -pe 's/\e\[[\d;]*[A-Za-z]//g; s/\x08//g' "$tmp" >> "$LOGFILE"
    rm -f "$tmp"
    return $rc
}

# -------------------------
# Sudo keepalive (pede senha uma vez)
SUDO_KEEPALIVE_PID=""
ensure_sudo() {
    if ! sudo -v >/dev/null 2>&1; then
        echo "Sudo é necessário. Você será solicitado a informar a senha."
        sudo -v || { warn "Não foi possível obter credenciais sudo"; return 1; }
    fi
    ( while true; do sudo -n true; sleep 60; done ) &
    SUDO_KEEPALIVE_PID=$!
    # garante kill no exit
    trap 'kill ${SUDO_KEEPALIVE_PID:-0} 2>/dev/null || true' EXIT
}

# -------------------------
# Garante pipx e pip-audit (instala se necessário).
# Tenta pacman (Arch) primeiro, depois pip --user.
ensure_pipx_and_pip_audit() {
    if command -v pip-audit >/dev/null 2>&1; then
        highlight_green "pip-audit já instalado."
        return 0
    fi

    info "Garantindo pipx e pip-audit (tentando instalar se necessário)..."

    # escolhe python disponível
    local pycmd="python"
    if ! command -v "$pycmd" >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
        pycmd="python3"
    fi

    # tenta instalar pipx via pacman (requer sudo)
    if command -v pacman >/dev/null 2>&1 && ! command -v pipx >/dev/null 2>&1; then
        info "Tentando instalar python-pipx via pacman..."
        run_with_spinner sudo pacman -S --needed python-pipx || warn "Instalação python-pipx via pacman falhou (continuando fallback)..."
    fi

    # fallback: instalar pipx via pip (user)
    if ! command -v pipx >/dev/null 2>&1; then
        if command -v "$pycmd" >/dev/null 2>&1; then
            info "Instalando pipx via $pycmd -m pip (modo --user)..."
            run_with_spinner "$pycmd" -m pip install --user pipx || warn "Instalação pipx via pip (user) falhou"
            # garante PATH para o usuário atual
            "$pycmd" -m pipx ensurepath 2>/dev/null || true
            export PATH="$HOME/.local/bin:$PATH"
        else
            warn "Python não encontrado para instalar pipx."
        fi
    fi

    # agora tenta instalar pip-audit via pipx
    if command -v pipx >/dev/null 2>&1; then
        if ! command -v pip-audit >/dev/null 2>&1; then
            info "Instalando pip-audit via pipx..."
            run_with_spinner pipx install pip-audit || warn "Falha ao instalar pip-audit via pipx"
        fi
    fi

    if command -v pip-audit >/dev/null 2>&1; then
        highlight_green "pip-audit disponível."
    else
        warn "pip-audit não instalado. Você pode instalar manualmente: 'sudo pacman -S python-pipx && pipx install pip-audit' ou 'python -m pip install --user pipx; python -m pipx ensurepath; pipx install pip-audit'"
    fi
}

# -------------------------
# Checagem de dependências (apenas avisa)
check_dependencies() {
    for cmd in pacman yay flatpak snap fwupdmgr python; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "$cmd não encontrado."
        fi
    done
}

# Verifica se pacman está bloqueado
check_pacman_lock() {
    if [ -f /var/lib/pacman/db.lck ]; then
        warn "Pacman lock detectado em /var/lib/pacman/db.lck. Saindo para evitar corrupção."
        exit 1
    fi
}

# -------------------------
update_pacman() {
    info "Atualizando pacotes oficiais (pacman)"
    check_pacman_lock
    run_with_spinner sudo pacman -Syu --noconfirm || warn "pacman finalizou com erro (veja log)"
    if pacman -Qu | grep . >/dev/null 2>&1; then
        highlight_green "PACOTES PACMAN ATUALIZADOS."
    else
        highlight_yellow "NADA PARA FAZER (pacman)."
    fi
}

update_yay() {
    info "Atualizando pacotes AUR (yay)"
    if command -v yay >/dev/null 2>&1; then
        run_with_spinner yay -Syu --noconfirm || warn "yay finalizou com erro (veja log)"
        if yay -Qu | grep . >/dev/null 2>&1; then
            highlight_green "PACOTES AUR ATUALIZADOS."
        else
            highlight_yellow "NADA PARA FAZER (yay)."
        fi
    else
        warn "yay não está instalado."
    fi
}

update_flatpak() {
    info "Atualizando pacotes Flatpak"
    if command -v flatpak >/dev/null 2>&1; then
        run_with_spinner flatpak update -y || warn "flatpak finalizou com erro (veja log)"
        highlight_green "FLATPAK ATUALIZADO (detalhes no log)."
    else
        warn "flatpak não está instalado."
    fi
}

update_snap() {
    info "Atualizando pacotes Snap"
    if command -v snap >/dev/null 2>&1; then
        run_with_spinner sudo snap refresh || warn "snap finalizou com erro (veja log)"
        highlight_green "SNAP ATUALIZADO (detalhes no log)."
    else
        warn "snap não está instalado."
    fi
}

update_fwupd() {
    info "Atualizando firmware (fwupd)"
    if command -v fwupdmgr >/dev/null 2>&1; then
        run_with_spinner fwupdmgr refresh || true
        run_with_spinner fwupdmgr update -y || true
        highlight_green "FIRMWARE ATUALIZADO (detalhes no log)."
    else
        warn "fwupd não está instalado."
    fi
}

# Função segura para verificar pacotes pip (não atualiza automaticamente)
verifica_update_pip() {
    info "Verificando pacotes Python (pip) — seguro (sem atualizações automáticas)"

    # Se existir um venv ativo, usa o Python dele
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        pycmd="$VIRTUAL_ENV/bin/python"
    else
        pycmd="python"
        if ! command -v "$pycmd" >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
            pycmd="python3"
        fi
    fi

    if ! command -v "$pycmd" >/dev/null 2>&1 || ! "$pycmd" -m pip --version >/dev/null 2>&1; then
        warn "pip não está instalado (no python consultado)."
        echo "Instale pip: sudo pacman -S python-pip (ou use python -m ensurepip / pip do usuário)."
        return
    fi

    echo "Usando: $($pycmd -m pip --version 2>/dev/null)"
    if [ "$(id -u)" -eq 0 ]; then
        warn "AVISO: você está rodando como root. Evite usar 'sudo pip install' — pode quebrar o sistema."
    fi
    echo "Nota: este script NÃO atualiza pacotes pip globalmente. Recomendo usar venv ou pipx."

    tmp=$(mktemp) || { warn "Erro ao criar temporário"; return 1; }

    "$pycmd" -m pip list --outdated --format=columns >"$tmp" 2>&1 &
    pid=$!
    spinner "$pid"
    wait "$pid"
    rc=$?

    outdated=$(awk 'NR>2 {print $1}' "$tmp" 2>/dev/null || true)
    if [[ -n "$outdated" ]]; then
        count=$(echo "$outdated" | wc -l)
        echo "Foram encontrados $count pacotes pip desatualizados:"
        while IFS= read -r pkg; do
            echo -e " \033[1;31m- $pkg\033[0m"
        done <<< "$outdated"
        highlight_red "Existem pacotes PIP desatualizados. Não atualize globalmente com sudo pip."
    else
        highlight_green "Nenhum pacote pip desatualizado encontrado (no ambiente consultado)."
    fi

    rm -f "$tmp"

    if command -v pip-audit >/dev/null 2>&1; then
        info "Executando pip-audit para checar vulnerabilidades..."
        run_with_spinner pip-audit || warn "pip-audit terminou com problemas (veja o log)"
    else
        echo "Dica: instale pip-audit via pipx: pipx install pip-audit"
    fi
}

# update_keys respeitando REFRESH_KEYS e KEY_REFRESH_MODE
update_keys() {
    info "Atualizando chaves GPG (pacman-key)"

    if [ "$REFRESH_KEYS" != true ]; then
        highlight_yellow "PULANDO atualização de chaves GPG (configurado para pular)."
        return
    fi

    if [ "$KEY_REFRESH_MODE" = "fast" ]; then
        info "Modo rápido: populando keyring local (sem contato com keyservers)"
        # rápido: popula a keyring com as chaves empacotadas localmente
        run_with_spinner sudo pacman-key --populate archlinux || warn "pacman-key --populate falhou (veja log)"
    else
        info "Modo completo: atualizando chaves via keyservers (pode demorar)"
        # completo: refresh que consulta keyservers (pode levar mais tempo)
        run_with_spinner sudo pacman-key --refresh-keys || warn "pacman-key --refresh-keys falhou (veja log)"
    fi

    highlight_green "CHAVES GPG processadas (detalhes no log)."
}

update_mirrors() {
    info "Atualizando lista de mirrors (reflector)"
    if command -v reflector >/dev/null 2>&1; then
        run_with_spinner sudo reflector --latest 20 --sort rate --save /etc/pacman.d/mirrorlist || true
        highlight_green "MIRRORS ATUALIZADOS (detalhes no log)."
    else
        warn "reflector não está instalado."
    fi
}

update_fonts() {
    info "Recarregando cache de fontes (fc-cache)"
    run_with_spinner fc-cache -fv || true
    highlight_green "CACHE DE FONTES RECONSTRUÍDO (detalhes no log)."
}

update_icons() {
    info "Atualizando cache de ícones (GTK)"
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        for icondir in /usr/share/icons/*; do
            if [ -d "$icondir" ]; then
                run_with_spinner gtk-update-icon-cache -f "$icondir" || true
            fi
        done
        highlight_green "CACHE DE ÍCONES ATUALIZADO (detalhes no log)."
    else
        warn "gtk-update-icon-cache não encontrado (provavelmente não necessário no KDE Plasma)."
    fi
}

remove_orphans_pacman() {
    info "Removendo pacotes órfãos (pacman)"
    mapfile -t orphans_array < <(pacman -Qdtq 2>/dev/null || true)
    if (( ${#orphans_array[@]} )); then
        echo "Pacotes órfãos encontrados:"
        printf ' - %s\n' "${orphans_array[@]}"
        if [ "$ASSUME_YES" = true ]; then
            info "Assumindo 'yes' (removendo sem perguntar)."
            run_with_spinner sudo pacman -Rns "${orphans_array[@]}" --noconfirm || true
            highlight_green "PACOTES ÓRFÃOS REMOVIDOS (pacman)."
        else
            # confirma remoção (não forçamos automaticamente)
            read -r -p "Remover esses pacotes? [y/N] " ans
            if [[ "$ans" =~ ^[Yy]$ ]]; then
                run_with_spinner sudo pacman -Rns "${orphans_array[@]}" --noconfirm || true
                highlight_green "PACOTES ÓRFÃOS REMOVIDOS (pacman)."
            else
                highlight_yellow "Remoção de órfãos cancelada pelo usuário."
            fi
        fi
    else
        highlight_yellow "Nenhum órfão encontrado (pacman)."
    fi
}

remove_orphans_yay() {
    info "Removendo pacotes órfãos (AUR)"
    if command -v yay >/dev/null 2>&1; then
        if [ "$ASSUME_YES" = true ]; then
            run_with_spinner yay -Yc --noconfirm || true
        else
            run_with_spinner yay -Yc || true
        fi
        highlight_green "PACOTES ÓRFÃOS REMOVIDOS (yay)."
    else
        highlight_yellow "Nenhum órfão encontrado (yay)."
    fi
}

verifica_pacman_integridade() {
    info "Verificando integridade dos pacotes (pacman -Qk)"
    run_with_spinner sudo pacman -Qk || true
    if sudo pacman -Qk 2>/dev/null | grep -q "arquivos faltando"; then
        highlight_red "Problemas de integridade detectados (detalhes no log)."
        echo "Sugestão: reinstale os pacotes afetados com 'sudo pacman -S <pacote>'."
    else
        highlight_green "Integridade dos pacotes OK."
    fi
}

verifica_pacman_dependencias() {
    info "Verificando dependências dos pacotes (pacman -Dk)"
    run_with_spinner sudo pacman -Dk || true
    if sudo pacman -Dk 2>/dev/null | grep -q "dependências faltando"; then
        highlight_red "Dependências quebradas detectadas (detalhes no log)."
        echo "Sugestão: instale os pacotes faltantes ou remova os pacotes que dependem deles."
    else
        highlight_green "Dependências dos pacotes OK."
    fi
}

finish() {
    END=$(date +%s)
    DURATION=$((END - START))
    success "✅ Sistema atualizado com sucesso em $DURATION segundos."
    echo "------------------------------------------------------------"
    check_kernel linux
    check_kernel linux-lts
    echo "Créditos: Script criado por $AUTHOR"
    echo "Log salvo em: $LOGFILE"
}

check_kernel() {
    local pkg=$1

    # se o pacote não estiver instalado, sai
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
        return
    fi

    local installed_full running_full installed_num running_num
    installed_full=$(pacman -Q "$pkg" | awk '{print $2}')
    running_full=$(uname -r)

    installed_num=$(echo "$installed_full" | grep -oE '^[0-9]+(\.[0-9]+)*' || echo "$installed_full")
    running_num=$(echo "$running_full" | grep -oE '^[0-9]+(\.[0-9]+)*' || echo "$running_full")

    echo "Kernel instalado ($pkg): $installed_full"
    echo "Kernel em uso:           $running_full"

    # calcula epoch do boot atual
    local uptime_seconds boot_epoch
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)
    boot_epoch=$(( $(date +%s) - uptime_seconds ))

    # tenta obter mtime do diretório de módulos correspondente à versão instalada
    local moddir mod_mtime
    moddir="/lib/modules/$installed_full"
    if [ -d "$moddir" ]; then
        mod_mtime=$(stat -c %Y "$moddir" 2>/dev/null || echo 0)
    else
        # fallback: procura por diretórios que comecem com a parte numérica
        mod_mtime=0
        if ls /lib/modules 2>/dev/null | grep -q "^${installed_num}"; then
            moddir="$(ls /lib/modules | grep "^${installed_num}" | head -n1)"
            mod_mtime=$(stat -c %Y "/lib/modules/$moddir" 2>/dev/null || echo 0)
        fi
    fi

    # se versões numéricas são iguais provavelmente não precisa reiniciar
    if [[ "$installed_num" == "$running_num" ]]; then
        highlight_green "Kernel ($pkg) já está na versão em uso."
    else
        # se módulos foram instalados após o boot, precisamos reiniciar
        if (( mod_mtime > boot_epoch )); then
            highlight_yellow "⚠️ O kernel ($pkg) foi atualizado (módulos instalados após o boot). Reinicie o sistema para usar o novo kernel."
        else
            # módulos existem mas não foram instalados desde o boot -> pode ser apenas kernel alternativo instalado anteriormente
            highlight_yellow "⚠️ O kernel ($pkg) instalado difere do kernel em uso. Reinicie se quiser usar o kernel instalado."
        fi
    fi

    echo "------------------------------------------------------------"
}

# -------------------------
# Menu interativo para escolher ações
show_menu() {
    while true; do
        echo
        echo "=================== Menu de Atualização ==================="
        echo " 1) Atualizar tudo (pacman, AUR, flatpak, snap, fwupd, pip, chaves, mirrors, fontes, ícones)"
        echo " 2) pacman - atualizar pacotes oficiais"
        echo " 3) yay   - atualizar AUR (se instalado)"
        echo " 4) flatpak - atualizar Flatpak"
        echo " 5) snap - atualizar Snap"
        echo " 6) fwupd - atualizar firmware"
        echo " 7) Verificar pacotes Python (pip) - seguro"
        echo " 8) Instalar/garantir pipx + pip-audit"
        echo " 9) Atualizar chaves GPG (pacman-key) (REFRESH_KEYS=$REFRESH_KEYS, mode=$KEY_REFRESH_MODE)"
        echo "10) Atualizar mirrors (reflector)"
        echo "11) Recarregar cache de fontes"
        echo "12) Atualizar cache de ícones"
        echo "13) Remover órfãos (pacman)"
        echo "14) Remover órfãos (yay)"
        echo "15) Verificar integridade (pacman -Qk)"
        echo "16) Verificar dependências (pacman -Dk)"
        echo "17) Ver resumo do kernel (checa linux + linux-lts)"
        echo "18) Ver últimas linhas do log (tail -n 200)"
        echo "19) Alternar atualização de chaves GPG ON/OFF (atualmente: $REFRESH_KEYS)"
        echo "20) Alterar modo de atualização de chaves (fast/full) (atualmente: $KEY_REFRESH_MODE)"
        echo "Q) Sair"
        echo "==========================================================="
        read -r -p "Escolha uma opção: " opt
        opt=${opt,,} # lower-case

        case "$opt" in
            1|a)
                info "Executando atualização completa..."
                ensure_sudo || true
                update_pacman
                update_yay
                update_flatpak
                update_snap
                update_fwupd
                verifica_update_pip
                update_keys
                update_mirrors
                update_fonts
                update_icons
                remove_orphans_pacman
                remove_orphans_yay
                verifica_pacman_integridade
                verifica_pacman_dependencias
                finish
                ;;
            2)
                ensure_sudo || true
                update_pacman
                ;;
            3)
                update_yay
                ;;
            4)
                update_flatpak
                ;;
            5)
                update_snap
                ;;
            6)
                update_fwupd
                ;;
            7)
                ensure_pipx_and_pip_audit || true
                verifica_update_pip
                ;;
            8)
                ensure_pipx_and_pip_audit || true
                ;;
            9)
                ensure_sudo || true
                update_keys
                ;;
            10)
                ensure_sudo || true
                update_mirrors
                ;;
            11)
                update_fonts
                ;;
            12)
                update_icons
                ;;
            13)
                remove_orphans_pacman
                ;;
            14)
                remove_orphans_yay
                ;;
            15)
                verifica_pacman_integridade
                ;;
            16)
                verifica_pacman_dependencias
                ;;
            17)
                check_kernel linux
                check_kernel linux-lts
                ;;
            18)
                if [ -f "$LOGFILE" ]; then
                    echo "Últimas 200 linhas do log: $LOGFILE"
                    echo "------------------------------------------------------------"
                    tail -n 200 "$LOGFILE" || true
                else
                    warn "Log não encontrado: $LOGFILE"
                fi
                ;;
            19)
                # alterna REFRESH_KEYS
                if [ "$REFRESH_KEYS" = true ]; then
                    REFRESH_KEYS=false
                else
                    REFRESH_KEYS=true
                fi
                highlight_yellow "Atualização de chaves GPG agora: $REFRESH_KEYS"
                ;;
            20)
                # altera KEY_REFRESH_MODE
                echo "Modo atual: $KEY_REFRESH_MODE"
                read -r -p "Escolha modo (fast/full): " mode
                case "${mode,,}" in
                    fast) KEY_REFRESH_MODE="fast"; highlight_yellow "Modo GPG: fast (popula localmente)";;
                    full) KEY_REFRESH_MODE="full"; highlight_yellow "Modo GPG: full (refresh keyservers)";;
                    *) echo "Modo inválido. Mantendo: $KEY_REFRESH_MODE";;
                esac
                ;;
            q|quit|sair|exit)
                echo "Saindo..."
                return 0
                ;;
            *)
                echo "Opção inválida: $opt"
                ;;
        esac

        echo
        read -r -p "Pressione Enter para voltar ao menu..." _dummy
    done
}

# -------------------------
# Fluxo principal (modo automático)
main_auto() {
    check_dependencies
    ensure_sudo || true
    ensure_pipx_and_pip_audit || true
    update_pacman
    update_yay
    update_flatpak
    update_snap
    update_fwupd
    verifica_update_pip
    update_keys
    update_mirrors
    update_fonts
    update_icons
    remove_orphans_pacman
    remove_orphans_yay
    verifica_pacman_integridade
    verifica_pacman_dependencias
    finish
}

# -------------------------
# Parse simples de opções de CLI (antes de executar)
# Pode chamar com: -a|--auto, -y|--yes, -h|--help
while [ $# -gt 0 ]; do
    case "$1" in
        -a|--auto)
            AUTO=true
            shift
            ;;
        -y|--yes)
            ASSUME_YES=true
            shift
            ;;
        -h|--help)
            cat <<EOF
Uso: $0 [opções]
  -a, --auto    Executa atualização completa sem menu (modo não interativo)
  -y, --yes     Assume 'yes' para confirmações (remoção de órfãos)
  -h, --help    Mostra esta ajuda
Exemplos:
  $0           # mostra menu interativo
  $0 -a        # executa tudo automaticamente
  $0 -a -y     # automático e assume yes para remoções
EOF
            exit 0
            ;;
        *)
            echo "Opção desconhecida: $1"
            exit 1
            ;;
    esac
done

# Inicia: menu ou modo automático conforme flag
if [ "$AUTO" = true ]; then
    main_auto
else
    check_dependencies
    # não forçamos ensure_sudo aqui — menu chamará ensure_sudo quando necessário
    show_menu
fi
