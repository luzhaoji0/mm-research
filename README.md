# mm-research

Python と Rust の開発・検証環境です。以下のコマンドはリポジトリのルートで実行します。

## 初期設定

`nix-command` と `flakes` を有効にした Nix が必要です。
Apple Silicon の macOS と、ARM64・x86-64 の Linux に対応しています。

```bash
nix develop
make develop
make hooks
```

`make develop` は依存関係を同期し、Rust のネイティブ拡張を `python/.venv` にインストールします。
Rust のコードを変更した後も実行してください。`make test` と `make check` は再構築を自動で行います。

direnv と nix-direnv を利用する場合は、`direnv allow` で環境の自動読み込みを有効にできます。

## 日常のコマンド

| コマンド | 用途 |
| --- | --- |
| `make help` | 利用できるコマンドを表示する |
| `make sync` | 固定された Python 依存関係のみを同期する |
| `make develop` | 依存関係を同期し、ネイティブ拡張を構築する |
| `make format` | コードと設定ファイルの書式を修正する |
| `make lint` | コード、書式、設定ファイル、Rust 依存関係の規則を検査する |
| `make typecheck` | Pyrefly で Python の型を検査する |
| `make test` | Python と Rust のテストを実行する |
| `make check` | ビルド、静的検査、型検査、コミット前の検査、テストを実行する |
| `make audit` | Rust 依存関係の規則と既知の脆弱性を検査する |
| `make hooks` | コミット前の検査を登録する |
| `make pre-commit` | Git で追跡している全ファイルにコミット前の検査を適用する |
| `make build` | 配布パッケージとソース配布物を `dist/` に生成する |
| `make package-check` | ソース配布物を再構築し、一時環境へのインストールを検証する |

## CPU・CUDA

通常の環境には PyTorch と NumPy を含みません。CPU 用の依存関係を使用する場合は、
各コマンドに `ML_BACKEND=cpu` を指定します。

```bash
make cpu-check ML_BACKEND=cpu
make test ML_BACKEND=cpu
```

CUDA は、対応する NVIDIA ドライバーを備えた x86-64 Linux 上で使用します。
CUDA 用のシェルでは `ML_BACKEND=cuda` が既定値になります。

```bash
nix develop .#cuda
make gpu-check
```

通常の依存構成に戻す場合は `make develop ML_BACKEND=none` を実行します。

## 構成

- `python/`：Python パッケージ、依存関係、テスト。
- `crates/`：Rust の共通処理と Python 向けのネイティブ拡張。

## ライセンス

本リポジトリのコードには [Apache-2.0 ライセンス](LICENSE)を適用します。
依存ライブラリには、それぞれのライセンスが適用されます。
