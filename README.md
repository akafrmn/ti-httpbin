# ti-httpbin

A Kubernetes and Helm deployment repository with automated pre-commit hooks for code quality.

## Pre-commit Hooks Setup

This repository uses [pre-commit](https://pre-commit.com/) hooks to ensure code quality and consistency. The hooks automatically validate YAML files, check formatting, and validate Helm charts before each commit.

### Prerequisites

- Python 3.x
- pip (Python package manager)
- Helm (for chart validation)

### Installation

1. Install pre-commit:

```bash
pip install pre-commit
```

2. Install the git hook scripts:

```bash
pre-commit install
```

3. (Optional) Run hooks manually on all files:

```bash
pre-commit run --all-files
```

### Configured Hooks

The following hooks are automatically run on each commit:

- **Trailing Whitespace**: Removes trailing whitespace from files
- **End of File Fixer**: Ensures all files end with a newline
- **YAML Syntax Check**: Validates YAML syntax (with support for Helm templates)
- **YAMLlint**: Lints YAML files for style and syntax issues
- **Prettier**: Auto-formats YAML files for consistent styling
- **Helm Lint**: Validates Helm charts structure and syntax
- **Large Files Check**: Prevents accidentally committing large files
- **Merge Conflict Check**: Detects merge conflict markers

### Auto-fixing

Many hooks will automatically fix issues when possible:
- Trailing whitespace is removed
- Missing end-of-file newlines are added
- YAML formatting is standardized

If a hook makes changes, the commit will be aborted so you can review the changes. Simply stage the changes and commit again.

### Manual Usage

To run hooks manually on specific files:

```bash
pre-commit run --files path/to/file.yaml
```

To update hooks to the latest versions:

```bash
pre-commit autoupdate
```

### Skipping Hooks

If you need to skip hooks for a specific commit (not recommended):

```bash
git commit --no-verify
```
