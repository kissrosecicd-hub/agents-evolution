---
name: github-repo-prepare
description: "Подготовить проект к публикации на GitHub: .gitignore, аудит безопасности, README.md, LICENSE, .env.example, скриншоты, проверка имени."
triggers: "подготовь к публикации", "подготовь к гитхаб", "github prepare", "подготовить репозиторий", "подготовка к публикации", "сделай README для гитхаб", "скриншоты для README", "подготовь репо", "github prep"
---

# GitHub Repository Preparation

## КРИТИЧНО: Проверка имени проекта

```bash
PROJECT_NAME=$(basename "$PWD")
```

| Имя | Можно на GitHub? |
|-----|------------------|
| `my-project` | ✅ Да |
| `my-project-private` | ❌ **НЕТ** |
| `*-private` | ❌ **НЕТ** |

**Правило:** если директория проекта заканчивается на `-private` — **КАТЕГОРИЧЕСКИ НЕЛЬЗЯ** на GitHub. Это личное. Скажи пользователю:

> ⚠️ Проект `*-private` — личное использование, не для GitHub.

## Пошаговый план

### 1. Проверка и создание .gitignore

**Убедись что .gitignore покрывает:**

```gitignore
# Dependencies
node_modules/

# Build output
.next/
out/
dist/

# Environment variables (НЕ коммитить!)
.env
.env.local
.env.*.local

# TypeScript
*.tsbuildinfo

# Testing
test-results/
playwright-report/
playwright/.cache/
blob-report/
coverage/

# Runtime data
data/*.sqlite
data/*.db
data/*.db-wal
data/*.db-shm
data/*.json
data/*.csv

# Logs
*.log
npm-debug.log*

# IDE
.vscode/*
!.vscode/extensions.json
!.vscode/settings.json
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Local skills/notes
.skills/
.mynotes/
```

**Добавь специфичное** по стеку проекта (Python → `__pycache__/`, Go → `bin/`, и т.д.).

### 2. Запуск audit-gitignore.sh

Если есть `scripts/audit-gitignore.sh` — запусти:

```bash
bash scripts/audit-gitignore.sh
```

Если нет — предложи создать (см. ниже).

Скрипт проверяет:
- Какие файлы реально игнорируются
- Опасные файлы которые МОГУТ попасть в коммит
- Скан на секреты в коде (API keys, passwords, private keys)
- Рекомендации по .gitignore

### 3. Создание .env.example

Скопируй `.env` → `.env.example`, **удали все значения**:

```bash
# Пример .env.example:
PORT=
BROWSER=
DATABASE_URL=
API_KEY=
```

НЕ копируй реальные секреты!

### 4. README.md

Структура:

```markdown
# Project Name

Короткое описание — что делает проект.

![Screenshot](screenshots/light-theme.png)
![Dark mode](screenshots/dark-theme.png)

## Фичи

- Фича 1
- Фича 2

## Установка

\`\`\`bash
git clone <url>
cd project
npm install
cp .env.example .env
npm run dev
\`\`\`

## Технологии

- Tech 1
- Tech 2

## Лицензия

[MIT](LICENSE)
```

### 5. Скриншоты

Для веб-приложений — сделай скриншоты через Playwright:

```ts
// tests/screenshots.spec.ts
import { test } from '@playwright/test';

test('screenshot', async ({ page }) => {
  await page.goto('http://localhost:3000');
  await page.waitForLoadState('networkidle');
  await page.screenshot({ path: 'screenshots/light.png', fullPage: true });
});
```

```bash
mkdir -p screenshots
npx playwright test tests/screenshots.spec.ts
```

**CLI-проектам** скриншоты не нужны — достаточно ASCII-демо или gif.

### 6. LICENSE

По умолчанию — MIT:

```
MIT License

Copyright (c) <year> <author>

Permission is hereby granted...
```

### 7. package.json "private"

Для публикации:

```json
{
  "private": false
}
```

Для библиотек — убери `"private"` или поставь `false`.
Для приложений — можно оставить `true`, но тогда это не npm-пакет.

### 8. git init + первый коммит

```bash
git init
git branch -m main
git add -A
git commit -m "feat: initial release

<описание проекта>"
git remote add origin https://github.com/<owner>/<repo>.git
git push -u origin main
```

**ПЕРЕД push:** убедись что репозиторий создан на GitHub.

## audit-gitignore.sh — Шаблон скрипта

