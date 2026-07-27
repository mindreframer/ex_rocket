use crate::atoms::{error, maintained, ok, undefined, vsn1};
use crate::options::RockerOptions;
use rocksdb::{Options, DB};
use rustler::{Binary, Encoder, Env, NifResult, OwnedBinary, Resource, ResourceArc, Term};
use std::sync::{RwLock, RwLockReadGuard};

pub struct DbResource {
    db: RwLock<DB>,
}

impl Resource for DbResource {}

impl DbResource {
    fn new(db: DB) -> Self {
        Self { db: RwLock::new(db) }
    }

    fn read(&self) -> RwLockReadGuard<'_, DB> {
        self.db.read().unwrap()
    }
}

pub fn on_load(env: Env, _load_info: Term) -> bool {
    env.register::<DbResource>().is_ok()
}

#[rustler::nif]
pub fn lxcode(env: Env) -> NifResult<Term> {
    Ok((ok(), maintained(), vsn1()).encode(env))
}

#[rustler::nif]
pub fn latest_sequence_number(
    env: Env,
    resource: ResourceArc<DbResource>,
) -> NifResult<Term> {
    Ok((ok(), resource.read().latest_sequence_number()).encode(env))
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn open(env: Env, path: String, options: RockerOptions) -> NifResult<Term> {
    match DB::open(&Options::from(options), path) {
        Ok(db) => Ok((ok(), ResourceArc::new(DbResource::new(db))).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn open_for_read_only(
    env: Env,
    path: String,
    options: RockerOptions,
) -> NifResult<Term> {
    match DB::open_for_read_only(&Options::from(options), path, false) {
        Ok(db) => Ok((ok(), ResourceArc::new(DbResource::new(db))).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn destroy(env: Env, path: String, options: RockerOptions) -> NifResult<Term> {
    match DB::destroy(&Options::from(options), path) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn repair(env: Env, path: String, options: RockerOptions) -> NifResult<Term> {
    match DB::repair(&Options::from(options), path) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn get_db_path(env: Env, resource: ResourceArc<DbResource>) -> NifResult<Term> {
    Ok((ok(), resource.read().path().display().to_string()).encode(env))
}

#[rustler::nif]
pub fn put<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    key: Binary<'a>,
    value: Binary<'a>,
) -> NifResult<Term<'a>> {
    match resource.read().put(key.as_slice(), value.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn get<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    match resource.read().get(key.as_slice()) {
        Ok(Some(value)) => {
            let mut output = OwnedBinary::new(value.len()).ok_or(rustler::Error::BadArg)?;
            output.as_mut_slice().copy_from_slice(value.as_ref());
            Ok((ok(), output.release(env)).encode(env))
        }
        Ok(None) => Ok(undefined().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn delete<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    match resource.read().delete(key.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}
