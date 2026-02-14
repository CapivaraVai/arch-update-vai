# 📜 Changelog

Todas as mudanças relevantes deste projeto serão documentadas aqui.

O formato segue o padrão:
https://keepachangelog.com/pt-BR/1.0.0/

O projeto utiliza versionamento semântico:
https://semver.org/lang/pt-BR/

---

## [0.5.6] - 2026-02-13

### 🛠 Corrigido
- Correção de falso positivo na detecção de reinício (normalização de versão do kernel).
- Comparação correta entre kernel em uso e kernel instalado.
- Ignora linux-lts se não estiver em uso.

### ✨ Adicionado
- Contagem de atualizações separada por backend (pacman, yay, flatpak, snap, fwupd).
- Detecção inteligente de necessidade de reinício.
- Exibição de motivos detalhados para reinício.
- Exibição de notificações (até 5) no relatório final.

---

## [0.5.5] - 2026-02-13

### ✨ Adicionado
- Bloco “Atualizações por comando” no relatório.
- Contagem de pacotes Python desatualizados (pip).
- Heurística inicial para recomendação de reinício.

---

## [0.5.4] - 2026-02-13

### ✨ Adicionado
- Exibição das mensagens de atenção e erro no final do relatório (até 5).
- Armazenamento interno de notificações.

---

## [0.5.3] - 2026-02-13

### ✨ Adicionado
- Menu completo com todas as funções.
- Melhorias de estabilidade no menu (não sair para o prompt).
- Remoção de problemas com leitura de input (tty).

---

## [0.5.2] - 2026-02-13

### 🛠 Corrigido
- Correção de encerramento inesperado do script.
- Ajuste de manipulação de log.
- Melhor tratamento de erro com set -euo pipefail.

---

## [0.5.1] - 2026-02-13

### ✨ Adicionado
- Sistema de relatório final com:
  - Sucessos
  - Atenções
  - Falhas
  - Tempo total
- Sistema de logs automático.

---

## [0.5.0] - 2026-02-13

### 🎉 Inicial
- Script base de atualização Arch Linux.
- Atualização de pacman, AUR, Flatpak, Snap e fwupd.
- Remoção de órfãos.
- Verificação de kernel.
