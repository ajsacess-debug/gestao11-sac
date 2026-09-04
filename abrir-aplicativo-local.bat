@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title Gestao One The One - Aplicativo local

set "PORT=4173"
set "URL=http://127.0.0.1:%PORT%/index.html"
set "PROJECT_DIR=%CD%"
set "PYTHON_CMD="
set "GIT_CMD="

echo.
echo ===============================================
echo  Gestao One The One - Inicializacao limpa
echo ===============================================
echo.
echo Pasta do projeto:
echo %PROJECT_DIR%
echo.

rem Procura o Git mesmo quando o Windows ainda nao atualizou o PATH.
where git >nul 2>nul && set "GIT_CMD=git"
if not defined GIT_CMD if exist "%ProgramFiles%\Git\cmd\git.exe" set "GIT_CMD="%ProgramFiles%\Git\cmd\git.exe""
if not defined GIT_CMD if exist "%LOCALAPPDATA%\Programs\Git\cmd\git.exe" set "GIT_CMD="%LOCALAPPDATA%\Programs\Git\cmd\git.exe""

if defined GIT_CMD (
  echo Verificando atualizacoes do aplicativo...
  %GIT_CMD% rev-parse --is-inside-work-tree >nul 2>nul
  if not errorlevel 1 (
    %GIT_CMD% fetch --all --prune
    if errorlevel 1 goto update_warning
    %GIT_CMD% pull --ff-only
    if errorlevel 1 goto update_warning
    echo Aplicativo atualizado com sucesso.
  )
) else (
  echo Git nao encontrado nesta janela. A versao local atual sera aberta.
)
goto find_python

:update_warning
echo.
echo Nao foi possivel buscar atualizacoes agora. A versao local sera aberta sem apagar nenhum arquivo.

:find_python
rem Procura Python no PATH e tambem nas instalacoes comuns deste computador.
where py >nul 2>nul && set "PYTHON_CMD=py -3"
if not defined PYTHON_CMD where python >nul 2>nul && set "PYTHON_CMD=python"
if not defined PYTHON_CMD if exist "%LOCALAPPDATA%\python-portable\python\python.exe" set "PYTHON_CMD="%LOCALAPPDATA%\python-portable\python\python.exe""
if not defined PYTHON_CMD if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON_CMD="%LOCALAPPDATA%\Programs\Python\Python313\python.exe""
if not defined PYTHON_CMD if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON_CMD="%LOCALAPPDATA%\Programs\Python\Python312\python.exe""

if not defined PYTHON_CMD (
  echo.
  echo Python nao foi localizado. Me envie esta tela para eu ajustar o caminho correto.
  pause
  exit /b 1
)

echo Python localizado. Iniciando servidor local...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $c = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue; if ($c) { 'PORT_IN_USE' } } catch {}" > "%TEMP%\g11_port_check.txt"
findstr /c:"PORT_IN_USE" "%TEMP%\g11_port_check.txt" >nul 2>nul
if %errorlevel%==0 (
  echo Servidor local ja esta em execucao. Vou aproveitar esta sessao.
) else (
  start "Gestao One The One - Servidor local" /min cmd /k "pushd ""%PROJECT_DIR%"" ^&^& %PYTHON_CMD% -m http.server %PORT% --bind 127.0.0.1"
)

timeout /t 2 /nobreak >nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMddHHmmss"') do set "STAMP=%%i"
set "CLEAN_URL=%URL%?local=1^&v=%STAMP%"

echo.
echo Abrindo aplicativo local atualizado:
echo %CLEAN_URL%
start "" "%CLEAN_URL%"

echo.
echo Pronto. Para encerrar o aplicativo local, feche a janela minimizada
echo chamada "Gestao One The One - Servidor local".
pause

