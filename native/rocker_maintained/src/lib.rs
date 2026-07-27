mod atoms;
mod nif;
mod options;

rustler::init!("Elixir.ExRocket.RustRocksDB", load = nif::on_load);
