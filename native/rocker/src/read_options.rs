use rocksdb::ReadOptions;
use rustler::{MapIterator, Term};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, PartialEq, Clone, Debug, Default)]
pub struct RockerReadOptions {
    pub iterate_upper_bound: Option<String>,
    pub iterate_lower_bound: Option<String>,
}

#[derive(Debug)]
pub enum ReadOptionsError {
    Unknown(String),
    Invalid(String),
}

impl RockerReadOptions {
    pub fn decode(term: Term<'_>) -> Result<Self, ReadOptionsError> {
        let mut options = Self::default();
        let iterator = MapIterator::new(term)
            .ok_or_else(|| ReadOptionsError::Invalid("read_options".to_string()))?;

        for (key, value) in iterator {
            let key = key
                .atom_to_string()
                .map_err(|_| ReadOptionsError::Invalid("read_options".to_string()))?;

            match key.as_str() {
                "iterate_upper_bound" => {
                    options.iterate_upper_bound = Some(
                        value
                            .decode()
                            .map_err(|_| ReadOptionsError::Invalid(key.clone()))?,
                    )
                }
                "iterate_lower_bound" => {
                    options.iterate_lower_bound = Some(
                        value
                            .decode()
                            .map_err(|_| ReadOptionsError::Invalid(key.clone()))?,
                    )
                }
                _ => return Err(ReadOptionsError::Unknown(key)),
            }
        }

        Ok(options)
    }
}

impl From<RockerReadOptions> for ReadOptions {
    fn from(options: RockerReadOptions) -> Self {
        let mut read_options = ReadOptions::default();

        if let Some(upper_bound) = options.iterate_upper_bound {
            read_options.set_iterate_upper_bound(upper_bound);
        }
        if let Some(lower_bound) = options.iterate_lower_bound {
            read_options.set_iterate_lower_bound(lower_bound);
        }

        read_options
    }
}
