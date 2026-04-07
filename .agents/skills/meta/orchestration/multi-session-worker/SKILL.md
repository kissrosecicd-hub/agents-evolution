---
name: meta-multi-session-worker
description: "Мета-скилл оркестрации много-сессионных воркеров через tmux: запуск отдельных CLI-процессов, IPC через файлы, мониторинг, сбор результатов. Trigger when: запусти воркеров через tmux, multi-session mode, запусти отдельных работников, распределённые агенты, tmux workers"
---

# Meta: Multi-Session Workers

Оркестрация воркеров в отдельных tmux-сессиях — когда in-session subagents (`Agent` tool) недостаточно.

## Чем отличается

| | In-session subagents | Multi-session workers |
|---|---|---|
| **Механизм** | `Agent` tool внутри одной LLM сессии | Отдельные CLI-процессы в tmux |
| **Контекст** | Общий, ограниченный | Изолированный у каждого |
| **Лимит** | ~4 параллельно | 6-8 (CPU/память) |
| **Сбой одного** | Загрязняет общий контекст | Полностью изолирован |
| **Общение** | Return values | Файлы + tmux capture |

## Архитектура

```
Main Agent (координатор)
  ├── tmux: worker-0  (qwen code / codex / ...)
  ├── tmux: worker-1  (qwen code / codex / ...)
  └── tmux: worker-N
        ↓
    .workers/
    ├── tasks/     → task-N.json
    ├── results/   ← result-N.md
    └── status.json
```

## Протокол задач

**task-N.json:**
```json
{
  "id": "task-0",
  "worker": "worker-0",
  "cli": "qwen",
  "task": "Описание задачи",
  "expected_output": "result-0.md",
  "status": "pending"
}
```

**result-N.md:** воркер пишет результат в файл. Если не пишет — ИИ читает через `tmux capture-pane`.

**status.json:** трекинг `pending` → `running` → `done` / `failed`.

## Жизненный цикл

1. **Spawn** — создать `.workers/tasks/` + `.workers/results/`, запустить tmux-сессии, раздать задачи
2. **Poll** — каждые 15-30s: проверить tmux has-session + наличие result-N.md
3. **Collect** — считать все result-N.md, применить synthesis
4. **Cleanup** — `tmux kill-session` для каждого, удалить `.workers/`

## Решения

| Ситуация | Решение |
|----------|---------|
| «провери код» (один файл) | ❌ In-session достаточно |
| «полный аудит» (3-4 задачи) | ⚠️ Можно in-session |
| «аудит + тесты + документация» (5+) | ✅ Multi-session |
| Тяжёлые задачи (>5 мин) | ✅ Multi-session |
| >4 параллельных задач | ✅ Multi-session |

## Лимиты

| Ресурс | Лимит | Почему |
|--------|-------|--------|
| Параллельные воркеры | 6-8 | CPU, память, API rate limits |
| Время жизни воркера | 10 мин | Бесконечные сессии = утечка |
| Размер задачи | 2000 слов | Больше = таймаут |

## Обработка ошибок

| Ошибка | Действие |
|--------|----------|
| Воркер упал сразу | Retry 1 раз → skip |
| Воркер завис (>10 мин) | `tmux kill-session` → skip |
| Результат пустой | `capture-pane` → сохранить что есть |
| Все воркеры упали | Fallback: in-session или main agent сам |

## Интеграция

| Скилл | Роль |
|-------|------|
| `spawn` | Решает КОГО запустить |
| `synthesis` | Собирает результаты |
| `recovery` | Обрабатывает сбои |
| `subagent-creator-universal` | Создаёт недостающих агентов |

## Требования окружения

Перед использованием:
- `tmux` установлен (`tmux -V`)
- CLI-инструменты (`qwen code`, `codex`) доступны в PATH
- Директория `.workers/` создана
