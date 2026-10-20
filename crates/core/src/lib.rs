//! 研究処理と実行環境で共有する Rust の共通処理。

/// Python 向けのネイティブ拡張で公開する Rust ワークスペースのバージョン。
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
