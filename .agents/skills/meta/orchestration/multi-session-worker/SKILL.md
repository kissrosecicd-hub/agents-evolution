---
name: meta-multi-session-worker
description: "Мета-скилл оркестрации много-сессионных воркеров через tmux: запуск отдельных CLI-процессов, IPC через файлы, мониторинг, сбор результатов. Trigger when: запусти воркеров через tmux, multi-session mode, запусти отдельных работников, распределённые агенты, tmux workers"
---

# Meta: Multi-Session Workers

Оркестрация воркеров в отдельныхых tmux-сессиях — когда in-session subagents (`Agent` tool) недостаточно.

## Чем отличается от in-session subagents

| | In-session subagents | Multi-session workers |
|---|---|---|
| **Механизм** | `Agent` tool внутри одной LLM сессии | Отдельные CLI-процессы в tmux |
| **Контекст** | Общий, ограниченный | Изолированный у каждого |
| **Лимит** | ~4 параллельно | Сколько хватит CPU/памяти |
| **Сбой одного** | Загрязняет общий контекст | Полностью изолирован |
| **Общение** | Return values | Файлы + tmux capture |
| **Когда использовать** | Быстрые задачи, аудит | Тяжёлые задачи, генерация кода, тесты |

## Архитектура

```
┌─────────────────────────────────────┐
│  Main Agent (текущая сессия Qwen)   │
│  ┌───────────────────────────────┐  │
│  │  Координация:                 │  │
│  │  1. Раздача задач             │  │
│  │  2. Мониторинг статуса        │  │
│  │  3. Сбор результатов          │  │
│  │  4. Synthesis                 │  │
│  └───────────────────────────────┘  │
└──────────┬──────────────┬───────────┘
           │              │
    ┌──────▼──────┐ ┌─────▼──────┐
    │ tmux: w-0   │ │ tmux: w-1  │
    │ qwen code   │ │ codex      │
    │ "audit code"│ │ "write tests"│
    └─────────────┘ └────────────┘
           │              │
    ┌──────▼──────────────▼──────┐
    │  .workers/                  │
    │  ├── tasks/                 │
    │  │   ├── task-0.json        │
    │  │   └── task-1.json        │
    │  ├── results/               │
    │  │   ├── result-0.md        │
    │  │   └── result-1.md        │
    │  └── status.json            │
    └─────────────────────────────┘
```

## Протокол задач

### Формат задачи: `.workers/tasks/task-N.json`

```json
{
  "id": "task-0",
  "worker": "worker-0",
  "cli": "qwen",
  "task": "Проведи полный аудит безопасности /home/qwen/kanban-board/. Проверь: секреты, инъекции, XSS, CORS, auth. Отчёт на русском.",
  "context_file": ".workers/context/project-overview.md",
  "expected_output": "security-report.md",
  "status": "pending",
  "created_at": "2026-04-07T12:00:00Z"
}
```

### Формат результата: `.workers/results/result-N.md`

Воркер пишет результат в файл. Если не пишет — главный ИИ читает через `tmux capture-pane`.

### Статус: `.workers/status.json`

```json
{
  "task-0": { "status": "done", "completed_at": "...", "result_file": ".workers/results/result-0.md" },
  "task-1": { "status": "running", "started_at": "..." },
  "task-2": { "status": "failed", "error": "tmux session died" }
}
```

## Команды

### 1. Подготовка директории

```bash
mkdir -p .workers/tasks .workers/results
```

### 2. Запуск воркера

```bash
tmux new-session -d -s worker-0 "qwen code --prompt 'Выполни задачу из .workers/tasks/task-0.json. Результат запиши в .workers/results/result-0.md'"
```

### 3. Мониторинг

```bash
# Посмотреть что делает воркер
tmux capture-pane -t worker-0 -p | tail -20

# Проверить что сессия жива
tmux has-session -t worker-0 2>/dev/null && echo "alive" || echo "dead"

# Проверить появился ли результат
cat .workers/results/result-0.md 2>/dev/null && echo "done" || echo "running"
```

### 4. Отправка задачи воркеру (если воркер уже работает)

```bash
# Записать задачу
echo '{"task": "..."}' > .workers/tasks/task-0.json

# Послать команду воркеру через tmux
tmux send-keys -t worker-0 "Прочитай задачу из .workers/tasks/task-0.json и выполни" Enter
```

### 5. Сбор результатов

```bash
# Прочитать результат
cat .workers/results/result-0.md

# Или capture если файл не создан
tmux capture-pane -t worker-0 -p > .workers/results/result-0.md
```

### 6. Очистка

```bash
# Убить все воркер-сессии
for s in $(tmux list-sessions | grep worker | cut -d: -f1); do
  tmux kill-session -t "$s"
done

# Очистить директорию
rm -rf .workers/
```

## Жизненный цикл

### Фаза 1: Spawn

```
1. Создать .workers/tasks/ .workers/results/
2. Для каждой задачи:
   - Создать task-N.json
   - Запустить tmux new-session -d -s worker-N
3. Записать status.json
```

### Фаза 2: Poll

```
Каждые 15-30 секунд:
  Для каждого worker-N:
    - Проверить tmux has-session -t worker-N
    - Проверить появился ли result-N.md
    - Обновить status.json
    - Если dead → отметить failed
```

### Фаза 3: Collect

```
1. Считать все result-N.md
2. Применить meta/orchestration/synthesis/SKILL.md
3. Сформировать итоговый отчёт
```

### Фаза 4: Cleanup

```
1. tmux kill-session -t worker-N для каждого
2. rm -rf .workers/
```

## Триггеры

- «запусти воркеров через tmux»
- «multi-session mode»
- «запусти отдельных работников»
- «распределённые агенты»
- «нужно больше 4 параллельных задач»

## Когда использовать

| Ситуация | Multi-session? |
|----------|---------------|
| «провери код» (один файл) | ❌ In-session достаточно |
| «полный аудит» (3-4 задачи) | ⚠️ Можно in-session |
| «аудит + тесты + документация + рефакторинг» (5+) | ✅ Multi-session |
| «напиши 10 тестов для 10 файлов» | ✅ Multi-session |
| «прогони E2E на 20 страницах» | ✅ Multi-session |
| Тяжёлые задачи (>5 мин на каждую) | ✅ Multi-session |

## Лимиты

| Ресурс | Лимит | Почему |
|--------|-------|--------|
| Параллельные воркеры | 6-8 | CPU, память, API rate limits |
| Время жизни воркера | 10 мин | Бесконечные сессии = утечка ресурсов |
| Размер задачи | 2000 слов | Слишком большие = таймаут |

## Обработка ошибок

| Ошибка | Действие |
|--------|----------|
| Воркер упал сразу | Retry 1 раз, потом skip |
| Воркер завис (нет результата 10 мин) | tmux kill-session → skip |
| Результат пустой | capture-pane → сохранить что есть |
| Все воркеры упали | Fallback: in-session subagents или main agent сам |

## Интеграция с другими мета-скиллами

| Скилл | Роль |
|-------|------|
| `meta/orchestration/spawn` | Решает КОГО запустить (in-session vs multi-session) |
| `meta/orchestration/synthesis` | Собирает результаты от воркеров |
| `meta/orchestration/recovery` | Обрабатывает сбои воркеров |
| `subagent-creator-universal` | Создаёт недостающих агентов для воркеров |
