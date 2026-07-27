mod atoms;
mod nif;

rustler::init!(
    "Elixir.ExRocket.RustRocksDB",
    [nif::lxcode],
    load = nif::on_load
);
