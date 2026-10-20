"""Polymarket 用の Nautilus 標準アダプターの互換性を検証する。"""

from nautilus_trader.adapters.polymarket import PolymarketDataClientConfig


def test_polymarket_adapter_is_available() -> None:
    """ネットワーク接続や認証情報なしに取引所の初期設定を生成できることを確認する。"""
    assert PolymarketDataClientConfig().http_timeout_secs > 0
