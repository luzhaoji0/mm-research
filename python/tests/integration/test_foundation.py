"""インストール済みの Python、Rust、Nautilus の連携を検証する。"""

from importlib.metadata import version

import nautilus_trader

from mm_research import __version__, _native


def test_native_extension_matches_distribution() -> None:
    """ネイティブ拡張と Python パッケージのバージョンが一致することを確認する。"""
    assert _native.__version__ == __version__


def test_nautilus_engine_is_available() -> None:
    """固定した Nautilus と本プロジェクトのネイティブ拡張を読み込めることを確認する。"""
    assert nautilus_trader.__version__ == version("nautilus-trader") == "2.0.0rc7"
