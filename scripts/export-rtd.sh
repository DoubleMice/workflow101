#!/usr/bin/env bash
# export-rtd.sh — 构建 ReadTheDocs 站点（本地预览 / 导出静态文件）
#
# 用法:
#   ./scripts/export-rtd.sh          # 本地预览 (http://127.0.0.1:8000)
#   ./scripts/export-rtd.sh build    # 构建静态站点到 _site/
#   ./scripts/export-rtd.sh install  # 安装依赖
#   ./scripts/export-rtd.sh clean    # 清理构建产物

set -euo pipefail
cd "$(dirname "$0")/.."

ROOT="$(pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

check_deps() {
    if ! command -v python3 &>/dev/null; then
        error "需要 Python 3.10+，请先安装"
        exit 1
    fi
    if ! python3 -c "import mkdocs" &>/dev/null; then
        warn "mkdocs 未安装，正在安装依赖..."
        cmd_install
    fi
}


cmd_install() {
    info "安装文档构建依赖..."
    pip install -r requirements-docs.txt
    info "依赖安装完成"
}

cmd_build() {
    check_deps
    info "同步 examples 到 docs/examples 以解决跨平台软链接问题..."
    python3 scripts/sync_examples.py
    info "构建静态站点..."
    mkdocs build --clean
    info "构建完成 → _site/"
    echo ""
    echo "  文件数: $(find _site -name '*.html' | wc -l | tr -d ' ') 个 HTML 页面"
    echo "  总大小: $(du -sh _site | cut -f1)"
    echo ""
    info "可直接部署 _site/ 目录，或推送到 ReadTheDocs"
}

cmd_serve() {
    check_deps
    info "同步 examples 到 docs/examples 以解决跨平台软链接问题..."
    python3 scripts/sync_examples.py
    info "启动本地预览服务器..."
    echo "  地址: http://127.0.0.1:8000"
    echo "  按 Ctrl+C 停止"
    echo ""
    mkdocs serve
}

cmd_clean() {
    info "清理构建产物..."
    rm -rf _site docs/examples
    info "清理完成"
}

case "${1:-serve}" in
    install) cmd_install ;;
    build)   cmd_build ;;
    serve)   cmd_serve ;;
    clean)   cmd_clean ;;
    *)
        echo "用法: $0 {install|build|serve|clean}"
        echo ""
        echo "  install  安装 mkdocs + material 主题"
        echo "  build    构建静态站点到 _site/"
        echo "  serve    本地预览 (默认)"
        echo "  clean    清理构建产物"
        exit 1
        ;;
esac
