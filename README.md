# Claude in a Box

Изолированный [Claude Code](https://claude.ai/code) в Docker-контейнере. Клод имеет полные права внутри контейнера, но не видит ничего за пределами папки `claude_in_box/`.

## Концепция

```
┌─────────────────────────────────────┐
│ claude_in_box/  (единственное, что  │
│                  видит контейнер)   │
│  ┌───────────────────────────────┐  │
│  │ Docker-контейнер              │  │
│  │                               │  │
│  │  Claude Code                  │  │
│  │  • bypassPermissions          │  │
│  │  • пользователь claude        │  │
│  │  • никаких подтверждений      │  │
│  │                               │  │
│  │  /workspace ← ./projects      │  │
│  │  /home/claude/.claude←./config│  │
│  └───────────────────────────────┘  │
│                                     │
│  НЕТ доступа к:                     │
│  ✗ хост-файлам                      │
│  ✗ docker.sock                      │
│  ✗ хост-сети                        │
└─────────────────────────────────────┘
```

## Структура

```
claude_in_box/
├── Dockerfile              # node:22-slim + git + python + Claude Code CLI
├── docker-compose.yml      # bridge-сеть, только локальные монтирования
├── .env.example            # Шаблон для .env
├── .env                    # API-ключи
├── .gitignore              # Исключает .env, config/, projects/
├── claude-docker           # Обёртка для общения с контейнером с хоста
├── USAGE.md                # Инструкция по использованию Claude Code
├── config.example/         # Шаблон конфигов (скопировать в config/)
│   ├── settings.json       # bypassPermissions, язык
│   └── settings.local.json # Разрешения команд и WebSearch
├── config/                 # Рабочие конфиги
│   ├── settings.json
│   └── settings.local.json
└── projects/               # Сюда клади проекты
```

## Быстрый старт

### 1. Клонирование и настройка

```bash
git clone https://github.com/GrigoriyAkhmetshakirov/claude_in_box.git
cd claude_in_box

# Создать .env из шаблона
cp .env.example .env

# Создать config/ из шаблона
cp -r config.example config

# Создать папку для проектов
mkdir -p projects
```

Отредактируй `.env` — вставь свой API-ключ:

Файл `.env`:

```
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=sk-твой-ключ
ANTHROPIC_MODEL=deepseek-v4-pro
ANTHROPIC_SMALL_FAST_MODEL=deepseek-v4-pro
API_TIMEOUT_MS=600000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

Подойдёт любой OpenAI-совместимый или Anthropic API — замени переменные на свои.

### 2. Сборка и запуск

```bash
cd claude_in_box

# Собрать образ (один раз)
docker compose build

# Запустить контейнер в фоне
docker compose up -d
```

### 3. Общение с Claude

```bash
# Новый сеанс
./claude-docker

# Продолжить последний сеанс (видит весь предыдущий диалог)
./claude-docker --resume

# Продолжить с места остановки
./claude-docker --continue

# Одноразовый запрос (без интерактива)
./claude-docker -p "объясни этот проект"

# Напрямую через docker compose
docker compose exec -it claude claude
```

**Разница между режимами:**

| Команда | Память диалога | Использование |
|---------|---------------|---------------|
| `./claude-docker` | Новый сеанс, не помнит прошлый разговор | Новая задача |
| `./claude-docker --resume` | Полный доступ к последнему диалогу | Продолжить вчерашнюю работу |
| `./claude-docker --continue` | Продолжает ровно с места остановки | Перезапустил контейнер и хочешь дальше |
| `./claude-docker -p "..."` | Без сохранения | Быстрый вопрос |

Авто-память (файлы проектов, CLAUDE.md, сохранённые факты) доступна во всех режимах.

### 4. Добавить проекты

```bash
cd projects
git clone https://github.com/user/my-project.git
```

Внутри контейнера проект будет в `/workspace/my-project`.

## Как менять права

Права настраиваются в `config/settings.json` через ключ `permissions.defaultMode`.

### Доступные режимы

| Режим | Правки файлов | Bash-команды | Подтверждения |
|-------|--------------|--------------|---------------|
| `bypassPermissions` | Без спроса | Без спроса | Никаких |
| `acceptEdits` | Без спроса | По whitelist | Только для опасных команд |
| `default` | С подтверждением | С подтверждением | Почти на всё |

### Текущая конфигурация (`bypassPermissions`)

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

Клод может всё без единого подтверждения. Подходит, потому что контейнер изолирован — радиус поражения ограничен папкой `claude_in_box/`.

### Если хочешь вернуть подтверждения

Поменяй `defaultMode` в `config/settings.json`:

```json
{
  "permissions": {
    "defaultMode": "acceptEdits"
  }
}
```

Затем перезапусти контейнер:

```bash
docker compose restart
```

### whitelist для Bash (только в режиме `acceptEdits`)

Когда `defaultMode: "acceptEdits"`, Bash-команды проверяются по белому списку из `config/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(go *)",
      "Bash(npm *)",
      "Bash(python3 *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(mkdir *)",
      "Bash(rm *)",
      "WebSearch",
      "WebFetch"
    ]
  }
}
```

Добавь нужные команды в массив `allow`, перезапусти контейнер — и они будут выполняться без подтверждения.

### Добавить доступ к Docker хоста

Если нужен доступ к Docker-демону хоста, добавь в `docker-compose.yml`:

```yaml
volumes:
  - ./projects:/workspace
  - ./config:/home/claude/.claude
  - /var/run/docker.sock:/var/run/docker.sock    # ← добавить эту строку
```

И в Dockerfile должен быть установлен Docker CLI (уже есть).

## Управление контейнером

```bash
docker compose up -d      # запустить
docker compose stop       # остановить
docker compose down       # удалить
docker compose logs -f    # логи
docker compose restart    # перезапустить (подхватит изменения config/)
```

## Перенос на другую машину

```bash
# 1. Скопировать папку
scp -r claude_in_box user@other-machine:~/work/

# 2. На новой машине
cd ~/work/claude_in_box
# Создать .env со своим ключом
docker compose build
docker compose up -d
./claude-docker
```

## Требования

- Docker 20.10+
- Docker Compose v2
- API-ключ Anthropic или совместимого провайдера

## Безопасность

- `.env` в `.gitignore` — не попадёт в репозиторий
- Контейнер полностью изолирован: `bypassPermissions` не опасен, потому что Клод видит только файлы внутри `claude_in_box/`
- Даже `rm -rf /` уничтожит контейнер, не хост
- При необходимости можно добавить доступ к хосту точечно (docker.sock, дополнительные папки) — см. раздел «Как менять права»
