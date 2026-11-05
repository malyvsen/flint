# Flint

A [Copier](https://copier.readthedocs.io/) template for bootstrapping new repositories.

## Usage

To create a new repository using `flint`, run `task new -- /path/to/new-repo`.

Flint asks for an application stack and repository size. Python repositories use `uv`. Tauri repositories use React, TypeScript, Rust, and pnpm; a single app lives at the repository root, while a monorepo places its initial app under `apps/`.

## Development

Run `task init` right after cloning the repo, and then `task check` regularly to run all checks.
