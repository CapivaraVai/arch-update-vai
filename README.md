# arch-update-script-vai
Script para atualização completa do Arch Linux (pacman, AUR, Flatpak, Snap, fwupd).

*** Arch Update Script Vai ***
Um script automatizado para atualizar sistemas Arch Linux e derivados.
Ele cobre pacotes oficiais, AUR, Flatpak, Snap e atualizações de firmware, além de remover pacotes órfãos e verificar se o kernel foi atualizado.

*** Recursos ***
- Atualiza pacotes oficiais com pacman
- Atualiza pacotes do AUR com yay
- Atualiza pacotes Flatpak
- Atualiza pacotes Snap
- Atualiza firmware com fwupd
- Remove pacotes órfãos (pacman e AUR)
- Verifica se o kernel foi atualizado e alerta para reinício




*** Exemplo de saída ***

=== Atualizador Arch Linux === 
Autor: Diego Ernani (CapivaraVai) | Versão: 2.1.0
Data: 30/01/2026 22:30:00
------------------------------------------------------------
[INFO] Atualizando pacotes oficiais (pacman)
ATUALIZADO.
[INFO] Atualizando pacotes AUR (yay)
NADA PARA FAZER.
...
Kernel instalado: 6.7.3.arch1-1
Kernel em uso:    6.7.2.arch1-1
⚠️ O kernel foi atualizado. Reinicie o sistema para aplicar a nova versão.
------------------------------------------------------------
✅ Sistema atualizado com sucesso em 45 segundos.


*** Requisitos ***
- Arch Linux ou derivado
- pacman (já incluso)
- yay (opcional, para AUR)
- flatpak (opcional)
- snapd (opcional)
- fwupd (opcional)

📜 Licença
Este projeto é licenciado sob a GNU General Public License v3.0 (GPLv3).
