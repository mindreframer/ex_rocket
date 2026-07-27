use crate::atoms::{end_of_iterator, error, maintained, ok, undefined, vsn1};
use crate::options::RockerOptions;
use rocksdb::{Direction, DBIterator, IteratorMode, Options, ReadOptions, WriteBatch, DB};
use rustler::types::list::ListIterator;
use rustler::{Binary, Encoder, Env, NifResult, OwnedBinary, Resource, ResourceArc, Term};
use std::sync::{Mutex, MutexGuard, RwLock, RwLockReadGuard};

pub struct DbResource {
    db: RwLock<DB>,
}

impl Resource for DbResource {}

pub struct IteratorResource {
    iter: Mutex<DBIterator<'static>>,
    _owner: ResourceArc<DbResource>,
}

impl Resource for IteratorResource {}

impl IteratorResource {
    fn lock(&self) -> MutexGuard<'_, DBIterator<'static>> {
        self.iter.lock().unwrap()
    }
}

impl DbResource {
    fn new(db: DB) -> Self {
        Self { db: RwLock::new(db) }
    }

    fn read(&self) -> RwLockReadGuard<'_, DB> {
        self.db.read().unwrap()
    }
}

pub fn on_load(env: Env, _load_info: Term) -> bool {
    env.register::<DbResource>().is_ok() && env.register::<IteratorResource>().is_ok()
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

#[rustler::nif(schedule = "DirtyIo")]
pub fn write_batch<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    operations: Term<'a>,
) -> NifResult<Term<'a>> {
    let operations: ListIterator = operations.decode()?;
    let mut batch = WriteBatch::default();

    for operation in operations {
        let terms = rustler::types::tuple::get_tuple(operation)?;
        let name = terms.first().ok_or(rustler::Error::BadArg)?.atom_to_string()?;
        match name.as_str() {
            "put" if terms.len() == 3 => {
                let key: Binary = terms[1].decode()?;
                let value: Binary = terms[2].decode()?;
                batch.put(key.as_slice(), value.as_slice());
            }
            "delete" if terms.len() == 2 => {
                let key: Binary = terms[1].decode()?;
                batch.delete(key.as_slice());
            }
            _ => return Err(rustler::Error::BadArg),
        }
    }

    let applied = batch.len();
    match resource.read().write(&batch) {
        Ok(()) => Ok((ok(), applied).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn delete_range<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    from: Binary<'a>,
    to: Binary<'a>,
) -> NifResult<Term<'a>> {
    let mut batch = WriteBatch::default();
    batch.delete_range(from.as_slice(), to.as_slice());
    match resource.read().write(&batch) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn multi_get<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    keys: Term<'a>,
) -> NifResult<Term<'a>> {
    let keys: ListIterator = keys.decode()?;
    let keys: NifResult<Vec<Vec<u8>>> = keys
        .map(|term| term.decode::<Binary>().map(|key| key.as_slice().to_vec()))
        .collect();
    let values = resource.read().multi_get(keys?);
    let mut output = Vec::with_capacity(values.len());

    for value in values {
        match value {
            Ok(Some(value)) => {
                let mut binary = OwnedBinary::new(value.len()).ok_or(rustler::Error::BadArg)?;
                binary.as_mut_slice().copy_from_slice(value.as_ref());
                output.push((ok(), binary.release(env)).encode(env));
            }
            Ok(None) => output.push(undefined().encode(env)),
            Err(reason) => output.push((error(), reason.to_string()).encode(env)),
        }
    }
    Ok((ok(), output).encode(env))
}

#[rustler::nif]
pub fn key_may_exist<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    Ok((ok(), resource.read().key_may_exist(key.as_slice())).encode(env))
}

fn iterator_mode<'a>(mode: Term<'a>) -> NifResult<(String, Option<Vec<u8>>, Direction)> {
    let terms = rustler::types::tuple::get_tuple(mode)?;
    let name = terms.first().ok_or(rustler::Error::BadArg)?.atom_to_string()?;
    let key = if name == "from" {
        Some(terms.get(1).ok_or(rustler::Error::BadArg)?.decode::<Binary>()?.as_slice().to_vec())
    } else {
        None
    };
    let direction = match terms.get(2) {
        Some(term) if term.atom_to_string()?.as_str() == "reverse" => Direction::Reverse,
        _ => Direction::Forward,
    };
    Ok((name, key, direction))
}

fn make_iterator_resource(
    owner: ResourceArc<DbResource>,
    iterator: DBIterator<'_>,
) -> ResourceArc<IteratorResource> {
    let iterator = unsafe { std::mem::transmute::<DBIterator<'_>, DBIterator<'static>>(iterator) };
    ResourceArc::new(IteratorResource {
        iter: Mutex::new(iterator),
        _owner: owner,
    })
}

#[rustler::nif]
pub fn iterator<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    mode: Term<'a>,
) -> NifResult<Term<'a>> {
    let (name, key, direction) = iterator_mode(mode)?;
    let guard = resource.read();
    let iterator = match (name.as_str(), key.as_deref()) {
        ("end", _) => guard.iterator(IteratorMode::End),
        ("from", Some(key)) => guard.iterator(IteratorMode::From(key, direction)),
        _ => guard.iterator(IteratorMode::Start),
    };
    let iterator = make_iterator_resource(resource.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif]
pub fn iterator_range<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    mode: Term<'a>,
    from: Term<'a>,
    to: Term<'a>,
    _read_options: Term<'a>,
) -> NifResult<Term<'a>> {
    let mut read_options = ReadOptions::default();
    let from_key = from.decode::<Binary>().ok().map(|value| value.as_slice().to_vec());
    let to_key = to.decode::<Binary>().ok().map(|value| value.as_slice().to_vec());
    match (from_key.as_deref(), to_key.as_deref()) {
        (Some(from), Some(to)) => read_options.set_iterate_range(from..to),
        (Some(from), None) => read_options.set_iterate_range(from..),
        (None, Some(to)) => read_options.set_iterate_range(..to),
        (None, None) => read_options.set_iterate_range(..),
    }

    let (name, key, direction) = iterator_mode(mode)?;
    let guard = resource.read();
    let iterator = match (name.as_str(), key.as_deref()) {
        ("end", _) => guard.iterator_opt(IteratorMode::End, read_options),
        ("from", Some(key)) => guard.iterator_opt(IteratorMode::From(key, direction), read_options),
        _ => guard.iterator_opt(IteratorMode::Start, read_options),
    };
    let iterator = make_iterator_resource(resource.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif]
pub fn prefix_iterator<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    prefix: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let iterator = guard.prefix_iterator(prefix.as_slice());
    let iterator = make_iterator_resource(resource.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif]
pub fn next<'a>(
    env: Env<'a>,
    resource: ResourceArc<IteratorResource>,
) -> NifResult<Term<'a>> {
    match resource.lock().next() {
        None => Ok(end_of_iterator().encode(env)),
        Some(Ok((key, value))) => {
            let mut output_key = OwnedBinary::new(key.len()).ok_or(rustler::Error::BadArg)?;
            output_key.as_mut_slice().copy_from_slice(key.as_ref());
            let mut output_value = OwnedBinary::new(value.len()).ok_or(rustler::Error::BadArg)?;
            output_value.as_mut_slice().copy_from_slice(value.as_ref());
            Ok((ok(), output_key.release(env), output_value.release(env)).encode(env))
        }
        Some(Err(reason)) => Ok((error(), reason.to_string()).encode(env)),
    }
}
