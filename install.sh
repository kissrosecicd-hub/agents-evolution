#!/usr/bin/env bash
# AGENTS.md Installer — Linux/macOS
# Устанавливает AGENTS.md, скиллы и структуру заметок

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     AGENTS.md Installer v1.0             ║${NC}"
echo -e "${CYAN}║     Linux/macOS                          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Определяем домашнюю директорию
HOME_DIR="$HOME"

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}📂 Установка из:${NC} $SCRIPT_DIR"
echo -e "${YELLOW}🏠 Домашняя директория:${NC} $HOME_DIR"
echo ""

# Проверка существования AGENTS.md
if [ ! -f "$SCRIPT_DIR/AGENTS.md" ]; then
    echo -e "${RED}❌ AGENTS.md не найден в $SCRIPT_DIR${NC}"
    echo -e "${RED}   Запустите скрипт из директории репозитория${NC}"
    exit 1
fi

echo -e "${GREEN}🚀 Начало установки...${NC}"
echo ""

# 1. Копируем AGENTS.md
echo -e "${YELLOW}📄 Копирую AGENTS.md → $HOME_DIR/${NC}"
cp "$SCRIPT_DIR/AGENTS.md" "$HOME_DIR/AGENTS.md"
echo -e "${GREEN}   ✅ AGENTS.md установлен${NC}"

# 2. Создаём .agents/skills/ и .myskills/skills/
echo -e "${YELLOW}📁 Создаю ~/.agents/skills/${NC}"
mkdir -p "$HOME_DIR/.agents/skills"
echo -e "${YELLOW}📁 Создаю ~/.myskills/skills/${NC}"
mkdir -p "$HOME_DIR/.myskills/skills"

# 3. Копируем скиллы
if [ -d "$SCRIPT_DIR/skills" ]; then
    echo -e "${YELLOW}🧩 Копирую скиллы...${NC}"
    for skill_dir in "$SCRIPT_DIR"/skills/*/; do
        skill_name=$(basename "$skill_dir")
        # Пропускаем .template
        if [ "$skill_name" = ".template" ]; then
            continue
        fi
        if [ -d "$skill_dir" ]; then
            cp -r "$skill_dir" "$HOME_DIR/.agents/skills/$skill_name"
            echo -e "${GREEN}   ✅ $skill_name${NC}"
        fi
    done
fi

# 4. Создаём .notes/INBOX/
echo -e "${YELLOW}📝 Создаю ~/.notes/INBOX/${NC}"
mkdir -p "$HOME_DIR/.notes/INBOX"
echo -e "${GREEN}   ✅ .notes/INBOX создана${NC}"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          ✅ Установка завершена!         ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Установлено:${NC}"
echo -e "  📄 AGENTS.md  → $HOME_DIR/AGENTS.md"
echo -e "  🧩 Скиллы     → $HOME_DIR/.agents/skills/"
echo -e "  🔧 User Skills → $HOME_DIR/.myskills/skills/"
echo -e "  📝 Заметки    → $HOME_DIR/.notes/INBOX/"
echo ""
echo -e "${YELLOW}Следующие шаги:${NC}"
echo -e "  1. Откройте ваш AI-агент (Qwen, Claude, Cursor...)"
echo -e "  2. Начните новый чат — агент подхватит AGENTS.md"
echo -e "  3. Или скажите: «следуй AGENTS.md»"
echo ""
echo -e "${CYAN}📖 Документация: https://github.com/kissrosecicd-hub/agents-evolution${NC}"
echo -e "${CYAN}💬 Автор: https://t.me/smartcaveman1${NC}"
