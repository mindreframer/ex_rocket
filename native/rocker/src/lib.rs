mod atoms;
mod merge;
mod nif;
mod options;
mod read_options;
mod write_options;

rustler::init!("Elixir.ExRocket", load = nif::on_load);
