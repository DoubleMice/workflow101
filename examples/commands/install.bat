@echo off
setlocal enabledelayedexpansion

:: install.bat — Install Review Bot Claude Code config to target project
:: Usage: install.bat <project-path> [--full]

if "%~1"=="" (
    echo Usage: %~nx0 ^<project-path^> [--full]
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

for %%I in ("%SCRIPT_DIR%\..\.." ) do set "REPO_ROOT=%%~fI"
set "REVIEW_BOT=%REPO_ROOT%\examples\review_bot"

set "TARGET=%~f1"
set "FULL_INSTALL=0"
if /i "%~2"=="--full" set "FULL_INSTALL=1"

if not exist "%TARGET%\" (
    echo ERROR: directory not found — %TARGET%
    exit /b 1
)

set "installed=0"

:: 1. Skills
echo Installing Skills ...
for /d %%D in ("%REVIEW_BOT%\.claude\skills\*") do (
    set "skill_name=%%~nxD"
    call :install_file "%%D\SKILL.md" "%TARGET%\.claude\skills\!skill_name!\SKILL.md" ".claude\skills\!skill_name!\SKILL.md"
)

:: 2. Agents
echo Installing Agents ...
for %%F in ("%REVIEW_BOT%\.claude\agents\*.md") do (
    set "agent_name=%%~nxF"
    call :install_file "%%F" "%TARGET%\.claude\agents\!agent_name!" ".claude\agents\!agent_name!"
)

:: 3. Rules
echo Installing Rules ...
for %%F in ("%REVIEW_BOT%\.claude\rules\*.md") do (
    set "rule_name=%%~nxF"
    call :install_file "%%F" "%TARGET%\.claude\rules\!rule_name!" ".claude\rules\!rule_name!"
)

:: 4. Hooks
echo Installing Hooks ...
call :install_file "%REVIEW_BOT%\.claude\settings.json" "%TARGET%\.claude\settings.json" ".claude\settings.json"

:: 5. CLAUDE.md
echo Installing CLAUDE.md ...
call :install_file "%REVIEW_BOT%\CLAUDE.md" "%TARGET%\CLAUDE.md" "CLAUDE.md"

:: 6. Python CLI (optional)
if "%FULL_INSTALL%"=="1" (
    echo Installing Python CLI ...
    pip install -e "%REVIEW_BOT%" -q >nul 2>&1
    if !errorlevel! equ 0 (
        echo   review-bot CLI installed
        set /a installed+=1
    ) else (
        echo   WARNING: pip install failed. Run manually: pip install -e "%REVIEW_BOT%"
    )
)

echo.
echo Done — installed %installed% file(s) to %TARGET%
echo.
echo Installed:
echo   .claude\skills\*\SKILL.md — Skill templates (/review-bot, /test)
echo   .claude\agents\*.md      — Agent definitions (security, performance, style, logic)
echo   .claude\rules\*.md       — Project rules (code style, testing)
echo   .claude\settings.json    — Hook config (auto-review on commit)
echo   CLAUDE.md                — Project-level agent instructions
if "%FULL_INSTALL%"=="1" (
    echo   review-bot CLI        — Python tools (diff parser, report generator)
)
echo.
echo Run /review-bot HEAD~3 in Claude Code to start a review

endlocal
exit /b 0

:: --- subroutine ---

:install_file
:: %~1 = source, %~2 = destination, %~3 = display label
set "src=%~1"
set "dest=%~2"
set "label=%~3"

for %%P in ("%dest%") do (
    if not exist "%%~dpP" mkdir "%%~dpP"
)

if exist "%dest%" (
    echo   skip %label% (exists)
) else (
    copy /y "%src%" "%dest%" >nul
    echo   installed %label%
    set /a installed+=1
)
exit /b 0
