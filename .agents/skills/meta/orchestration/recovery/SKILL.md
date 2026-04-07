---
name: meta-agent-recovery
description: "Мета-скилл обработки сбоев субагентов: таймауты, зависания, каскадные отказы, fallback. Trigger when: агент упал, агент завис, partial results, таймаут, agent crash, субагент не отвечает, каскадный сбой"
---

# Meta: Agent Recovery

Обрабатывает сбои субагентов — таймауты, зависания, каскадные отказы — и обеспечивает graceful degradation.

## Типы сбоев

| Тип | Симптом | Причина |
|-----|---------|---------|
| **Таймаут** | Агент не отвечает N секунд | Задача слишком сложная, модель зависла |
| **JSON парсинг** | `InvalidParameter`, `function.arguments` | Ответ слишком длинный, спецсимволы |
| **Каскадный** | Агент B без данных от агента A | Агент A упал, B ожидает его результат |
| **Частичный** | Агент ответил но не завершил | Прервался на середине задачи |
| **Полный** | Агент вернул ошибку сразу | Неподдерживаемый subagent_type |

## Стратегии восстановления

### 1. Таймаут → Skip & Continue

```
Агент не отвечает → ждать 30s → skip → продолжить с остальными →
в отчёте: "X agent skipped (timeout), results from Y agents"
```

**Когда:** Агент не критичный для результата.

### 2. Таймаут → Retry

```
Агент не отвечает → ждать 30s → повторить с упрощённым промптом →
если снова таймаут → skip
```

**Когда:** Агент важный, задача не слишком длинная.

### 3. Каскадный → Fallback

```
Агент A упал → агент B не может работать без A →
B тоже skip → main agent делает работу A сам
```

**Когда:** Критичный агент (без него весь pipeline ломается).

### 4. Частичный результат → Использовать

```
Агент начал но не закончил → взять что есть →
в отчёте: "partial result from X agent, may be incomplete"
```

**Когда:** Частичные результаты полезны (нашёл 3 из 5 проблем).

### 5. Полный сбой → Main agent fallback

```
Агент вообще не запускается → main agent берёт его роль →
читает SKILL.md → выполняет задачу сам
```

**Когда:** Агент недоступен, subagent_type не поддерживается.

## Матрица решений

| Агент упал | Критичен? | Действие |
|---|---|---|
| code-reviewer | Да (основной аудит) | Retry → Fallback: main agent делает review |
| security-auditor | Да (безопасность) | Retry → Fallback: main agent проверяет секреты |
| test-architect | Нет (можно потом) | Skip → пометить «тесты написать позже» |
| debugger | Зависит от бага | Если баг критичный → main agent чинит |
| docs-writer | Нет | Skip → «документацию добавить позже» |
| git-doctor | Нет | Skip → пользователь сделает сам |

## Graceful degradation

```
Идеально: 4 агента → полный отчёт
Реально: 2 агента + 2 skipped → отчёт с пометками

Пользователь видит:
✅ Результаты от code-reviewer
✅ Результаты от security-auditor
⏭️ test-architect skipped (timeout)
⏭️ docs-writer skipped (cascade failure)

Вывод: «2 из 4 агентов ответили. Основные проблемы найдены.
Тесты и документация — следующий шаг отдельно.»
```

## Правила

- **Никогда не ждать вечно** — таймаут 30-60s максимум
- **Не терять частичные результаты** — лучше неполный отчёт чем никакой
- **Честно говорить пользователю** — какие агенты не ответили
- **Fallback на main agent** — если критичный агент упал, я делаю сам
- **Не спавнить заново больше 1 раза** — если retry не помог, skip
- **Сохранять контекст** — даже если все агенты упали, результаты разведки (Explore) остаются

## Отчёт о сбоях

```
## Agent Status

| Agent | Status | Details |
|-------|--------|---------|
| code-reviewer | ✅ Completed | 12 findings |
| security-auditor | ✅ Completed | 8 findings |
| test-architect | ⏭️ Skipped | Timeout after 60s |
| docs-writer | ⏭️ Skipped | Cascade (needs test results) |

### Recovery Actions Taken
- test-architect: retried once, still timeout → skipped
- docs-writer: cascade skip, no test context available

### What's Missing
- Test coverage assessment
- Test file generation
→ Main agent can do this separately on request
```
