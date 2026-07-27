use rocksdb::Options;
use rustler::{Decoder, Error, MapIterator, NifResult, Term};

pub struct RockerOptions {
    create_if_missing: bool,
    create_missing_column_families: bool,
    error_if_exists: bool,
    paranoid_checks: bool,
}

impl Default for RockerOptions {
    fn default() -> Self {
        Self {
            create_if_missing: true,
            create_missing_column_families: false,
            error_if_exists: false,
            paranoid_checks: true,
        }
    }
}

impl<'a> Decoder<'a> for RockerOptions {
    fn decode(term: Term<'a>) -> NifResult<Self> {
        let mut options = Self::default();
        for (key, value) in MapIterator::new(term).ok_or(Error::BadArg)? {
            match key.atom_to_string()?.as_str() {
                "create_if_missing" => options.create_if_missing = value.decode()?,
                "create_missing_column_families" => {
                    options.create_missing_column_families = value.decode()?
                }
                "set_error_if_exists" => options.error_if_exists = value.decode()?,
                "set_paranoid_checks" => options.paranoid_checks = value.decode()?,
                _ => {}
            }
        }
        Ok(options)
    }
}

impl From<RockerOptions> for Options {
    fn from(value: RockerOptions) -> Self {
        let mut options = Options::default();
        options.create_if_missing(value.create_if_missing);
        options.create_missing_column_families(value.create_missing_column_families);
        options.set_error_if_exists(value.error_if_exists);
        options.set_paranoid_checks(value.paranoid_checks);
        options
    }
}
