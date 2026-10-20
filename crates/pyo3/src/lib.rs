//! Rust ワークスペースを Python から利用するための最小限のインターフェース。

use pyo3::prelude::*;

#[pymodule]
fn _native(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add("__version__", mm_core::VERSION)
}
