# 📜 Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue o padrão:
https://keepachangelog.com/pt-BR/1.0.0/

O projeto utiliza versionamento semântico:
https://semver.org/lang/pt-BR/

---

## [0.6.0] - 2026-02-13

### ✨ Adicionado
- Relatório final com sucessos/avisos/falhas + tempo + log
- Exibição de até 5 notificações no relatório
- Contagem de atualizações por backend (pacman/yay/flatpak/snap/fwupd)
- Detecção inteligente de reinício com motivos

### 🛠 Corrigido
- Correção de falso positivo na detecção de reinício (formato do kernel)

---

## [0.5.0] - 2026-02-13

### 🎉 Inicial
- Script base de atualização Arch Linux.
- Atualização de pacman, AUR, Flatpak, Snap e fwupd.
- Remoção de órfãos.
- Verificação de kernel.
