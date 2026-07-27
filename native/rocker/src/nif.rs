use crate::atoms::{backup, end_of_iterator, error, ok, snap, undefined, unknown_cf, vsn1};
use crate::options::RockerOptions;
use crate::read_options::RockerReadOptions;
use rocksdb::{
    DB, DBIterator, Direction, IteratorMode, Options, ReadOptions, Snapshot, WriteBatch,
    backup::{BackupEngine, BackupEngineOptions, RestoreOptions},
    checkpoint::Checkpoint,
};
use rustler::types::list::ListIterator;
use rustler::{Binary, Encoder, Env, NifResult, OwnedBinary, Resource, ResourceArc, Term};
use std::sync::{Mutex, MutexGuard, RwLock, RwLockReadGuard, RwLockWriteGuard};

pub struct DbResource {
    db: RwLock<DB>,
}

impl Resource for DbResource {}

pub struct SnapshotResource {
    snapshot: Mutex<Snapshot<'static>>,
    owner: ResourceArc<DbResource>,
}

impl Resource for SnapshotResource {}

impl SnapshotResource {
    fn lock(&self) -> MutexGuard<'_, Snapshot<'static>> {
        self.snapshot.lock().unwrap()
    }
}

pub struct IteratorResource {
    iter: Mutex<DBIterator<'static>>,
    _owner: ResourceArc<DbResource>,
    _snapshot_owner: Option<ResourceArc<SnapshotResource>>,
}

impl Resource for IteratorResource {}

impl IteratorResource {
    fn lock(&self) -> MutexGuard<'_, DBIterator<'static>> {
        self.iter.lock().unwrap()
    }
}

impl DbResource {
    fn new(db: DB) -> Self {
        Self {
            db: RwLock::new(db),
        }
    }

    fn read(&self) -> RwLockReadGuard<'_, DB> {
        self.db.read().unwrap()
    }

    fn write(&self) -> RwLockWriteGuard<'_, DB> {
        self.db.write().unwrap()
    }
}

pub fn on_load(env: Env, _load_info: Term) -> bool {
    env.register::<DbResource>().is_ok()
        && env.register::<SnapshotResource>().is_ok()
        && env.register::<IteratorResource>().is_ok()
}

#[rustler::nif]
pub fn lxcode(env: Env) -> NifResult<Term> {
    Ok((ok(), vsn1()).encode(env))
}

