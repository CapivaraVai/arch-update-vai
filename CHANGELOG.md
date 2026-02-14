<<<<<<< HEAD
=======
cat > CHANGELOG.md << 'EOF'
>>>>>>> d616691 (docs: update README and add changelog for v0.6.0)
# 📜 Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

<<<<<<< HEAD
O formato segue o padrão:
https://keepachangelog.com/pt-BR/1.0.0/

O projeto utiliza versionamento semântico:
=======
O formato segue o padrão Keep a Changelog:
https://keepachangelog.com/pt-BR/1.0.0/

O projeto utiliza versionamento semântico (SemVer):
>>>>>>> d616691 (docs: update README and add changelog for v0.6.0)
https://semver.org/lang/pt-BR/

---

## [0.6.0] - 2026-02-13

### ✨ Adicionado
<<<<<<< HEAD
- Relatório final com sucessos/avisos/falhas + tempo + log
- Exibição de até 5 notificações no relatório
- Contagem de atualizações por backend (pacman/yay/flatpak/snap/fwupd)
- Detecção inteligente de reinício com motivos

### 🛠 Corrigido
- Correção de falso positivo na detecção de reinício (formato do kernel)
=======
- Relatório final com sucessos/avisos/falhas, tempo total e caminho do log.
- Exibição de até 5 notificações (warnings/erros) no final do relatório.
- Contagem de atualizações por comando (pacman/yay/flatpak/snap/fwupd).
- Contagem de pacotes Python desatualizados (pip list --outdated).
- Detecção inteligente de reinício recomendado, com motivo.

### 🛠 Corrigido
- Correção de falso positivo na detecção de reinício (normalização de versão do kernel).
- Estabilidade do menu e leitura de entrada via /dev/tty.
>>>>>>> d616691 (docs: update README and add changelog for v0.6.0)

---

## [0.5.0] - 2026-02-13

### 🎉 Inicial
<<<<<<< HEAD
- Script base de atualização Arch Linux.
- Atualização de pacman, AUR, Flatpak, Snap e fwupd.
- Remoção de órfãos.
- Verificação de kernel.
=======
- Script base para atualizar Arch Linux (pacman, AUR, Flatpak, Snap, fwupd).
- Remoção de pacotes órfãos (pacman e yay).
- Verificações de integridade e dependências (pacman -Qk / -Dk).
EOF
>>>>>>> d616691 (docs: update README and add changelog for v0.6.0)
