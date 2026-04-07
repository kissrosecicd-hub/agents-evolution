---
name: meta-agent-synthesis
description: "Мета-скилл сбора и синтеза результатов от параллельных субагентов: дедупликация, приоритизация, конфликтующие рекомендации. Trigger when: синтез результатов, собери отчёты, merge результатов, дедупликация, обобщи результаты"
---

# Meta: Agent Synthesis

Собирает результаты от параллельных субагентов в единый actionable отчёт.

## Что делает

- Объединяет результаты 2-4 агентов в один отчёт
- Убирает дубликаты (два агента нашли одно и то же)
- Разрешает противоречия
- Строит приоритизированный план действий

## Что НЕ делает

- НЕ копирует сырые отчёты друг за другом
- НЕ теряет важные находки при дедупликации
- НЕ скрывает конфликты — помечает их явно

## Алгоритм синтеза

```
1. Собрать все отчёты
2. Нормализовать формат (file:line → issue → severity → fix)
3. Дедупликация:
   - Если два агента указали на одно место → объединить
   - Сохранить оба perspective, не терять
4. Приоритизация:
   - CRITICAL (blocking, security exploit) → first
   - HIGH (likely bug in production) → second
   - MEDIUM (edge case, performance) → third
   - LOW (style, suggestion) → last
5. Конфликты:
   - Агент A говорит X, агент B говорит NOT X
   - Пометить: "CONFLICT: agent A recommends X, agent B recommends Y → needs human decision"
6. Финальный отчёт:
   - Executive summary (1 абзац)
   - Prioritized findings
   - Conflicts (если есть)
   - Action plan
```

## Дедупликация

| Ситуация | Действие |
|----------|----------|
| code-reviewer и security-auditor нашли один XSS | Один finding, оба источника упомянуты |
| Два агента советуют одно и то же | Один пункт, оба credited |
| Один агент детальнее, другой поверхностнее | Взять детальное, отметить что второй подтвердил |
| Агенты смотрели разные файлы | Не дедуплицировать — это разные findings |

## Приоритизация

| Priority | Критерий | Пример |
|----------|----------|--------|
| 🔴 CRITICAL | Эксплуатируемо сейчас, блокирует работу | Path traversal, broken auth, crash on startup |
| 🟠 HIGH | Сломает в production с высокой вероятностью | Race condition, null pointer, missing validation |
| 🟡 MEDIUM | Проблема при определённых условиях | Slow query, edge case, minor UI glitch |
| 🟢 LOW | Улучшение, не баг | Code style, naming, optimization suggestion |

## Разрешение конфликтов

| Конфликт | Стратегия |
|----------|-----------|
| Агент A: «рефактори», агент B: «не трогай, работает» | Пометить конфликт, рекомендовать: сначала тесты, потом рефакторинг |
| Агент A: «безопасно», агент B: «уязвимость» | Верить security-агенту, пометить как HIGH |
| Два агента, разные фиксы для одного бага | Показать оба варианта с pros/cons |
| Агент говорит «всё ок», другой нашёл баги | Верить тому кто нашёл баги |

## Формат итогового отчёта

```
## Consolidated Audit Report

### Executive Summary
[1-2 абзаца: общее состояние, главные проблемы, общая оценка]

### Critical Issues (N)
1. **[file:line]** Issue description
   - Found by: [agent names]
   - Impact: [what could go wrong]
   - Fix: [concrete solution]

### High Priority Issues (N)
[same format]

### Medium & Low (N)
[summarized, not every single one]

### Conflicts Requiring Human Decision
1. [Agent A recommends X, Agent B recommends Y because... → needs decision]

### Consolidated Action Plan
1. [Priority 1 — fix now]
2. [Priority 2 — fix next]
3. [Priority 3 — can wait]

### What's Good
[Positive findings from all agents]
```

## Правила

- **Язык итогового отчёта — всегда на языке пользователя.** Если запрос на русском — итог на русском. Если на английском — на английском. Можно оставить технические термины на английском (severity, file:line, CRITICAL, HIGH), но связки, выводы, описания и action plan — на языке пользователя.
- Executive summary первым — пользователь видит картину сразу
- Каждый finding ссылается на файл и строку
- Конкретные фиксы, не абстрактные рекомендации
- Конфликты не скрывать — явно помечать
- Не терять позитивные находки — что сделано хорошо
- Итог = action plan, не сырой дамп отчётов
