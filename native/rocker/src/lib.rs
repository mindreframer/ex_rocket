mod atoms;
mod merge;
mod nif;
mod options;
mod read_options;

rustler::init!("Elixir.ExRocket.RustRocksDB", load = nif::on_load);
