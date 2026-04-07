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
