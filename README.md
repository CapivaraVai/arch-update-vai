# 🐧 Arch Update Script Vai

Script automatizado para atualização completa do Arch Linux e derivados.

Ele gerencia atualizações de:

- Pacotes oficiais (pacman)
- AUR (yay)
- Flatpak
- Snap
- Firmware (fwupd)
- Pacotes Python (pip)
- Chaves GPG
- Mirrors (reflector)

Além disso, gera um relatório detalhado com:

- Total de sucessos, avisos e falhas
- Contagem de atualizações por comando
- Detecção inteligente de necessidade de reinício
- Registro completo em log

---

## 🚀 Recursos

- 🔄 Atualização completa do sistema
- 📦 Atualização separada por backend
- 🧹 Remoção de pacotes órfãos (pacman e yay)
- 🔐 Atualização de chaves GPG (modo fast/full)
- 🌍 Atualização automática de mirrors (reflector)
- 🔍 Verificação de integridade (pacman -Qk)
- 🔗 Verificação de dependências (pacman -Dk)
- 🖥 Detecção inteligente de reinício necessário
- 📊 Relatório final detalhado
- 📄 Histórico de logs automático

---

## 📊 Exemplo de saída

📊 RELATÓRIO
✅ Sucessos : 18
⚠ Atenções : 3
❌ Falhas : 0
⏱ Tempo total: 27s
📄 Log: ~/arch-update-script-vai/logs/update-vai-20260213-224515.log

📦 Atualizações por comando:
pacman : 0
yay : 0
flatpak: 0
snap : 0
fwupd : 14
pip (outdated detectados): 13
==============================================================

📌 Notificações:
⚠ Atualização de chaves GPG desativada.
⚠ snap não está instalado.
⚠ fwupd: get-updates retornou status não-zero (informativo).

✅ Reinício: não parece necessário (heurística).
⚠ Concluído com avisos.



---

## 📦 Requisitos

- Arch Linux ou derivado
- pacman (já incluso)
- yay (opcional, para AUR)
- flatpak (opcional)
- snapd (opcional)
- fwupd (opcional)
- reflector (opcional)

---

## ⚙️ Instalação

```bash
git clone https://github.com/seu-usuario/arch-update-script-vai.git
cd arch-update-script-vai
chmod +x update-vai.sh
./update-vai.sh

🧠 Detecção de Reinício

O script recomenda reinício quando detecta atualização de:
- Kernel (linux / linux-lts)
- Microcode (amd-ucode / intel-ucode)
- systemd
- glibc
- linux-firmware
- Ele também compara o kernel em uso (uname -r) com o instalado para evitar falsos positivos.

Este projeto é licenciado sob a GNU General Public License v3.0 (GPLv3).
