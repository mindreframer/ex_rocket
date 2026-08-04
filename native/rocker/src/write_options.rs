use rocksdb::WriteOptions;
use rustler::{MapIterator, Term};

#[derive(Debug, Default)]
pub struct RockerWriteOptions {
    pub sync: bool,
    pub disable_wal: bool,
}

#[derive(Debug)]
pub enum WriteOptionsError {
    Invalid,
    Unknown(String),
}

impl RockerWriteOptions {
    pub fn decode(term: Term<'_>) -> Result<Self, WriteOptionsError> {
        let mut options = Self::default();
        let iterator = MapIterator::new(term).ok_or(WriteOptionsError::Invalid)?;

        for (key, value) in iterator {
            let key = key
                .atom_to_string()
                .map_err(|_| WriteOptionsError::Invalid)?;
            match key.as_str() {
                "sync" => {
                    options.sync = value
                        .decode::<bool>()
                        .map_err(|_| WriteOptionsError::Invalid)?
                }
                "disable_wal" => {
                    options.disable_wal = value
                        .decode::<bool>()
                        .map_err(|_| WriteOptionsError::Invalid)?
                }
                _ => return Err(WriteOptionsError::Unknown(key)),
            }
        }

        if options.sync && options.disable_wal {
            return Err(WriteOptionsError::Invalid);
        }

        Ok(options)
    }
}

impl From<RockerWriteOptions> for WriteOptions {
    fn from(options: RockerWriteOptions) -> Self {
        let mut write_options = WriteOptions::default();
        write_options.set_sync(options.sync);
        write_options.disable_wal(options.disable_wal);
        write_options
    }
}
