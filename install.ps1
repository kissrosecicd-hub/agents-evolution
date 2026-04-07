# AGENTS.md Installer — Windows (PowerShell)
# Устанавливает AGENTS.md, скиллы, мета-оркестрацию и примеры субагентов

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     AGENTS.md Installer v2.0                     ║" -ForegroundColor Cyan
Write-Host "║     Windows (PowerShell) — с субагентами         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Определяем директорию пользователя
$HOME_DIR = $env:USERPROFILE

# Определяем директорию скрипта
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "📂 Установка из: $SCRIPT_DIR" -ForegroundColor Yellow
Write-Host "🏠 Домашняя директория: $HOME_DIR" -ForegroundColor Yellow
Write-Host ""

# Проверка существования AGENTS.md
if (-not (Test-Path "$SCRIPT_DIR\AGENTS.md")) {
    Write-Host "❌ AGENTS.md не найден в $SCRIPT_DIR" -ForegroundColor Red
    Write-Host "   Запустите скрипт из директории репозитория" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Начало установки..." -ForegroundColor Green
Write-Host ""

# 1. Копируем AGENTS.md
Write-Host "📄 Копирую AGENTS.md → $HOME_DIR\" -ForegroundColor Yellow
Copy-Item "$SCRIPT_DIR\AGENTS.md" "$HOME_DIR\AGENTS.md" -Force
Write-Host "   ✅ AGENTS.md установлен" -ForegroundColor Green

# 2. Создаём директории
Write-Host "📁 Создаю .agents\skills\" -ForegroundColor Yellow
$skillsDir = Join-Path $HOME_DIR ".agents\skills"
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

Write-Host "📁 Создаю .agents\ExampleSubagents\" -ForegroundColor Yellow
$exampleDir = Join-Path $HOME_DIR ".agents\ExampleSubagents"
New-Item -ItemType Directory -Path $exampleDir -Force | Out-Null

Write-Host "📁 Создаю .myskills\skills\" -ForegroundColor Yellow
$mySkillsDir = Join-Path $HOME_DIR ".myskills\skills"
New-Item -ItemType Directory -Path $mySkillsDir -Force | Out-Null

# 3. Копируем скиллы из skills/ → ~/.agents/skills/
if (Test-Path "$SCRIPT_DIR\skills") {
    Write-Host "🧩 Копирую скиллы..." -ForegroundColor Yellow
    Get-ChildItem "$SCRIPT_DIR\skills" -Directory | Where-Object { $_.Name -ne ".template" } | ForEach-Object {
        $skillName = $_.Name
        $destDir = Join-Path $skillsDir $skillName
        if (Test-Path $destDir) {
            Remove-Item $destDir -Recurse -Force
        }
        Copy-Item $_.FullName $destDir -Recurse -Force
        Write-Host "   ✅ $skillName" -ForegroundColor Green
    }
}

# 4. Копируем мета-скиллы оркестрации
if (Test-Path "$SCRIPT_DIR\.agents\skills\meta\orchestration") {
    Write-Host "🎭 Копирую мета-оркестрацию..." -ForegroundColor Yellow
    $metaDir = Join-Path $HOME_DIR ".agents\skills\meta"
    New-Item -ItemType Directory -Path $metaDir -Force | Out-Null
    Copy-Item "$SCRIPT_DIR\.agents\skills\meta\orchestration" $metaDir -Recurse -Force
    Write-Host "   ✅ meta/orchestration (spawn, synthesis, recovery, multi-session)" -ForegroundColor Green
}

# 5. Копируем subagent-creator-universal
if (Test-Path "$SCRIPT_DIR\.agents\skills\subagent-creator-universal") {
    Write-Host "🏗️  Копирую subagent-creator-universal..." -ForegroundColor Yellow
    $destDir = Join-Path $HOME_DIR ".agents\skills\subagent-creator-universal"
    if (Test-Path $destDir) {
        Remove-Item $destDir -Recurse -Force
    }
    Copy-Item "$SCRIPT_DIR\.agents\skills\subagent-creator-universal" $HOME_DIR\.agents\skills -Recurse -Force
    Write-Host "   ✅ subagent-creator-universal" -ForegroundColor Green
}

# 6. Копируем примеры субагентов
if (Test-Path "$SCRIPT_DIR\.agents\ExampleSubagents") {
    Write-Host "📋 Копирую примеры субагентов..." -ForegroundColor Yellow
    Get-ChildItem "$SCRIPT_DIR\.agents\ExampleSubagents" -Recurse | ForEach-Object {
        $destPath = $_.FullName -replace [regex]::Escape("$SCRIPT_DIR\.agents\ExampleSubagents"), "$exampleDir"
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $destPath -Force | Out-Null
        } else {
            Copy-Item $_.FullName $destPath -Force
        }
    }
    Write-Host "   ✅ ExampleSubagents (12 примеров)" -ForegroundColor Green
}

# 7. Создаём .notes\INBOX\
Write-Host "📝 Создаю .notes\INBOX\" -ForegroundColor Yellow
$inboxDir = Join-Path $HOME_DIR ".notes\INBOX"
New-Item -ItemType Directory -Path $inboxDir -Force | Out-Null
Write-Host "   ✅ .notes\INBOX создана" -ForegroundColor Green

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          ✅ Установка завершена!                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Установлено:" -ForegroundColor Green
Write-Host "  📄 AGENTS.md         → $HOME_DIR\AGENTS.md"
Write-Host "  🧩 Скиллы            → $HOME_DIR\.agents\skills\"
Write-Host "  🎭 Мета-оркестрация  → $HOME_DIR\.agents\skills\meta\orchestration\"
Write-Host "  🏗️  Subagent Creator  → $HOME_DIR\.agents\skills\subagent-creator-universal\"
Write-Host "  📋 Примеры агентов   → $HOME_DIR\.agents\ExampleSubagents\"
Write-Host "  🔧 User Skills       → $HOME_DIR\.myskills\skills\"
Write-Host "  📝 Заметки           → $HOME_DIR\.notes\INBOX\"
Write-Host ""
Write-Host "Следующие шаги:" -ForegroundColor Yellow
Write-Host "  1. Откройте ваш AI-агент (Qwen, Claude, Cursor...)"
Write-Host "  2. Начните новый чат — агент подхватит AGENTS.md"
Write-Host "  3. Или скажите: «следуй AGENTS.md»"
Write-Host "  4. Для сабагентов: «хочу сабагентов» или «заспавни агентов»"
Write-Host ""
Write-Host "📖 Документация: https://github.com/kissrosecicd-hub/agents-evolution" -ForegroundColor Cyan
Write-Host "💬 Автор: https://t.me/smartcaveman1" -ForegroundColor Cyan
