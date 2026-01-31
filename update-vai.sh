#!/bin/bash
# ============================================================
# update.sh - Script de atualização para Arch Linux
# Autor: Diego Ernani (CapivaraVai)
# Versão: 0.0.5 - A
# Última atualização: 30/01/2026
# ============================================================
# Licença: GNU General Public License v3.0
# Você pode redistribuir e/ou modificar este programa sob os
# termos da GPL conforme publicada pela Free Software Foundation,
# versão 3 ou superior.
#
# Este programa é distribuído na esperança de que seja útil,
# mas SEM NENHUMA GARANTIA; sem mesmo a garantia implícita de
# COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM PROPÓSITO ESPECÍFICO.
# Veja a GNU General Public License para mais detalhes. # ============================================================

set -euo pipefail

VERSION="0.0.5 - A"
AUTHOR="Diego Ernani (CapivaraVai)"
LOGFILE="$HOME/update.log"
START=$(date +%s)

# Funções de mensagem
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
warn()    { echo -e "\033[1;33m[WARNING]\033[0m $1"; }

highlight_green()  { echo -e "\033[1;32m$1\033[0m"; }
highlight_yellow() { echo -e "\033[1;33m$1\033[0m"; }
highlight_blue()   { echo -e "\033[1;34m$1\033[0m"; }

echo -e "\033[1;36m=== Atualizador Arch Linux ===\033[0m"
echo "Autor: $AUTHOR | Versão: $VERSION"
echo "Data: $(date '+%d/%m/%Y %H:%M:%S')"
echo "------------------------------------------------------------"

exec > >(tee -a "$LOGFILE") 2>&1

# Funções principais
update_pacman() {
    info "Atualizando pacotes oficiais (pacman)"
    output=$(sudo pacman -Syu --noconfirm)
    if echo "$output" | grep -qi "nada para fazer"; then
        highlight_yellow "NADA PARA FAZER."
    else
        highlight_green "ATUALIZADO."
    fi
}

update_yay() {
    info "Atualizando pacotes AUR (yay)"
    if command -v yay >/dev/null 2>&1; then
        output=$(yay -Syu --noconfirm)
        if echo "$output" | grep -qi "não há nada a ser feito"; then
            highlight_yellow "NADA PARA FAZER."
        else
            highlight_green "ATUALIZADO."
        fi
    else
        warn "yay não está instalado. Pulei atualização de AUR."
    fi
}

update_flatpak() {
    info "Atualizando pacotes Flatpak"
    if command -v flatpak >/dev/null 2>&1; then
        output=$(flatpak update -y)
        if echo "$output" | grep -qi "Nada para fazer"; then
            highlight_yellow "NADA PARA FAZER."
        else
            highlight_green "ATUALIZADO."
        fi
    else
        warn "flatpak não está instalado. Pulei atualização de Flatpak."
    fi
}

update_snap() {
    info "Atualizando pacotes Snap"
    if command -v snap >/dev/null 2>&1; then
        sudo snap refresh
        highlight_green "SNAP ATUALIZADO."
    else
        warn "snap não está instalado. Pulei atualização de Snap."
    fi
}

update_fwupd() {
    info "Atualizando firmware (fwupd)"
    if command -v fwupdmgr >/dev/null 2>&1; then
        fwupdmgr refresh
        fwupdmgr update -y
        highlight_green "FIRMWARE ATUALIZADO."
    else
        warn "fwupd não está instalado. Pulei atualização de firmware."
    fi
}

remove_orphans_pacman() {
    info "Removendo pacotes órfãos (pacman)"
    orphans=$(pacman -Qdtq || true)
    if [[ -n "$orphans" ]]; then
        sudo pacman -Rns $orphans --noconfirm
        highlight_green "PACOTES ÓRFÃOS REMOVIDOS."
    else
        highlight_yellow "NENHUM ÓRFÃO ENCONTRADO."
    fi
}

remove_orphans_yay() {
    info "Removendo pacotes órfãos (AUR)"
    if command -v yay >/dev/null 2>&1; then
        yay -Yc --noconfirm
        highlight_green "PACOTES ÓRFÃOS REMOVIDOS."
    else
        highlight_yellow "NENHUM ÓRFÃO ENCONTRADO."
    fi
}

# Execução
update_pacman
update_yay
update_flatpak
update_snap
update_fwupd
remove_orphans_pacman
remove_orphans_yay

# Finalização
END=$(date +%s)
DURATION=$((END - START))
success "✅ Sistema atualizado com sucesso em $DURATION segundos."
echo "------------------------------------------------------------"

# Verificação de kernel
check_kernel() {
    local pkg=$1
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        INSTALLED=$(pacman -Q "$pkg" | awk '{print $2}')
        RUNNING=$(uname -r)
        echo "Kernel instalado ($pkg): $INSTALLED"
        echo "Kernel em uso:           $RUNNING"
        if [[ "$INSTALLED" != "$RUNNING" ]]; then
            highlight_yellow "⚠️ O kernel ($pkg) foi atualizado. Reinicie o sistema para aplicar a nova versão."
        else
            highlight_green "Kernel ($pkg) já está na versão mais recente em uso."
        fi
        echo "------------------------------------------------------------"
    fi
}

check_kernel linux
check_kernel linux-lts

echo "Créditos: Script criado por $AUTHOR"
echo "Log salvo em: $LOGFILE"
