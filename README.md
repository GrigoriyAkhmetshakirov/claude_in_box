# Claude in a Box

Запускаем Claude Code в Docker-контейнере с полной изоляцией. Клод делает что хочет внутри контейнера, но наружу не видит ничего, кроме папки `claude_in_box/`.

## Зачем это нужно

Claude Code по умолчанию на каждый чих спрашивает разрешение. Это правильно для безопасности, но дико тормозит работу. Здесь я даю Клоду полную свободу (`bypassPermissions`) — он правит файлы, выполняет команды, ставит пакеты без единого вопроса.

Безопасно, потому что контейнер изолирован. Даже `rm -rf /` уничтожит только контейнер, хост не пострадает.

```
┌─────────────────────────────────────┐
│ claude_in_box/  — единственное,     │
│                  что видит Клод     │
│  ┌───────────────────────────────┐  │
│  │ Docker-контейнер              │  │
│  │                               │  │
│  │  Claude Code                  │  │
│  │  • bypassPermissions          │  │
│  │  • без подтверждений          │  │
│  │                               │  │
│  │  /workspace ← ./projects      │  │
│  │  ~/.claude   ← ./config       │  │
│  └───────────────────────────────┘  │
│                                     │
│  НЕТ доступа:                       │
│  ✗ хост-файлы                       │
│  ✗ docker.sock                      │
│  ✗ хост-сеть                        │
└─────────────────────────────────────┘
```

## Что внутри

```
claude_in_box/
├── Dockerfile              # node:22-slim + git + python + Claude Code CLI
├── docker-compose.yml      # bridge-сеть, только локальные монтирования
├── .env.example            # Шаблон для .env
├── .env                    # Твои API-ключи
├── .gitignore              # Исключает .env, config/, projects/
├── claude-docker           # Скрипт запуска (Linux/macOS)
├── claude-docker.bat       # Скрипт запуска (Windows)
├── USAGE.md                # Памятка по Claude Code
├── config.example/         # Шаблоны конфигов
│   ├── settings.json       # bypassPermissions, язык
│   └── settings.local.json # Разрешённые команды
├── config/                 # Рабочие конфиги
│   ├── settings.json
│   └── settings.local.json
└── projects/               # Сюда кладёшь проекты
```

## Быстрый старт

Клонируем, копируем шаблоны, вставляем ключ:

```bash
git clone https://github.com/GrigoriyAkhmetshakirov/claude_in_box.git
cd claude_in_box

cp .env.example .env
cp -r config.example config
mkdir -p projects
```

Редактируем `.env` — вставляем свой ключ:

```
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
ANTHROPIC_AUTH_TOKEN=sk-твой-ключ
ANTHROPIC_MODEL=deepseek-v4-pro
ANTHROPIC_SMALL_FAST_MODEL=deepseek-v4-pro
API_TIMEOUT_MS=600000
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

Я использую DeepSeek, но подойдёт любое OpenAI-совместимое или Anthropic API — просто замени переменные.

Собираем и запускаем:

```bash
docker compose build
docker compose up -d
```

## Как пользоваться

```bash
./claude-docker                      # новый интерактивный сеанс
./claude-docker "что делает код?"     # один вопрос (неинтерактивно)
./claude-docker --resume             # продолжить последнюю сессию
./claude-docker --continue           # продолжить с последнего места
```

Или напрямую:

```bash
docker compose exec -it -u claude claude claude
```

### Windows

```cmd
claude-docker.bat                    # новый интерактивный сеанс
claude-docker.bat --resume           # продолжить последнюю сессию
claude-docker.bat "что делает код?"   # один вопрос
```

## Добавляем проекты

```bash
cd projects
git clone https://github.com/user/my-project.git
```

Внутри контейнера проект будет в `/workspace/my-project`.

## Настройка прав

Права задаются в `config/settings.json`, ключ `permissions.defaultMode`.

Доступные режимы:

| Режим | Правки файлов | Bash | Подтверждения |
|-------|--------------|------|---------------|
| `bypassPermissions` | Без спроса | Без спроса | Нет |
| `acceptEdits` | Без спроса | По whitelist | Только опасное |
| `default` | Спрашивает | Спрашивает | Почти на всё |

По умолчанию стоит `bypassPermissions` — Клод может всё без подтверждений. Контейнер изолирован, так что это безопасно.

Если надоело и хочешь вернуть подтверждения — меняешь `defaultMode` на `acceptEdits` и перезапускаешь:

```bash
docker compose restart
```

В режиме `acceptEdits` bash-команды проверяются по белому списку из `config/settings.local.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(go *)",
      "Bash(npm *)",
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

Добавляешь нужные команды в `allow`, перезапускаешь — работают без подтверждения.

## Дать доступ к Docker хоста

Если Клоду нужен доступ к Docker-демону хоста, добавляешь в `docker-compose.yml`:

```yaml
volumes:
  - ./projects:/workspace
  - ./config:/home/claude/.claude
  - /var/run/docker.sock:/var/run/docker.sock    # ← вот эту строку
```

Docker CLI в образе уже есть.

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
# Копируем папку
scp -r claude_in_box user@other-machine:~/work/

# На новой машине
cd ~/work/claude_in_box
# создаём .env со своим ключом
docker compose build
docker compose up -d
./claude-docker
```

## Требования

- Docker 20.10+
- Docker Compose v2
- API-ключ Anthropic или совместимого провайдера

## Безопасность

- `.env` в `.gitignore` — ключи не улетят в репозиторий
- Контейнер изолирован — `bypassPermissions` не страшно
- Хочешь добавить доступ точечно (docker.sock, папки) — см. раздел выше
