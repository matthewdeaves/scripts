# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a collection of utility scripts created over time. Scripts are standalone tools for various system administration and automation tasks.

## Script Conventions

- Scripts use bash with `set -e` for error handling
- Colored output functions: `print_info`, `print_success`, `print_warn`, `print_error`
- Scripts that need elevated privileges check for sudo access via a `check_sudo` function
- Each script includes a `show_usage` or help function accessible via `help`, `--help`, or `-h`

## Testing Scripts

Scripts are tested manually. Run with `--help` or `help` to see available commands before testing functionality.
