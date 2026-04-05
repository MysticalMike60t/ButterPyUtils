#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  butterpyutils — developer TUI                                             ║
# ║  deps: fzf, pyenv, python 3.x                                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── resolve project root ────────────────────────────────────────────────────
__BPYU_PROJ_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly __BPYU_PROJ_DIR

# ─── config ──────────────────────────────────────────────────────────────────
__BPYU_PYTHON_VERSION="3.12.4"           # override via .python-version or env
__BPYU_VENV_DIR="${__BPYU_PROJ_DIR}/.venv"
__BPYU_LOG_DIR="${__BPYU_PROJ_DIR}/.log"
__BPYU_TMP_DIR="${__BPYU_PROJ_DIR}/.tmp"
__BPYU_REQ_FILE="${__BPYU_PROJ_DIR}/requirements.txt"
__BPYU_REQ_DEV_FILE="${__BPYU_PROJ_DIR}/requirements-dev.txt"
__BPYU_TIMESTAMP="$(date --utc +%Y-%m-%d-%H-%M-%S 2>/dev/null || date -u +%Y-%m-%d-%H-%M-%S)"

# ─── colors ──────────────────────────────────────────────────────────────────
# your pink accent + complementary palette
readonly __BPYU_C_RESET=$'\033[0m'
readonly __BPYU_C_PINK=$'\033[38;2;244;167;185m'       # #f4a7b9
readonly __BPYU_C_GRAY=$'\033[38;2;120;120;120m'
readonly __BPYU_C_WHITE=$'\033[38;2;220;220;220m'
readonly __BPYU_C_GREEN=$'\033[38;2;120;220;140m'
readonly __BPYU_C_YELLOW=$'\033[38;2;240;240;100m'
readonly __BPYU_C_RED=$'\033[38;2;240;80;80m'
readonly __BPYU_C_BLUE=$'\033[38;2;100;160;240m'
readonly __BPYU_C_PURPLE=$'\033[38;2;180;120;240m'
readonly __BPYU_C_DIM=$'\033[2m'
readonly __BPYU_C_BOLD=$'\033[1m'

# ─── logging ─────────────────────────────────────────────────────────────────
__bpyu_log() {
    local level="${1}" ; shift
    local msg="${*}"
    local color
    case "${level}" in
        info)  color="${__BPYU_C_BLUE}"   ;;
        ok)    color="${__BPYU_C_GREEN}"   ;;
        warn)  color="${__BPYU_C_YELLOW}"  ;;
        err)   color="${__BPYU_C_RED}"     ;;
        run)   color="${__BPYU_C_PURPLE}"  ;;
        *)     color="${__BPYU_C_WHITE}"   ;;
    esac
    local prefix="${__BPYU_C_GRAY}[${color}${level}${__BPYU_C_GRAY}]${__BPYU_C_RESET}"
    printf '%b %b\n' "${prefix}" "${msg}" >&2
}

__bpyu_log_to_file() {
    local program="${1}" ; shift
    local content="${*}"
    mkdir -p "${__BPYU_LOG_DIR}"
    local filepath="${__BPYU_LOG_DIR}/${program}_${__BPYU_TIMESTAMP}.log"
    printf '%s\n' "${content}" >> "${filepath}"
    __bpyu_log info "logged to ${__BPYU_C_DIM}${filepath}${__BPYU_C_RESET}"
}

# ─── dependency checks ──────────────────────────────────────────────────────
__bpyu_require() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "${cmd}" &>/dev/null; then
            missing+=("${cmd}")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        __bpyu_log err "missing dependencies: ${__BPYU_C_BOLD}${missing[*]}${__BPYU_C_RESET}"
        return 1
    fi
}

# ─── pretty command display ──────────────────────────────────────────────────
__bpyu_colorize_cmd() {
    local cmd="${1}"
    cmd="${cmd//pyenv /${__BPYU_C_PINK}pyenv${__BPYU_C_RESET} }"
    cmd="${cmd// exec / ${__BPYU_C_YELLOW}exec${__BPYU_C_RESET} }"
    cmd="${cmd//python /${__BPYU_C_BLUE}python${__BPYU_C_RESET} }"
    cmd="${cmd//pip /${__BPYU_C_PURPLE}pip${__BPYU_C_RESET} }"
    cmd="${cmd// -m / ${__BPYU_C_DIM}-m${__BPYU_C_RESET} }"
    cmd="${cmd//pytest/${__BPYU_C_GREEN}pytest${__BPYU_C_RESET}}"
    cmd="${cmd//ruff/${__BPYU_C_YELLOW}ruff${__BPYU_C_RESET}}"
    cmd="${cmd//mypy/${__BPYU_C_BLUE}mypy${__BPYU_C_RESET}}"
    printf '%b' "${cmd}"
}

