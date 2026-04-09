# Pre-commit & Code Quality Setup

Триггеры: "pre-commit", "настроить линтинг", "code quality gate", "lizard", "cyclomatic complexity", "настроить linter", "pre-commit hook", "статический анализ", "настроить проверку перед commit", "check before commit", "автопроверка кода", "настроить code quality"

## Контекст
Настройка pre-commit хуков для проверки кода перед commit. Включает linter, formatter, complexity check.

## Обязательный инструмент: Lizard

Анализатор cyclomatic complexity для ВСЕХ языков.

```
pip install lizard  # или uv pip install lizard
lizard -l 15 -n 300 -a 10 <dir>
```

**Ориентиры:** complexity ≤ 15, NLOC ≤ 300, параметры ≤ 10.

## Инструменты по языкам

| Язык | Линтер | Форматер | Анализатор |
|------|--------|----------|------------|
| Python | ruff | ruff format | mypy, lizard |
| TypeScript | eslint, biome | biome, prettier | tsc --noEmit |
| JavaScript | eslint | prettier | lizard |
| Go | golangci-lint | gofmt | go vet |
| Rust | clippy | rustfmt | cargo check |
| C/C++ | clang-tidy | clang-format | cppcheck |
| Java | checkstyle | spotless | pmd |

## Примеры pre-commit-config.yaml

### Python
```yaml
repos:
  - repo: local
    hooks:
      - id: ruff-check
        name: ruff check
        entry: uv run ruff check --force-exclude
        language: system
        types: [python]
      - id: ruff-format
        name: ruff format
        entry: uv run ruff format --check
        language: system
        types: [python]
      - id: lizard
        name: lizard complexity
        entry: uv run lizard -l 15 -n 300 -a 10 .
        language: system
        types: [python]
```

### TypeScript/JavaScript
```yaml
repos:
  - repo: local
    hooks:
      - id: eslint
        name: eslint
        entry: npx eslint
        language: system
        types: [ts, tsx, javascript]
      - id: biome
        name: biome format
        entry: npx @biomejs/biome format --write
        language: system
        types: [ts, tsx, javascript]
      - id: tsc
        name: type check
        entry: npx tsc --noEmit
        language: system
        types: [ts, tsx]
```

### Go
```yaml
repos:
  - repo: local
    hooks:
      - id: golangci-lint
        name: golangci-lint
        entry: golangci-lint run
        language: system
        types: [go]
      - id: gofmt
        name: gofmt
        entry: gofmt -l -w
        language: system
        types: [go]
```

## Monorepo

Для monorepo используй `changed-files` чтобы проверять только изменённые файлы:

```yaml
repos:
  - repo: local
    hooks:
      - id: ruff-check
        name: ruff check
        entry: bash -c 'git diff --cached --name-only --diff-filter=ACM | grep ".py$" | xargs -r uv run ruff check'
        language: system
        pass_filenames: false
```

## Алгоритм настройки

1. Определи стек
2. Подбери инструменты из таблицы
3. Создай `.pre-commit-config.yaml` с `uv run` (или `npx` для JS)
4. `pre-commit install`
5. Тест: `pre-commit run --all-files`

### Почему uv run а не внешние хуки

- Локальные утилиты = контроль версий, кеш, скорость
- `uv` = мгновенная установка, изолированное окружение
- Нет зависимости от GitHub при каждом коммите

## Инженерный принцип оценки метрик

Метрики — сигнал, не абсолютный запрет.

- Порог превышен без объяснения → дефект, упрости код
- Есть обоснование (архитектура, ограничения) → зафиксируй в PR
- Метрики применяются ПОСЛЕ формирования решения, не во время

## Примеры

✅ Правильно:
- pre-commit настроен до начала разработки
- complexity ≤ 15, горячие пути оптимизированы
- Monorepo проверяет только изменённые файлы
- Hotfix отклоняется, но перед merge качество восстановлено

❌ Неправильно:
- pre-commit без кеша — медленный каждый коммит
- complexity 50+ без обоснования
- Отключение линтера вместо исправления проблем
- Проверка всех файлов в monorepo — тормозит CI
