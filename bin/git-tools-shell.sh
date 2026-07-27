#!/usr/bin/env bash

_redgps_git_tools_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

if ! type -t gc >/dev/null 2>&1; then
  function gc {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" gc "$@"
  }
fi

if ! type -t update_repos >/dev/null 2>&1; then
  function update_repos {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" update_repos "$@"
  }
fi

if ! type -t update_repo >/dev/null 2>&1; then
  function update_repo {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" update_repo "$@"
  }
fi

if ! type -t create_branch >/dev/null 2>&1; then
  function create_branch {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" create_branch "$@"
  }
fi

if ! type -t create_branch_repo >/dev/null 2>&1; then
  function create_branch_repo {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" create_branch_repo "$@"
  }
fi

if ! type -t reset_repo >/dev/null 2>&1; then
  function reset_repo {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" reset_repo "$@"
  }
fi

if ! type -t git_help >/dev/null 2>&1; then
  function git_help {
    bash "$_redgps_git_tools_root/bin/git-tools.sh" shell-help
  }
fi