# ─── core exec wrapper ──────────────────────────────────────────────────────
__bpyu_exec() {
    local description="${1}" ; shift
    local cmd="${*}"

    printf '\n'
    __bpyu_log run "$(__bpyu_colorize_cmd "${cmd}")"
    printf '%b' "${__BPYU_C_GRAY}" ; printf '─%.0s' {1..60} ; printf '%b\n' "${__BPYU_C_RESET}"

    local start_time
    start_time=$(date +%s%N 2>/dev/null || date +%s)

    local exit_code=0
    # shellcheck disable=SC2294
    eval "${cmd}" || exit_code=$?

    local end_time
    end_time=$(date +%s%N 2>/dev/null || date +%s)

    local elapsed="?"
    if [[ "${start_time}" =~ [0-9]{10,} ]] && [[ "${end_time}" =~ [0-9]{10,} ]]; then
        local diff_ns=$(( end_time - start_time ))
        local diff_s=$(( diff_ns / 1000000000 ))
        local diff_ms=$(( (diff_ns % 1000000000) / 1000000 ))
        elapsed="${diff_s}.${diff_ms}s"
    fi

    printf '%b' "${__BPYU_C_GRAY}" ; printf '─%.0s' {1..60} ; printf '%b\n' "${__BPYU_C_RESET}"

    if [[ ${exit_code} -eq 0 ]]; then
        __bpyu_log ok "${description} ${__BPYU_C_DIM}(${elapsed})${__BPYU_C_RESET}"
    else
        __bpyu_log err "${description} failed (exit ${exit_code}) ${__BPYU_C_DIM}(${elapsed})${__BPYU_C_RESET}"
    fi

    return ${exit_code}
}

# ─── venv helpers ────────────────────────────────────────────────────────────
__bpyu_ensure_dirs() {
    mkdir -p "${__BPYU_LOG_DIR}" "${__BPYU_TMP_DIR}"
}

__bpyu_resolve_python_version() {
    if [[ -f "${__BPYU_PROJ_DIR}/.python-version" ]]; then
        __BPYU_PYTHON_VERSION="$(< "${__BPYU_PROJ_DIR}/.python-version")"
    fi
}

__bpyu_venv_active() {
    [[ -n "${VIRTUAL_ENV:-}" ]] && [[ "${VIRTUAL_ENV}" == "${__BPYU_VENV_DIR}" ]]
}

__bpyu_activate_venv() {
    if [[ ! -d "${__BPYU_VENV_DIR}" ]]; then
        __bpyu_log warn "venv not found at ${__BPYU_C_DIM}${__BPYU_VENV_DIR}${__BPYU_C_RESET}"
        return 1
    fi
    # shellcheck disable=SC1091
    source "${__BPYU_VENV_DIR}/bin/activate"
    __bpyu_log ok "venv activated"
}

__bpyu_pip_cmd() {
    # use the venv's python directly — pyenv exec bypasses the activated venv
    # and --require-virtualenv will reject the call since pyenv exec doesn't see VIRTUAL_ENV
    printf '%s' "python -m pip --no-input --disable-pip-version-check --require-virtualenv --no-cache-dir"
}

