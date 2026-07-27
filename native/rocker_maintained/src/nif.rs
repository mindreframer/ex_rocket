use crate::atoms::{maintained, ok, vsn1};
use rustler::{Encoder, Env, NifResult, Term};

pub fn on_load(_env: Env, _load_info: Term) -> bool {
    true
}

#[rustler::nif]
pub fn lxcode(env: Env) -> NifResult<Term> {
    Ok((ok(), maintained(), vsn1()).encode(env))
}
