@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
title Gestao One The One - Aplicativo local

echo.
echo ===============================================
echo  Gestao One The One - Inicializacao limpa
echo ===============================================
echo.
echo Pasta do projeto:
echo %cd%
echo.

where git >nul 2>nul
if %errorlevel%==0 (
  git rev-parse --is-inside-work-tree >nul 2>nul
  if %errorlevel%==0 (
    echo Atualizando arquivos pelo GitHub...
    git fetch --all --prune
    if errorlevel 1 goto git_error
    git pull --ff-only
    if errorlevel 1 goto git_error
    echo.
    echo Projeto atualizado com sucesso.
  ) else (
    echo Esta pasta nao parece ser um repositorio Git. Vou abrir a versao local existente.
  )
) else (
  echo Git nao encontrado. Vou abrir a versao local existente.
)

goto start_server

:git_error
echo.
echo Nao foi possivel atualizar automaticamente pelo Git.
echo Se aparecer mensagem de conflito, feche este arquivo e me chame para ajustar sem perder dados.
pause
exit /b 1

:start_server
echo.
echo Iniciando servidor local...
set PORT=4173
set URL=http://127.0.0.1:%PORT%/index.html

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $c = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue; if ($c) { 'PORT_IN_USE' } } catch {}" > "%TEMP%\g11_port_check.txt"
findstr /c:"PORT_IN_USE" "%TEMP%\g11_port_check.txt" >nul 2>nul
if %errorlevel%==0 (
  echo Ja existe um servidor usando a porta %PORT%. Vou aproveitar essa sessao.
) else (
  where py >nul 2>nul
  if %errorlevel%==0 (
    start "Gestao One The One - Servidor local" /min cmd /k "pushd ""%~dp0"" && py -3 -m http.server %PORT% --bind 127.0.0.1"
  ) else (
    where python >nul 2>nul
    if %errorlevel%==0 (
      start "Gestao One The One - Servidor local" /min cmd /k "pushd ""%~dp0"" && python -m http.server %PORT% --bind 127.0.0.1"
    ) else (
      echo.
      echo Python nao encontrado. Instale o Python ou me chame para criar uma alternativa.
      pause
      exit /b 1
    )
  )
)

timeout /t 2 /nobreak >nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set STAMP=%%i
set CLEAN_URL=%URL%?local=1^&v=%STAMP%

echo.
echo Abrindo aplicativo local:
echo %CLEAN_URL%
start "" "%CLEAN_URL%"

echo.
echo Pronto. Use esta janela apenas se quiser fechar/reabrir depois.
echo Para encerrar o servidor local, feche a janela minimizada chamada "Gestao One The One - Servidor local".
echo.
pause

