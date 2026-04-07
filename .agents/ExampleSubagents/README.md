# Example Subagents

Это **примеры** субагентов — только для вдохновения и референса.

## Структура

```
ExampleSubagents/
├── *.md                  # Примеры агентов (Qwen MD+YAML формат)
└── meta/                 # Примеры мета-агентов (оркестрация)
```

## Как использовать

1. **Не копировать** файлы напрямую — они не привязаны к конкретному CLI
2. Использовать `.agents/skills/subagent-creator-universal/SKILL.md` для создания агентов с правильной структурой
3. Смотреть примеры для понимания формата, идей, паттернов

## Форматы по CLI

| CLI | Формат | Директория |
|-----|--------|------------|
| Qwen Code | `.md` + YAML frontmatter | `~/.qwen/agents/` |
| Codex CLI | `.toml` | `~/.codex/agents/` |
| Claude Code | `.md` + YAML frontmatter | `~/.claude/agents/` |
| Factory Droid | `.md` + YAML frontmatter | `.factory/droids/` |
| OpenCode | `.md` + YAML frontmatter | `~/.config/opencode/agents/` |