#[rustler::nif]
pub fn latest_sequence_number(env: Env, resource: ResourceArc<DbResource>) -> NifResult<Term> {
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
pub fn open_for_read_only(env: Env, path: String, options: RockerOptions) -> NifResult<Term> {
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

#[rustler::nif]
pub fn merge<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    key: Binary<'a>,
    operand: Binary<'a>,
) -> NifResult<Term<'a>> {
    match resource.read().merge(key.as_slice(), operand.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn merge_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    key: Binary<'a>,
    operand: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match guard.merge_cf(cf, key.as_slice(), operand.as_slice()) {
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
    let guard = resource.read();
    let mut batch = WriteBatch::default();

    for operation in operations {
        let terms = rustler::types::tuple::get_tuple(operation)?;
        let name = terms
            .first()
            .ok_or(rustler::Error::BadArg)?
            .atom_to_string()?;
        match name.as_str() {
            "put" if terms.len() == 3 => {
                let key: Binary = terms[1].decode()?;
                let value: Binary = terms[2].decode()?;
                batch.put(key.as_slice(), value.as_slice());
            }
            "delete" if terms.len() >= 2 => {
                let key: Binary = terms[1].decode()?;
                batch.delete(key.as_slice());
            }
            "put_cf" if terms.len() == 4 => {
                let cf_name: String = terms[1].decode()?;
                let key: Binary = terms[2].decode()?;
                let value: Binary = terms[3].decode()?;
                let cf = guard.cf_handle(&cf_name).ok_or(rustler::Error::BadArg)?;
                batch.put_cf(cf, key.as_slice(), value.as_slice());
            }
            "delete_cf" if terms.len() >= 3 => {
                let cf_name: String = terms[1].decode()?;
                let key: Binary = terms[2].decode()?;
                let cf = guard.cf_handle(&cf_name).ok_or(rustler::Error::BadArg)?;
                batch.delete_cf(cf, key.as_slice());
            }
            "merge" if terms.len() == 3 => {
                let key: Binary = terms[1].decode()?;
                let operand: Binary = terms[2].decode()?;
                batch.merge(key.as_slice(), operand.as_slice());
            }
            "merge_cf" if terms.len() == 4 => {
                let cf_name: String = terms[1].decode()?;
                let key: Binary = terms[2].decode()?;
                let operand: Binary = terms[3].decode()?;
                let cf = guard.cf_handle(&cf_name).ok_or(rustler::Error::BadArg)?;
                batch.merge_cf(cf, key.as_slice(), operand.as_slice());
            }
            _ => return Err(rustler::Error::BadArg),
        }
    }

    let applied = batch.len();
    match guard.write(&batch) {
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

#[rustler::nif(schedule = "DirtyIo")]
pub fn create_cf(
    env: Env,
    resource: ResourceArc<DbResource>,
    name: String,
    options: RockerOptions,
) -> NifResult<Term> {
    match resource.write().create_cf(name, &Options::from(options)) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

fn decode_cf_names(term: Term<'_>) -> NifResult<Vec<String>> {
    term.decode::<ListIterator>()?
        .map(|name| name.decode())
        .collect()
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn open_cf<'a>(
    env: Env<'a>,
    path: String,
    names: Term<'a>,
    options: RockerOptions,
) -> NifResult<Term<'a>> {
    match DB::open_cf(&Options::from(options), path, decode_cf_names(names)?) {
        Ok(db) => Ok((ok(), ResourceArc::new(DbResource::new(db))).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn open_cf_for_read_only<'a>(
    env: Env<'a>,
    path: String,
    names: Term<'a>,
    options: RockerOptions,
) -> NifResult<Term<'a>> {
    match DB::open_cf_for_read_only(
        &Options::from(options),
        path,
        decode_cf_names(names)?,
        false,
    ) {
        Ok(db) => Ok((ok(), ResourceArc::new(DbResource::new(db))).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn list_cf(env: Env, path: String, options: RockerOptions) -> NifResult<Term> {
    match DB::list_cf(&Options::from(options), path) {
        Ok(names) => Ok((ok(), names).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn drop_cf(env: Env, resource: ResourceArc<DbResource>, name: String) -> NifResult<Term> {
    match resource.write().drop_cf(&name) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn put_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    key: Binary<'a>,
    value: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match guard.put_cf(cf, key.as_slice(), value.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn get_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match guard.get_cf(cf, key.as_slice()) {
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
pub fn delete_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match guard.delete_cf(cf, key.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn delete_range_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    from: Binary<'a>,
    to: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match guard.delete_range_cf(cf, from.as_slice(), to.as_slice()) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn multi_get_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    keys: Term<'a>,
) -> NifResult<Term<'a>> {
    let decoded: NifResult<Vec<(String, Vec<u8>)>> = keys
        .decode::<ListIterator>()?
        .map(|item| {
            let tuple = rustler::types::tuple::get_tuple(item)?;
            if tuple.len() != 2 {
                return Err(rustler::Error::BadArg);
            }
            Ok((
                tuple[0].decode()?,
                tuple[1].decode::<Binary>()?.as_slice().to_vec(),
            ))
        })
        .collect();
    let decoded = decoded?;
    let guard = resource.read();
    let mut requests = Vec::with_capacity(decoded.len());
    for (name, key) in &decoded {
        let Some(cf) = guard.cf_handle(name) else {
            return Ok((error(), unknown_cf()).encode(env));
        };
        requests.push((cf, key.as_slice()));
    }
    let values = guard.multi_get_cf(requests);
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
pub fn key_may_exist_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    Ok((ok(), guard.key_may_exist_cf(cf, key.as_slice())).encode(env))
}

fn iterator_mode<'a>(mode: Term<'a>) -> NifResult<(String, Option<Vec<u8>>, Direction)> {
    let terms = rustler::types::tuple::get_tuple(mode)?;
    let name = terms
        .first()
        .ok_or(rustler::Error::BadArg)?
        .atom_to_string()?;
    let key = if name == "from" {
        Some(
            terms
                .get(1)
                .ok_or(rustler::Error::BadArg)?
                .decode::<Binary>()?
                .as_slice()
                .to_vec(),
        )
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
        _snapshot_owner: None,
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
    read_options: RockerReadOptions,
) -> NifResult<Term<'a>> {
    let mut read_options = ReadOptions::from(read_options);
    let from_key = from
        .decode::<Binary>()
        .ok()
        .map(|value| value.as_slice().to_vec());
    let to_key = to
        .decode::<Binary>()
        .ok()
        .map(|value| value.as_slice().to_vec());
    match (from_key.as_deref(), to_key.as_deref()) {
        (Some(from), Some(to)) => read_options.set_iterate_range(from..to),
        (Some(from), None) => read_options.set_iterate_range(from..),
        (None, Some(to)) => read_options.set_iterate_range(..to),
        (None, None) => {}
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
pub fn iterator_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    mode: Term<'a>,
) -> NifResult<Term<'a>> {
    let (mode_name, key, direction) = iterator_mode(mode)?;
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    let iterator = match (mode_name.as_str(), key.as_deref()) {
        ("end", _) => guard.iterator_cf(cf, IteratorMode::End),
        ("from", Some(key)) => guard.iterator_cf(cf, IteratorMode::From(key, direction)),
        _ => guard.iterator_cf(cf, IteratorMode::Start),
    };
    let iterator = make_iterator_resource(resource.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif]
pub fn prefix_iterator_cf<'a>(
    env: Env<'a>,
    resource: ResourceArc<DbResource>,
    name: String,
    prefix: Binary<'a>,
) -> NifResult<Term<'a>> {
    let guard = resource.read();
    let Some(cf) = guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    let iterator = guard.prefix_iterator_cf(cf, prefix.as_slice());
    let iterator = make_iterator_resource(resource.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

fn decode_snapshot(resource: Term<'_>) -> NifResult<ResourceArc<SnapshotResource>> {
    let terms = rustler::types::tuple::get_tuple(resource)?;
    if terms.len() != 3 {
        return Err(rustler::Error::BadArg);
    }
    terms[2].decode()
}

#[rustler::nif]
pub fn snapshot(env: Env, resource: ResourceArc<DbResource>) -> NifResult<Term> {
    let guard = resource.read();
    let snapshot = guard.snapshot();
    let snapshot = unsafe { std::mem::transmute::<Snapshot<'_>, Snapshot<'static>>(snapshot) };
    drop(guard);
    let snapshot_resource = ResourceArc::new(SnapshotResource {
        snapshot: Mutex::new(snapshot),
        owner: resource.clone(),
    });
    Ok((ok(), (snap(), resource, snapshot_resource)).encode(env))
}

#[rustler::nif]
pub fn snapshot_get<'a>(env: Env<'a>, resource: Term<'a>, key: Binary<'a>) -> NifResult<Term<'a>> {
    match decode_snapshot(resource)?.lock().get(key.as_slice()) {
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
pub fn snapshot_get_cf<'a>(
    env: Env<'a>,
    resource: Term<'a>,
    name: String,
    key: Binary<'a>,
) -> NifResult<Term<'a>> {
    let snapshot = decode_snapshot(resource)?;
    let db_guard = snapshot.owner.read();
    let Some(cf) = db_guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    match snapshot.lock().get_cf(cf, key.as_slice()) {
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
pub fn snapshot_multi_get<'a>(
    env: Env<'a>,
    resource: Term<'a>,
    keys: Term<'a>,
) -> NifResult<Term<'a>> {
    let keys: NifResult<Vec<Vec<u8>>> = keys
        .decode::<ListIterator>()?
        .map(|term| term.decode::<Binary>().map(|key| key.as_slice().to_vec()))
        .collect();
    let snapshot = decode_snapshot(resource)?;
    let values = snapshot.lock().multi_get(keys?);
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
pub fn snapshot_multi_get_cf<'a>(
    env: Env<'a>,
    resource: Term<'a>,
    keys: Term<'a>,
) -> NifResult<Term<'a>> {
    let decoded: NifResult<Vec<(String, Vec<u8>)>> = keys
        .decode::<ListIterator>()?
        .map(|item| {
            let tuple = rustler::types::tuple::get_tuple(item)?;
            if tuple.len() != 2 {
                return Err(rustler::Error::BadArg);
            }
            Ok((
                tuple[0].decode()?,
                tuple[1].decode::<Binary>()?.as_slice().to_vec(),
            ))
        })
        .collect();
    let decoded = decoded?;
    let snapshot = decode_snapshot(resource)?;
    let db_guard = snapshot.owner.read();
    let mut requests = Vec::with_capacity(decoded.len());
    for (name, key) in &decoded {
        let Some(cf) = db_guard.cf_handle(name) else {
            return Ok((error(), unknown_cf()).encode(env));
        };
        requests.push((cf, key.as_slice()));
    }
    let values = snapshot.lock().multi_get_cf(requests);
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

fn make_snapshot_iterator_resource(
    snapshot: ResourceArc<SnapshotResource>,
    iterator: DBIterator<'_>,
) -> ResourceArc<IteratorResource> {
    let iterator = unsafe { std::mem::transmute::<DBIterator<'_>, DBIterator<'static>>(iterator) };
    ResourceArc::new(IteratorResource {
        iter: Mutex::new(iterator),
        _owner: snapshot.owner.clone(),
        _snapshot_owner: Some(snapshot),
    })
}

#[rustler::nif]
pub fn snapshot_iterator<'a>(
    env: Env<'a>,
    resource: Term<'a>,
    mode: Term<'a>,
) -> NifResult<Term<'a>> {
    let snapshot = decode_snapshot(resource)?;
    let (name, key, direction) = iterator_mode(mode)?;
    let guard = snapshot.lock();
    let iterator = match (name.as_str(), key.as_deref()) {
        ("end", _) => guard.iterator(IteratorMode::End),
        ("from", Some(key)) => guard.iterator(IteratorMode::From(key, direction)),
        _ => guard.iterator(IteratorMode::Start),
    };
    let iterator = make_snapshot_iterator_resource(snapshot.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif]
pub fn snapshot_iterator_cf<'a>(
    env: Env<'a>,
    resource: Term<'a>,
    name: String,
    mode: Term<'a>,
) -> NifResult<Term<'a>> {
    let snapshot = decode_snapshot(resource)?;
    let db_guard = snapshot.owner.read();
    let Some(cf) = db_guard.cf_handle(&name) else {
        return Ok((error(), unknown_cf()).encode(env));
    };
    let (mode_name, key, direction) = iterator_mode(mode)?;
    let snapshot_guard = snapshot.lock();
    let iterator = match (mode_name.as_str(), key.as_deref()) {
        ("end", _) => snapshot_guard.iterator_cf(cf, IteratorMode::End),
        ("from", Some(key)) => snapshot_guard.iterator_cf(cf, IteratorMode::From(key, direction)),
        _ => snapshot_guard.iterator_cf(cf, IteratorMode::Start),
    };
    let iterator = make_snapshot_iterator_resource(snapshot.clone(), iterator);
    Ok((ok(), iterator).encode(env))
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn create_checkpoint(
    env: Env,
    resource: ResourceArc<DbResource>,
    path: String,
) -> NifResult<Term> {
    let guard = resource.read();
    match Checkpoint::new(&guard).and_then(|checkpoint| checkpoint.create_checkpoint(path)) {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

fn backup_info<'a>(env: Env<'a>, engine: &BackupEngine) -> Vec<Term<'a>> {
    engine
        .get_backup_info()
        .into_iter()
        .map(|item| {
            (
                backup(),
                item.backup_id,
                item.timestamp,
                item.size,
                item.num_files,
            )
                .encode(env)
        })
        .collect()
}

fn open_backup_engine(path: &str) -> Result<BackupEngine, rocksdb::Error> {
    let options = BackupEngineOptions::new(path)?;
    let rocks_env = rocksdb::Env::new()?;
    BackupEngine::open(&options, &rocks_env)
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn create_backup(env: Env, resource: ResourceArc<DbResource>, path: String) -> NifResult<Term> {
    let mut engine = match open_backup_engine(&path) {
        Ok(engine) => engine,
        Err(reason) => return Ok((error(), reason.to_string()).encode(env)),
    };
    match engine.create_new_backup(&resource.read()) {
        Ok(()) => Ok((ok(), backup_info(env, &engine)).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn get_backup_info(env: Env, path: String) -> NifResult<Term> {
    match open_backup_engine(&path) {
        Ok(engine) => Ok((ok(), backup_info(env, &engine)).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn purge_old_backups(env: Env, path: String, keep: usize) -> NifResult<Term> {
    let mut engine = match open_backup_engine(&path) {
        Ok(engine) => engine,
        Err(reason) => return Ok((error(), reason.to_string()).encode(env)),
    };
    match engine.purge_old_backups(keep) {
        Ok(()) => Ok((ok(), backup_info(env, &engine)).encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyIo")]
pub fn restore_from_backup(
    env: Env,
    backup_path: String,
    restore_path: String,
    backup_id: i32,
) -> NifResult<Term> {
    let mut engine = match open_backup_engine(&backup_path) {
        Ok(engine) => engine,
        Err(reason) => return Ok((error(), reason.to_string()).encode(env)),
    };
    let mut options = RestoreOptions::default();
    options.set_keep_log_files(false);
    let result = if backup_id == -1 {
        engine.restore_from_latest_backup(&restore_path, &restore_path, &options)
    } else {
        engine.restore_from_backup(&restore_path, &restore_path, &options, backup_id as u32)
    };
    match result {
        Ok(()) => Ok(ok().encode(env)),
        Err(reason) => Ok((error(), reason.to_string()).encode(env)),
    }
}

#[rustler::nif]
pub fn next<'a>(env: Env<'a>, resource: ResourceArc<IteratorResource>) -> NifResult<Term<'a>> {
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
