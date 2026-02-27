@echo off
setlocal

:: 设置代码页为UTF-8
chcp 65001 >nul 2>&1

:: 切换到脚本所在目录的上层目录
cd /d "%~dp0.." 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Cannot change to parent directory
    exit /b 1
)

set "CMD=%~1"
if "%CMD%"=="" set "CMD=serve"

if /i "%CMD%"=="install" goto :cmd_install
if /i "%CMD%"=="build" goto :cmd_build
if /i "%CMD%"=="serve" goto :cmd_serve
if /i "%CMD%"=="clean" goto :cmd_clean
goto :usage

:info
echo [INFO] %*
exit /b 0

:warn
echo [WARN] %*
exit /b 0

:error
echo [ERROR] %* 1>&2
exit /b 0

:check_deps
python --version >nul 2>&1
if %errorlevel% neq 0 (
    call :error Python 3.6+ is required, please install it first
    exit /b 1
)

python -c "import mkdocs" >nul 2>&1
if %errorlevel% neq 0 (
    call :warn mkdocs not found, installing dependencies...
    call :do_install
)
exit /b 0

:do_install
call :info Installing documentation dependencies...
python -m pip install -r requirements-docs.txt
if %errorlevel% equ 0 (
    call :info Dependencies installed successfully
) else (
    call :error Failed to install dependencies
    exit /b 1
)
exit /b 0

:cmd_install
call :do_install
exit /b 0

:cmd_build
call :check_deps
if %errorlevel% neq 0 exit /b %errorlevel%
call :info Syncing examples to docs\examples to fix cross-platform symlink issues...
python scripts\sync_examples.py
call :info Building static site...
python -m mkdocs build --clean
if %errorlevel% equ 0 (
    call :info Build completed -^> _site/
    echo.
    :: Count HTML files
    set "HTML_COUNT=0"
    if exist _site (
        for /f %%A in ('dir /s /b _site\*.html 2^>nul ^| find /c /v ""') do set "HTML_COUNT=%%A"
        echo    Files: %HTML_COUNT% HTML pages
    )
    echo.
    call :info You can deploy _site/ directory or push to ReadTheDocs
) else (
    call :error Build failed
    exit /b 1
)
exit /b 0

:cmd_serve
call :check_deps
if %errorlevel% neq 0 exit /b %errorlevel%
call :info Syncing examples to docs\examples to fix cross-platform symlink issues...
python scripts\sync_examples.py
call :info Starting local preview server...
echo    URL: http://127.0.0.1:8000
echo    Press Ctrl+C to stop
echo.
python -m mkdocs serve -a 0.0.0.0:8000
exit /b 0

:cmd_clean
call :info Cleaning build artifacts...
if exist _site rmdir /s /q _site
if exist docs\examples rmdir /s /q docs\examples
call :info Clean completed
exit /b 0

:usage
echo Usage: %~nx0 {install^|build^|serve^|clean}
echo.
echo   install  Install mkdocs + material theme
echo   build    Build static site to _site/
echo   serve    Local preview (default)
echo   clean    Clean build artifacts
exit /b 1