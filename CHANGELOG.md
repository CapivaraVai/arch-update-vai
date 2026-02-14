cat > CHANGELOG.md << 'EOF'
# 📜 Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue o padrão Keep a Changelog:
https://keepachangelog.com/pt-BR/1.0.0/

O projeto utiliza versionamento semântico (SemVer):
https://semver.org/lang/pt-BR/

---

## [0.6.0] - 2026-02-13

### ✨ Adicionado
- Relatório final com sucessos/avisos/falhas, tempo total e caminho do log.
- Exibição de até 5 notificações (warnings/erros) no final do relatório.
- Contagem de atualizações por comando (pacman/yay/flatpak/snap/fwupd).
- Contagem de pacotes Python desatualizados (pip list --outdated).
- Detecção inteligente de reinício recomendado, com motivo.

### 🛠 Corrigido
- Correção de falso positivo na detecção de reinício (normalização de versão do kernel).
- Estabilidade do menu e leitura de entrada via /dev/tty.

---

## [0.5.0] - 2026-02-13

### 🎉 Inicial
- Script base para atualizar Arch Linux (pacman, AUR, Flatpak, Snap, fwupd).
- Remoção de pacotes órfãos (pacman e yay).
- Verificações de integridade e dependências (pacman -Qk / -Dk).
EOF