# ─── fzf menu ────────────────────────────────────────────────────────────────
__bpyu_fzf_menu() {
    local header="${1}" ; shift
    local -a items=("$@")

    if [[ ${#items[@]} -eq 0 ]]; then
        __bpyu_log err "no menu items"
        return 1
    fi

    local selected
    selected=$(
        printf '%s\n' "${items[@]}" | fzf \
            --ansi \
            --no-multi \
            --cycle \
            --layout=reverse \
            --border=rounded \
            --border-label=" ${header} " \
            --border-label-pos=3 \
            --info=hidden \
            --prompt="  " \
            --pointer="▸" \
            --color="fg:#dcdcdc,bg:#0a0a0a,hl:#f4a7b9" \
            --color="fg+:#ffffff,bg+:#1a1a1a,hl+:#f4a7b9" \
            --color="pointer:#f4a7b9,prompt:#f4a7b9,border:#555555" \
            --color="header:#888888,label:#f4a7b9" \
            --height=~40% \
            --margin=1,2
    ) || return 1

    printf '%s' "${selected}"
}

__bpyu_fzf_multi_menu() {
    local header="${1}" ; shift
    local -a items=("$@")

    local selected
    selected=$(
        printf '%s\n' "${items[@]}" | fzf \
            --ansi \
            --multi \
            --cycle \
            --layout=reverse \
            --border=rounded \
            --border-label=" ${header} " \
            --border-label-pos=3 \
            --info=hidden \
            --prompt="  " \
            --pointer="▸" \
            --marker="●" \
            --color="fg:#dcdcdc,bg:#0a0a0a,hl:#f4a7b9" \
            --color="fg+:#ffffff,bg+:#1a1a1a,hl+:#f4a7b9" \
            --color="pointer:#f4a7b9,prompt:#f4a7b9,border:#555555" \
            --color="header:#888888,label:#f4a7b9,marker:#f4a7b9" \
            --height=~40% \
            --margin=1,2
    ) || return 1

    printf '%s' "${selected}"
}

__bpyu_confirm() {
    local prompt="${1:-Continue?}"
    local answer
    printf '%b %b ' "${__BPYU_C_PINK}▸${__BPYU_C_RESET}" "${prompt} ${__BPYU_C_DIM}[y/N]${__BPYU_C_RESET}" >&2
    read -r answer
    [[ "${answer}" =~ ^[Yy]$ ]]
}

# ═════════════════════════════════════════════════════════════════════════════
#  ACTIONS
# ═════════════════════════════════════════════════════════════════════════════

__bpyu_action_env_setup() {
    __bpyu_log info "setting up python ${__BPYU_C_BOLD}${__BPYU_PYTHON_VERSION}${__BPYU_C_RESET}"

    # ensure pyenv has the version
    if ! pyenv versions --bare 2>/dev/null | grep -qxF "${__BPYU_PYTHON_VERSION}"; then
        __bpyu_log warn "python ${__BPYU_PYTHON_VERSION} not installed in pyenv"
        if __bpyu_confirm "Install python ${__BPYU_PYTHON_VERSION} via pyenv?"; then
            __bpyu_exec "pyenv install" "pyenv install ${__BPYU_PYTHON_VERSION}"
        else
            return 1
        fi
    fi

    __bpyu_exec "set local python version" "pyenv local ${__BPYU_PYTHON_VERSION}"
    __bpyu_exec "create venv" "pyenv exec python -m venv \"${__BPYU_VENV_DIR}\""
    __bpyu_activate_venv || return 1
    __bpyu_exec "upgrade pip" "$(__bpyu_pip_cmd) install --upgrade pip setuptools wheel"
    pyenv rehash
    __bpyu_log ok "environment ready"
}

__bpyu_action_install_deps() {
    __bpyu_activate_venv || return 1
    local pip
    pip="$(__bpyu_pip_cmd)"

    local -a targets=()
    [[ -f "${__BPYU_REQ_FILE}" ]]     && targets+=("requirements.txt")
    [[ -f "${__BPYU_REQ_DEV_FILE}" ]] && targets+=("requirements-dev.txt")
    if [[ -f "${__BPYU_PROJ_DIR}/pyproject.toml" ]]; then
        # only offer pyproject installs if it has a build-system defined
        if grep -q '^\[build-system\]' "${__BPYU_PROJ_DIR}/pyproject.toml" 2>/dev/null; then
            targets+=("pyproject.toml (editable)")
            targets+=("pyproject.toml (regular)")
        else
            targets+=("pyproject.toml (deps only)")
        fi
    fi

    if [[ ${#targets[@]} -eq 0 ]]; then
        __bpyu_log warn "no requirements.txt, requirements-dev.txt, or pyproject.toml found"
        return 1
    fi

    local selected
    selected=$(__bpyu_fzf_multi_menu "install from" "${targets[@]}") || return 0

    local log_path="${__BPYU_LOG_DIR}/pip_install_${__BPYU_TIMESTAMP}.log"
    while IFS= read -r target; do
        case "${target}" in
            "requirements.txt")
                __bpyu_exec "install deps" "${pip} install -r \"${__BPYU_REQ_FILE}\" --log \"${log_path}\""
                ;;
            "requirements-dev.txt")
                __bpyu_exec "install dev deps" "${pip} install -r \"${__BPYU_REQ_DEV_FILE}\" --log \"${log_path}\""
                ;;
            "pyproject.toml (editable)")
                __bpyu_exec "install editable" "${pip} install -e \"${__BPYU_PROJ_DIR}\" --log \"${log_path}\""
                ;;
            "pyproject.toml (regular)")
                __bpyu_exec "install from pyproject" "${pip} install \"${__BPYU_PROJ_DIR}\" --log \"${log_path}\""
                ;;
            "pyproject.toml (deps only)")
                # extract optional-dependencies or project.dependencies without building
                __bpyu_log info "pyproject.toml has no [build-system] — installing project dependencies only"
                __bpyu_exec "install project deps" "${pip} install \"${__BPYU_PROJ_DIR}\" --no-build-isolation --log \"${log_path}\"" || {
                    __bpyu_log warn "fallback: try installing dependencies from pyproject.toml manually"
                }
                ;;
        esac
    done <<< "${selected}"

    pyenv rehash
}

__bpyu_action_install_package() {
    __bpyu_activate_venv || return 1
    local pip
    pip="$(__bpyu_pip_cmd)"

    printf '%b %b ' "${__BPYU_C_PINK}▸${__BPYU_C_RESET}" "package name(s):" >&2
    local packages
    read -r packages
    [[ -z "${packages}" ]] && return 0

    local log_path="${__BPYU_LOG_DIR}/pip_install_${__BPYU_TIMESTAMP}.log"
    # shellcheck disable=SC2086
    __bpyu_exec "pip install" "${pip} install ${packages} --log \"${log_path}\""
    pyenv rehash
}

__bpyu_action_freeze() {
    __bpyu_activate_venv || return 1
    local pip
    pip="$(__bpyu_pip_cmd)"

    local target
    target=$(__bpyu_fzf_menu "freeze to" \
        "requirements.txt" \
        "requirements-dev.txt" \
        "stdout (just print)" \
    ) || return 0

    case "${target}" in
        "stdout (just print)")
            eval "${pip} freeze"
            ;;
        *)
            local filepath="${__BPYU_PROJ_DIR}/${target}"
            eval "${pip} freeze" > "${filepath}"
            __bpyu_log ok "frozen to ${__BPYU_C_DIM}${filepath}${__BPYU_C_RESET}"
            ;;
    esac
}

