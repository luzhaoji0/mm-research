"""ソース配布物を再構築し、作業ツリーの外で配布パッケージを検証する。"""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def run(*args: str, cwd: Path = ROOT) -> None:
    """パッケージ用のコマンドを実行し、失敗時にも出力を保持する。"""
    subprocess.run(args, cwd=cwd, check=True)


def main() -> None:
    """固定された依存関係とソース配布物から再構築したパッケージを検証する。"""
    with (ROOT / "python/pyproject.toml").open("rb") as manifest:
        project_version = tomllib.load(manifest)["project"]["version"]
    sdist = ROOT / "dist" / f"mm_research-{project_version}.tar.gz"

    with tempfile.TemporaryDirectory(prefix="mm-research-package-") as directory:
        scratch = Path(directory)
        rebuilt = scratch / "rebuilt"
        run("uv", "build", "--wheel", "--out-dir", str(rebuilt), str(sdist))
        wheels = list(rebuilt.glob("*.whl"))
        if len(wheels) != 1:
            raise RuntimeError(f"Expected one rebuilt wheel, found {len(wheels)}")

        environment = scratch / "venv"
        interpreter = environment / "bin/python"
        requirements = scratch / "requirements.txt"
        run("uv", "venv", "--python", sys.executable, str(environment), cwd=scratch)
        run(
            "uv",
            "export",
            "--project",
            "python",
            "--locked",
            "--no-default-groups",
            "--no-emit-project",
            "--output-file",
            str(requirements),
        )
        run(
            "uv",
            "pip",
            "sync",
            "--python",
            str(interpreter),
            "--require-hashes",
            str(requirements),
            cwd=scratch,
        )
        run(
            "uv",
            "pip",
            "install",
            "--python",
            str(interpreter),
            "--no-deps",
            str(wheels[0]),
            cwd=scratch,
        )
        run("uv", "pip", "check", "--python", str(interpreter), cwd=scratch)

        # 作業ツリーや利用者の Python 検索パスに依存せず読み込みを検証する
        environment_variables = os.environ.copy()
        environment_variables.pop("PYTHONPATH", None)
        code = """
from importlib.metadata import distribution, version
from pathlib import Path
import mm_research
import mm_research.adapters
import nautilus_trader
from mm_research import _native

assert mm_research.__version__ == _native.__version__
assert nautilus_trader.__version__ == version('nautilus-trader') == '2.0.0rc7'
package = distribution('mm-research')
assert package.metadata['License-Expression'] == 'Apache-2.0'
assert any(str(path).endswith('.dist-info/licenses/LICENSE') for path in package.files or [])
assert Path(mm_research.__file__).parent.joinpath('py.typed').is_file()
assert Path(mm_research.__file__).parent.joinpath('_native.pyi').is_file()
print(f'Installed wheel verified: {mm_research.__file__}')
"""
        subprocess.run(
            [str(interpreter), "-I", "-c", code],
            cwd=scratch,
            env=environment_variables,
            check=True,
        )


if __name__ == "__main__":
    main()
