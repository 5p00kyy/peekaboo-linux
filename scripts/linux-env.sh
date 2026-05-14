#!/usr/bin/env bash

# Source this file before running Swift commands for peekaboo-linux development
# on Linux hosts. It intentionally avoids modifying shell profiles.

if [[ -f "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"
fi

if [[ "$(uname -s)" == "Linux" && ! -e /usr/lib/libncurses.so.6 && -e /usr/lib/libncursesw.so.6 ]]; then
  compat_dir="${PEEKABOO_LINUX_LIBCOMPAT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/peekaboo-linux/libcompat}"
  mkdir -p "$compat_dir"
  ln -sfn /usr/lib/libncursesw.so.6 "$compat_dir/libncurses.so.6"
  case ":${LD_LIBRARY_PATH:-}:" in
    *":$compat_dir:"*) ;;
    *) export LD_LIBRARY_PATH="$compat_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
  esac
fi

hash -r 2>/dev/null || true

