use rustler::{MapIterator, Term};

pub const MAX_ENTRIES: usize = 100_000;
pub const MAX_BYTES: usize = 64 * 1024 * 1024;

#[derive(Debug)]
pub struct IteratorTakeOptions {
    pub max_entries: usize,
    pub max_bytes: Option<usize>,
}

#[derive(Debug)]
pub enum IteratorOptionsError {
    Invalid,
    Unknown(String),
}

impl IteratorTakeOptions {
    pub fn decode(term: Term<'_>) -> Result<Self, IteratorOptionsError> {
        let iterator = MapIterator::new(term).ok_or(IteratorOptionsError::Invalid)?;
        let mut max_entries = None;
        let mut max_bytes = None;

        for (key, value) in iterator {
            let key = key
                .atom_to_string()
                .map_err(|_| IteratorOptionsError::Invalid)?;

            match key.as_str() {
                "max_entries" => {
                    let decoded = value
                        .decode::<usize>()
                        .map_err(|_| IteratorOptionsError::Invalid)?;
                    if decoded == 0 || decoded > MAX_ENTRIES {
                        return Err(IteratorOptionsError::Invalid);
                    }
                    max_entries = Some(decoded);
                }
                "max_bytes" => {
                    let decoded = value
                        .decode::<usize>()
                        .map_err(|_| IteratorOptionsError::Invalid)?;
                    if decoded == 0 || decoded > MAX_BYTES {
                        return Err(IteratorOptionsError::Invalid);
                    }
                    max_bytes = Some(decoded);
                }
                _ => return Err(IteratorOptionsError::Unknown(key)),
            }
        }

        Ok(Self {
            max_entries: max_entries.ok_or(IteratorOptionsError::Invalid)?,
            max_bytes,
        })
    }
}
