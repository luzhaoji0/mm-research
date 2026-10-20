.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

export UV_PYTHON_DOWNLOADS := never
export PYTHONNOUSERSITE := 1

ML_BACKEND ?= $(if $(MM_ML_BACKEND),$(MM_ML_BACKEND),none)
PYTHON := $(CURDIR)/python/.venv/bin/python
UV_RUN := uv run --project python --no-sync
SYNC_FLAGS := --locked --group test --no-install-project

ifeq ($(ML_BACKEND),cpu)
SYNC_FLAGS += --extra cpu
else ifeq ($(ML_BACKEND),cuda)
SYNC_FLAGS += --extra cuda
else ifneq ($(ML_BACKEND),none)
$(error ML_BACKEND must be none, cpu, or cuda)
endif

.PHONY: help sync develop format lint typecheck test check audit pre-commit hooks build package-check cpu-check gpu-check

help:
	@printf '%s\n' \
	  'nix develop 内で実行してください。Linux x86-64 の CUDA 環境は nix develop .#cuda です。' \
	  'make sync          固定された依存関係を同期する（ML_BACKEND=none|cpu|cuda）' \
	  'make develop       依存関係を同期し、編集用の Rust ネイティブ拡張を構築する' \
	  'make format        Python、Rust、TOML、Nix、YAML を整形する' \
	  'make lint          コード、書式、設定ファイルを検査する' \
	  'make typecheck     Pyrefly で Python の型を検査する' \
	  'make test          Python と Rust のテストを構築・実行する' \
	  'make check         ローカルの検査とテストを一式実行する' \
	  'make audit         Rust 依存関係の規則と既知の脆弱性を検査する' \
	  'make hooks         コミット前の検査を登録する' \
	  'make pre-commit    追跡対象の全ファイルを検査する' \
	  'make build         配布用パッケージとソース配布物を構築する' \
	  'make package-check ソース配布物を再構築し、インストール結果を検証する' \
	  'make cpu-check     CPU のテンソル演算を検証する（ML_BACKEND=cpu）' \
	  'make gpu-check     CUDA のテンソル演算を検証する（ML_BACKEND=cuda）'

sync:
ifeq ($(ML_BACKEND),cuda)
	@test "$$(uname -s)/$$(uname -m)" = Linux/x86_64 || { \
	  printf '%s\n' 'The CUDA profile requires Linux x86-64.' >&2; exit 1; }
endif
	uv sync --project python $(SYNC_FLAGS)

develop: sync
	cd python && VIRTUAL_ENV="$(CURDIR)/python/.venv" PYO3_PYTHON="$(PYTHON)" \
	  maturin develop --locked

format:
	ruff check --fix --config python/pyproject.toml python
	ruff format --config python/pyproject.toml python
	cargo fmt --all
	taplo format
	nixfmt flake.nix
	yamlfmt .pre-commit-config.yaml .yamllint.yaml .yamlfmt .github

lint:
	ruff check --config python/pyproject.toml python
	ruff format --check --config python/pyproject.toml python
	cargo fmt --all -- --check
	cargo clippy --locked --workspace --all-targets -- -D warnings
	taplo format --check
	nixfmt --check flake.nix
	actionlint
	typos
	yamlfmt -lint .pre-commit-config.yaml .yamllint.yaml .yamlfmt .github
	yamllint --strict .pre-commit-config.yaml .yamllint.yaml .yamlfmt .github
	cargo deny --locked check bans licenses sources

audit:
	cargo deny --locked check

typecheck:
	cd python && pyrefly check --python-interpreter-path "$(PYTHON)"

test: develop
	cargo test --locked --workspace
	cd python && .venv/bin/python -m pytest

hooks:
	prek install

pre-commit:
	prek run --all-files

# make -j でもビルドと整形が競合しないよう、各処理を順番に実行する
check:
	$(MAKE) develop
	$(MAKE) lint
	$(MAKE) typecheck
	$(MAKE) pre-commit
	$(MAKE) test

build:
	cd python && PYO3_PYTHON="$${UV_PYTHON:-python3}" \
	  maturin build --release --locked --out ../dist
	cd python && uv build --sdist --out-dir ../dist

package-check: build
	"$${UV_PYTHON:-python3}" python/check_packaging.py

cpu-check: develop
	@test "$(ML_BACKEND)" = cpu || { printf '%s\n' 'Use ML_BACKEND=cpu.' >&2; exit 1; }
	$(UV_RUN) python -c 'import torch; assert torch.version.cuda is None; \
	  x = torch.ones((2, 2)); assert (x @ x).numpy().sum() == 8; print(f"CPU: {torch.__version__}")'

gpu-check: develop
	@test "$(ML_BACKEND)" = cuda || { printf '%s\n' 'Use ML_BACKEND=cuda.' >&2; exit 1; }
	$(UV_RUN) python -c 'import torch; assert torch.cuda.is_available(); \
	  x = torch.ones((2, 2), device="cuda"); assert (x @ x).sum().item() == 8; \
	  print(f"CUDA {torch.version.cuda}: {torch.cuda.get_device_name()}")'