Создай `scripts/audit-gitignore.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

cd "$(dirname "$0")/.."
HAS_GIT=false
[[ -d .git ]] && HAS_GIT=true

echo -e "${CYAN}=== Gitignore Audit ===${NC}"
echo "Project: $PWD"
$HAS_GIT && echo -e "Git repo: ${GREEN}да${NC}" || echo -e "Git repo: ${YELLOW}нет (фоллбэк)${NC}"
echo

if [[ ! -f .gitignore ]]; then
  echo -e "${RED}✗ .gitignore НЕ НАЙДЕН${NC}"
  exit 1
fi
echo -e "${GREEN}✓ .gitignore найден${NC}"

# Хелпер: проверяет что файл игнорируется
is_ignored() {
  local file="$1"
  if $HAS_GIT; then
    git check-ignore -q "$file" 2>/dev/null
  else
    local basename
    basename=$(basename "$file")
    local dir
    dir=$(dirname "$file" | sed 's|^\./||')
    grep -qF "$basename" .gitignore 2>/dev/null && return 0
    grep -qF "${dir}/" .gitignore 2>/dev/null && return 0
    local ext="${basename##*.}"
    [[ "$ext" != "$basename" ]] && grep -q "*.${ext}" .gitignore 2>/dev/null && return 0
    [[ "$dir" == data/* ]] && grep -q "data/\*" .gitignore 2>/dev/null && return 0
    return 1
  fi
}

# Проверка игнорируемых файлов
echo -e "\n${CYAN}─── Игнорируемые файлы ───${NC}"
IGNORED_COUNT=0
NOT_IGNORED=()

while IFS= read -r -d '' file; do
  if is_ignored "$file"; then
    echo -e "${GREEN}  ✓ ${file}${NC}"
    ((IGNORED_COUNT++)) || true
  else
    echo -e "${RED}  ✗ ${file} (НЕ игнорируется!)${NC}"
    NOT_IGNORED+=("$file")
  fi
done < <(find . -maxdepth 3 \
  \( -path "./node_modules" -o -path "./.next" -o -path "./test-results" \
  -o -path "./.temp" -o -name "*.tsbuildinfo" -o -name ".env" \
  -o -name "*.db" -o -name "*.sqlite" -o -name "*.json" -path "*/data/*" \) \
  -print0 2>/dev/null)

echo -e "Итого: ${IGNORED_COUNT} файлов"

# Скан на секреты
echo -e "\n${CYAN}─── Скан на секреты ───${NC}"
SECRETS_FOUND=0
SECRET_PATTERNS=(
  "password\s*=\s*['\"][^'\"]+['\"]"
  "api_key\s*=\s*['\"][^'\"]+['\"]"
  "secret\s*=\s*['\"][^'\"]+['\"]"
  "token\s*=\s*['\"][^'\"]+['\"]"
  "PRIVATE KEY"
  "BEGIN RSA"
  "aws_secret_access_key"
  "sk-[a-zA-Z0-9]{20,}"
)

while IFS= read -r -d '' file; do
  [[ "$file" == *node_modules* ]] && continue
  [[ "$file" == *.next* ]] && continue
  [[ "$file" == *.git* ]] && continue
  [[ "$file" == *package-lock.json ]] && continue
  [[ "$file" == *.env ]] && continue

  for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -Pq "$pattern" "$file" 2>/dev/null; then
      match=$(grep -Pn "$pattern" "$file" 2>/dev/null | head -1)
      echo -e "${RED}  ✗ ${file}: ${match}${NC}"
      ((SECRETS_FOUND++)) || true
    fi
  done
done < <(find . -maxdepth 3 -type f \( -name "*.js" -o -name "*.ts" -o -name "*.tsx" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" -print0 2>/dev/null)

[[ $SECRETS_FOUND -eq 0 ]] && echo -e "${GREEN}  ✓ Секреты не найдены${NC}" || echo -e "${RED}  Найдено ${SECRETS_FOUND} утечек${NC}"

# Итого
echo -e "\n${CYAN}=== Итого ===${NC}"
echo "Игнорируется: ${IGNORED_COUNT}"
echo "НЕ игнорируется: ${#NOT_IGNORED[@]}"
echo "Утечек секретов: ${SECRETS_FOUND}"

if [[ ${#NOT_IGNORED[@]} -gt 0 ]] || [[ $SECRETS_FOUND -gt 0 ]]; then
  echo -e "\n${RED}⚠ ТРЕБУЕТСЯ ДЕЙСТВИЕ${NC}"
  exit 1
else
  echo -e "\n${GREEN}✓ Всё в порядке${NC}"
  exit 0
fi
```

## Быстрый чеклист

| Шаг | Команда | Зачем |
|-----|---------|-------|
| 1 | Проверь `-private` в имени | Безопасность |
| 2 | Создай `.gitignore` | Не коммитить лишнее |
| 3 | `bash scripts/audit-gitignore.sh` | Проверка |
| 4 | Создай `.env.example` | Шаблон без секретов |
| 5 | Создай `README.md` | Документация |
| 6 | Сделай скриншоты | Визуал |
| 7 | Создай `LICENSE` | Лицензия |
| 8 | `"private": false` в package.json | Для npm |
| 9 | `git init && git add -A && git commit` | Первый коммит |
| 10 | `git remote add origin && git push` | Публикация |
