@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

:: install.bat — 将 Review Bot 的 Claude Code 配置安装到目标项目
:: 用法: install.bat <project-path> [--full]
:: 示例:
::   install.bat C:\projects\my-app          # 安装 skills + agents + hooks
::   install.bat C:\projects\my-app --full   # 同上 + 安装 Python CLI 工具

if "%~1"=="" (
    echo 用法: %~nx0 ^<project-path^> [--full]
    exit /b 1
)

set "SCRIPT_DIR=%~dp0"
:: 去掉末尾反斜杠
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: 向上两级得到仓库根目录
for %%I in ("%SCRIPT_DIR%\..\.." ) do set "REPO_ROOT=%%~fI"
set "REVIEW_BOT=%REPO_ROOT%\examples\review_bot"

set "TARGET=%~f1"
set "FULL_INSTALL=0"
if /i "%~2"=="--full" set "FULL_INSTALL=1"

:: 验证目标路径
if not exist "%TARGET%\" (
    echo 错误: 目录不存在 — %TARGET%
    exit /b 1
)

set "installed=0"

:: 1. 安装 Skills（.claude\skills\）
echo 安装 Skills ...
for /d %%D in ("%REVIEW_BOT%\.claude\skills\*") do (
    set "skill_name=%%~nxD"
    call :install_file "%%D\SKILL.md" "%TARGET%\.claude\skills\!skill_name!\SKILL.md" ".claude\skills\!skill_name!\SKILL.md"
)

:: 2. 安装 Agents（.claude\agents\）
echo 安装 Agents ...
for %%F in ("%REVIEW_BOT%\.claude\agents\*.md") do (
    set "agent_name=%%~nxF"
    call :install_file "%%F" "%TARGET%\.claude\agents\!agent_name!" ".claude\agents\!agent_name!"
)

:: 3. 安装 Rules（.claude\rules\）
echo 安装 Rules ...
for %%F in ("%REVIEW_BOT%\.claude\rules\*.md") do (
    set "rule_name=%%~nxF"
    call :install_file "%%F" "%TARGET%\.claude\rules\!rule_name!" ".claude\rules\!rule_name!"
)

:: 4. 安装 Hooks（.claude\settings.json）
echo 安装 Hooks ...
call :install_file "%REVIEW_BOT%\.claude\settings.json" "%TARGET%\.claude\settings.json" ".claude\settings.json"

:: 5. 安装 CLAUDE.md
echo 安装 CLAUDE.md ...
call :install_file "%REVIEW_BOT%\CLAUDE.md" "%TARGET%\CLAUDE.md" "CLAUDE.md"

:: 6. 安装 Python CLI（可选）
if "%FULL_INSTALL%"=="1" (
    echo 安装 Python CLI ...
    pip install -e "%REVIEW_BOT%" -q >nul 2>&1
    if !errorlevel! equ 0 (
        echo   review-bot CLI 已安装
        set /a installed+=1
    ) else (
        echo   警告: pip install 失败，请手动运行: pip install -e "%REVIEW_BOT%"
    )
)

echo.
echo 完成 — 安装了 %installed% 个文件到 %TARGET%
echo.
echo 已安装内容:
echo   .claude\skills\*\SKILL.md — Skill 模板（/review-bot, /test）
echo   .claude\agents\*.md      — Agent 定义（security, performance, style, logic）
echo   .claude\rules\*.md       — 项目规则（代码风格、测试要求）
echo   .claude\settings.json    — Hook 配置（commit 自动审查、自动测试）
echo   CLAUDE.md                — 项目级 Agent 指令
if "%FULL_INSTALL%"=="1" (
    echo   review-bot CLI        — Python 工具（diff 解析、报告生成）
)
echo.
echo 在 Claude Code 中输入 /review-bot HEAD~3 开始审查

endlocal
exit /b 0

:: --- 子程序 ---

:install_file
:: %~1 = 源文件, %~2 = 目标文件, %~3 = 显示标签
set "src=%~1"
set "dest=%~2"
set "label=%~3"

:: 创建目标目录
for %%P in ("%dest%") do (
    if not exist "%%~dpP" mkdir "%%~dpP"
)

if exist "%dest%" (
    echo   跳过 %label%（已存在）
) else (
    copy /y "%src%" "%dest%" >nul
    echo   安装 %label%
    set /a installed+=1
)
exit /b 0
