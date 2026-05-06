@echo off
cd /d "%~dp0"

REM Поднять контейнер если не запущен
docker compose up -d >nul 2>&1
if %errorlevel% neq 0 docker compose up -d

REM Всегда используем -it для интерактивного режима
docker compose exec -it -u claude claude claude %*