__bpyu_action_clean_venv() {
    __bpyu_activate_venv || return 1
    local pip
    pip="$(__bpyu_pip_cmd)"

    local frozen
    frozen=$(eval "${pip} freeze") || return 1

    if [[ -z "${frozen}" ]]; then
        __bpyu_log info "venv is already clean — no packages installed"
        return 0
    fi

    printf '%b\n' "${__BPYU_C_DIM}${frozen}${__BPYU_C_RESET}" >&2
    __bpyu_log warn "this will uninstall all ${__BPYU_C_BOLD}$(echo "${frozen}" | wc -l)${__BPYU_C_RESET} packages"

    if __bpyu_confirm "Nuke all packages?"; then
        local tmp_file="${__BPYU_TMP_DIR}/to-uninstall.txt"
        printf '%s\n' "${frozen}" > "${tmp_file}"
        __bpyu_exec "uninstall all" "${pip} uninstall -y -r \"${tmp_file}\""
        rm -f "${tmp_file}"
    fi
}

__bpyu_action_nuke_venv() {
    if [[ ! -d "${__BPYU_VENV_DIR}" ]]; then
        __bpyu_log info "no venv found"
        return 0
    fi

    __bpyu_log warn "this will ${__BPYU_C_RED}delete${__BPYU_C_RESET} ${__BPYU_C_DIM}${__BPYU_VENV_DIR}${__BPYU_C_RESET}"
    if __bpyu_confirm "Delete venv entirely?"; then
        rm -rf "${__BPYU_VENV_DIR}"
        __bpyu_log ok "venv removed"
    fi
}

__bpyu_action_lint() {
    __bpyu_activate_venv || return 1

    local -a tools=()
    command -v ruff  &>/dev/null && tools+=("ruff check .")
    command -v mypy  &>/dev/null && tools+=("mypy .")
    command -v black &>/dev/null && tools+=("black --check .")
    command -v isort &>/dev/null && tools+=("isort --check-only .")

    if [[ ${#tools[@]} -eq 0 ]]; then
        __bpyu_log warn "no linters found in venv — install ruff, mypy, black, or isort"
        return 1
    fi

    local selected
    selected=$(__bpyu_fzf_multi_menu "run linters (tab to multi-select)" "${tools[@]}") || return 0

    while IFS= read -r tool; do
        __bpyu_exec "lint: ${tool%% *}" "${tool}" || true
    done <<< "${selected}"
}

__bpyu_action_lint_fix() {
    __bpyu_activate_venv || return 1

    local -a tools=()
    command -v ruff  &>/dev/null && tools+=("ruff check --fix .")
    command -v black &>/dev/null && tools+=("black .")
    command -v isort &>/dev/null && tools+=("isort .")

    if [[ ${#tools[@]} -eq 0 ]]; then
        __bpyu_log warn "no fixers found in venv"
        return 1
    fi

    local selected
    selected=$(__bpyu_fzf_multi_menu "run fixers (tab to multi-select)" "${tools[@]}") || return 0

    while IFS= read -r tool; do
        __bpyu_exec "fix: ${tool%% *}" "${tool}" || true
    done <<< "${selected}"
}

__bpyu_action_test() {
    __bpyu_activate_venv || return 1

    if ! command -v pytest &>/dev/null; then
        __bpyu_log warn "pytest not found in venv"
        return 1
    fi

    local mode
    mode=$(__bpyu_fzf_menu "test mode" \
        "all tests" \
        "verbose (-v)" \
        "last failed (--lf)" \
        "with coverage (--cov)" \
        "pick path" \
    ) || return 0

    case "${mode}" in
        "all tests")          __bpyu_exec "pytest" "pytest" ;;
        "verbose (-v)")       __bpyu_exec "pytest" "pytest -v" ;;
        "last failed (--lf)") __bpyu_exec "pytest" "pytest --lf" ;;
        "with coverage (--cov)")
            local pkg_name
            pkg_name=$(basename "${__BPYU_PROJ_DIR}")
            __bpyu_exec "pytest+cov" "pytest --cov=\"${pkg_name}\" --cov-report=term-missing"
            ;;
        "pick path")
            printf '%b %b ' "${__BPYU_C_PINK}▸${__BPYU_C_RESET}" "test path:" >&2
            local test_path
            read -r test_path
            [[ -n "${test_path}" ]] && __bpyu_exec "pytest" "pytest \"${test_path}\""
            ;;
    esac
}

__bpyu_action_shell() {
    __bpyu_activate_venv || return 1
    __bpyu_log info "dropping into python shell — ${__BPYU_C_DIM}exit() to return${__BPYU_C_RESET}"

    local shell_cmd="python"
    command -v ipython &>/dev/null && shell_cmd="ipython"
    command -v ptpython &>/dev/null && shell_cmd="ptpython"

    __bpyu_exec "python shell" "${shell_cmd}"
}

__bpyu_action_env_info() {
    printf '\n'
    local -A info=(
        ["project"]="${__BPYU_PROJ_DIR}"
        ["python target"]="${__BPYU_PYTHON_VERSION}"
        ["venv"]="${__BPYU_VENV_DIR}"
        ["venv exists"]="$( [[ -d "${__BPYU_VENV_DIR}" ]] && echo "yes" || echo "no" )"
        ["venv active"]="$( __bpyu_venv_active && echo "yes" || echo "no" )"
        ["log dir"]="${__BPYU_LOG_DIR}"
    )

    # active python
    if __bpyu_venv_active || [[ -d "${__BPYU_VENV_DIR}" ]]; then
        # shellcheck disable=SC1091
        [[ -f "${__BPYU_VENV_DIR}/bin/activate" ]] && source "${__BPYU_VENV_DIR}/bin/activate" 2>/dev/null
        info["python path"]="$(command -v python 2>/dev/null || echo 'n/a')"
        info["python version"]="$(python --version 2>/dev/null || echo 'n/a')"
        info["pip version"]="$(python -m pip --version 2>/dev/null | awk '{print $2}' || echo 'n/a')"
        info["packages"]="$(python -m pip freeze 2>/dev/null | wc -l || echo '?')"
    fi

    # deterministic key order
    local -a key_order=(
        "project" "python target" "venv" "venv exists" "venv active"
        "python path" "python version" "pip version" "packages" "log dir"
    )

    for key in "${key_order[@]}"; do
        [[ -z "${info[${key}]+set}" ]] && continue
        printf '  %b%-16s%b %s\n' "${__BPYU_C_PINK}" "${key}" "${__BPYU_C_RESET}" "${info[${key}]}"
    done
    printf '\n'
}

__bpyu_action_clean_logs() {
    if [[ ! -d "${__BPYU_LOG_DIR}" ]]; then
        __bpyu_log info "no log directory"
        return 0
    fi

    local count
    count=$(find "${__BPYU_LOG_DIR}" -type f -name '*.log' 2>/dev/null | wc -l)

    if [[ "${count}" -eq 0 ]]; then
        __bpyu_log info "no log files"
        return 0
    fi

    __bpyu_log info "${count} log file(s) in ${__BPYU_C_DIM}${__BPYU_LOG_DIR}${__BPYU_C_RESET}"
    if __bpyu_confirm "Delete all logs?"; then
        rm -f "${__BPYU_LOG_DIR}"/*.log
        __bpyu_log ok "logs cleaned"
    fi
}

__bpyu_action_run_script() {
    __bpyu_activate_venv || return 1

    # find python files, let user pick
    local -a scripts=()
    while IFS= read -r -d '' f; do
        scripts+=("${f#"${__BPYU_PROJ_DIR}/"}")
    done < <(find "${__BPYU_PROJ_DIR}" -maxdepth 3 -name '*.py' \
        -not -path '*/.venv/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/.git/*' \
        -print0 2>/dev/null | sort -z)

    if [[ ${#scripts[@]} -eq 0 ]]; then
        __bpyu_log warn "no .py files found"
        return 1
    fi

    local selected
    selected=$(__bpyu_fzf_menu "run script" "${scripts[@]}") || return 0
    __bpyu_exec "run ${selected}" "python \"${__BPYU_PROJ_DIR}/${selected}\""
}

# ═════════════════════════════════════════════════════════════════════════════
#  MAIN MENU
# ═════════════════════════════════════════════════════════════════════════════

__bpyu_banner() {
    printf '%b' "${__BPYU_C_PINK}"
    cat << 'BANNER'
    ╔═══════════════════════════════════════╗
    ║       butterpyutils  ·  dev tui       ║
    ╚═══════════════════════════════════════╝
BANNER
    printf '%b' "${__BPYU_C_RESET}"
}

__bpyu_main() {
    __bpyu_require fzf pyenv || return 1
    __bpyu_ensure_dirs
    __bpyu_resolve_python_version

    __bpyu_banner

    # menu items — icon · label · description
    local -a menu_items=(
        "  env setup         │  create venv + install pyenv python"
        "  install deps      │  install from requirements / pyproject"
        "  install package   │  pip install <package>"
        "  freeze            │  pip freeze → requirements"
        "  clean packages    │  uninstall all pip packages"
        "  nuke venv         │  delete .venv entirely"
        "  lint              │  run ruff / mypy / black / isort"
        "  lint fix          │  auto-fix with ruff / black / isort"
        "  test              │  run pytest"
        "  run script        │  pick and run a .py file"
        "  python shell      │  interactive python / ipython"
        "  env info          │  show project & venv details"
        "  clean logs        │  delete .log/*.log files"
        "  quit              │  exit"
    )

    while true; do
        local selection
        selection=$(__bpyu_fzf_menu "butterpyutils" "${menu_items[@]}") || break

        # extract action name between first and │
        local action
        action=$(printf '%s' "${selection}" | sed 's/^[^a-z]*//' | sed 's/ *│.*//' | tr -s ' ')

        case "${action}" in
            "env setup")        __bpyu_action_env_setup        ;;
            "install deps")     __bpyu_action_install_deps     ;;
            "install package")  __bpyu_action_install_package  ;;
            "freeze")           __bpyu_action_freeze           ;;
            "clean packages")   __bpyu_action_clean_venv       ;;
            "nuke venv")        __bpyu_action_nuke_venv        ;;
            "lint")             __bpyu_action_lint             ;;
            "lint fix")         __bpyu_action_lint_fix         ;;
            "test")             __bpyu_action_test             ;;
            "run script")       __bpyu_action_run_script       ;;
            "python shell")     __bpyu_action_shell            ;;
            "env info")         __bpyu_action_env_info         ;;
            "clean logs")       __bpyu_action_clean_logs       ;;
            "quit")             break                          ;;
            *)
                __bpyu_log warn "unknown action: ${action}"
                ;;
        esac

        # pause before returning to menu
        printf '\n%b' "${__BPYU_C_DIM}  press enter to continue...${__BPYU_C_RESET}" >&2
        read -r
    done

    printf '\n'
    __bpyu_log info "bye"
}

# ─── entrypoint ──────────────────────────────────────────────────────────────
# allow sourcing without auto-running (for testing individual functions)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    __bpyu_main "$@"
fi
