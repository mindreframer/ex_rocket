use rocksdb::MergeOperands;
use eetf::{Term as EetfTerm, FixInteger};

/// Counter merge operator that handles string-based integer arithmetic
pub fn counter_merge(
    _key: &[u8],
    existing_val: Option<&[u8]>,
    operands: &MergeOperands,
) -> Option<Vec<u8>> {
    let mut result: i64 = match existing_val {
        Some(val) => {
            match std::str::from_utf8(val).ok().and_then(|s| s.parse::<i64>().ok()) {
                Some(num) => num,
                None => 0,
            }
        },
        None => 0,
    };

    for op in operands.iter() {
        if let Ok(operand_str) = std::str::from_utf8(op) {
            if let Ok(operand) = operand_str.parse::<i64>() {
                result += operand;
            }
        }
    }

    Some(result.to_string().into_bytes())
}

/// Erlang merge operator that handles ETF-serialized tuple operations
pub fn erlang_merge(
    _key: &[u8],
    existing_val: Option<&[u8]>,
    operands: &MergeOperands,
) -> Option<Vec<u8>> {
    // First try ETF term processing
    let mut current_eetf_term = existing_val.and_then(|val| {
        EetfTerm::decode(val).ok()
    });

    let mut is_etf_processing = false;

    // Process each operand
    for operand_bytes in operands.iter() {
        if let Ok(operand_eetf_term) = EetfTerm::decode(operand_bytes) {
            current_eetf_term = process_eetf_merge_operation(current_eetf_term, operand_eetf_term);
            is_etf_processing = true;
        }
    }

    // If ETF processing succeeded, encode result back to ETF
    if is_etf_processing {
        if let Some(result_eetf_term) = current_eetf_term {
            let mut buffer = Vec::new();
            if result_eetf_term.encode(&mut buffer).is_ok() {
                return Some(buffer);
            }
        }
    }

    // Fallback to counter behavior for simple string operations
    let mut result: i64 = match existing_val {
        Some(val) => {
            match std::str::from_utf8(val).ok().and_then(|s| s.parse::<i64>().ok()) {
                Some(num) => num,
                None => 0,
            }
        },
        None => 0,
    };

    for op in operands.iter() {
        if let Ok(operand_str) = std::str::from_utf8(op) {
            if let Ok(operand) = operand_str.parse::<i64>() {
                result += operand;
            }
        }
    }

    Some(result.to_string().into_bytes())
}

/// Process ETF merge operations for tuple-based operations
fn process_eetf_merge_operation(existing_value: Option<EetfTerm>, operand: EetfTerm) -> Option<EetfTerm> {
    // Try to parse operand as a tuple (operation_atom, value)
    if let EetfTerm::Tuple(tuple) = operand {
        if tuple.elements.len() >= 2 {
            if let EetfTerm::Atom(op_atom) = &tuple.elements[0] {
                match op_atom.name.as_str() {
                    "int_add" => {
                        // Handle integer addition
                        let existing_int = existing_value
                            .as_ref()
                            .and_then(|val| match val {
                                EetfTerm::FixInteger(i) => Some(i.value as i64),
                                EetfTerm::BigInteger(_big_int) => Some(0), // Simplified for now
                                _ => None,
                            })
                            .unwrap_or(0);

                        if let EetfTerm::FixInteger(add_value) = &tuple.elements[1] {
                            let result = existing_int + (add_value.value as i64);
                            return Some(EetfTerm::FixInteger(FixInteger { value: result as i32 }));
                        }
                    }
                    "list_append" => {
                        // Handle list append
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if let EetfTerm::List(append_list) = &tuple.elements[1] {
                            existing_list.elements.extend_from_slice(&append_list.elements);
                            return Some(EetfTerm::List(existing_list));
                        }
                    }
                    "list_prepend" => {
                        // Handle list prepend (add elements to the beginning)
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if let EetfTerm::List(prepend_list) = &tuple.elements[1] {
                            // Insert elements at the beginning in reverse order to maintain order
                            for (i, elem) in prepend_list.elements.iter().enumerate() {
                                existing_list.elements.insert(i, elem.clone());
                            }
                            return Some(EetfTerm::List(existing_list));
                        }
                    }
                    "list_subtract" => {
                        // Handle list subtract (remove elements)
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if let EetfTerm::List(subtract_list) = &tuple.elements[1] {
                            // Remove elements that are in subtract_list
                            existing_list.elements.retain(|elem| {
                                !subtract_list.elements.contains(elem)
                            });
                            return Some(EetfTerm::List(existing_list));
                        }
                    }
                    "list_set" => {
                        // Handle list set (set element at position)
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if tuple.elements.len() >= 3 {
                            if let (EetfTerm::FixInteger(pos), new_value) = (&tuple.elements[1], &tuple.elements[2]) {
                                let index = pos.value as usize;
                                if index < existing_list.elements.len() {
                                    existing_list.elements[index] = new_value.clone();
                                }
                                return Some(EetfTerm::List(existing_list));
                            }
                        }
                    }
                    "list_delete" => {
                        // Handle list delete (single position or range)
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if tuple.elements.len() >= 2 {
                            if let EetfTerm::FixInteger(pos) = &tuple.elements[1] {
                                let start_index = pos.value as usize;

                                if tuple.elements.len() >= 3 {
                                    // Range delete: {list_delete, start, end}
                                    if let EetfTerm::FixInteger(end_pos) = &tuple.elements[2] {
                                        let end_index = end_pos.value as usize;
                                        if start_index < existing_list.elements.len() && end_index <= existing_list.elements.len() {
                                            existing_list.elements.drain(start_index..end_index);
                                        }
                                    }
                                } else {
                                    // Single delete: {list_delete, pos}
                                    if start_index < existing_list.elements.len() {
                                        existing_list.elements.remove(start_index);
                                    }
                                }
                                return Some(EetfTerm::List(existing_list));
                            }
                        }
                    }
                    "list_insert" => {
                        // Handle list insert (insert elements at position)
                        let mut existing_list = match &existing_value {
                            Some(EetfTerm::List(list)) => list.clone(),
                            _ => eetf::List { elements: Vec::new() },
                        };

                        if tuple.elements.len() >= 3 {
                            if let (EetfTerm::FixInteger(pos), EetfTerm::List(insert_list)) = (&tuple.elements[1], &tuple.elements[2]) {
                                let index = pos.value as usize;
                                if index <= existing_list.elements.len() {
                                    // Insert elements at the specified position
                                    for (i, elem) in insert_list.elements.iter().enumerate() {
                                        existing_list.elements.insert(index + i, elem.clone());
                                    }
                                }
                                return Some(EetfTerm::List(existing_list));
                            }
                        }
                    }
                    "binary_append" => {
                        // Handle binary append
                        let mut existing_binary = match &existing_value {
                            Some(EetfTerm::Binary(binary)) => binary.clone(),
                            _ => eetf::Binary { bytes: Vec::new() },
                        };

                        if let EetfTerm::Binary(append_binary) = &tuple.elements[1] {
                            existing_binary.bytes.extend_from_slice(&append_binary.bytes);
                            return Some(EetfTerm::Binary(existing_binary));
                        }
                    }
                    "binary_erase" => {
                        // Handle binary erase (erase bytes at position)
                        let mut existing_binary = match &existing_value {
                            Some(EetfTerm::Binary(binary)) => binary.clone(),
                            _ => eetf::Binary { bytes: Vec::new() },
                        };

                        if tuple.elements.len() >= 3 {
                            if let (EetfTerm::FixInteger(pos), EetfTerm::FixInteger(count)) = (&tuple.elements[1], &tuple.elements[2]) {
                                let start_pos = pos.value as usize;
                                let erase_count = count.value as usize;
                                let end_pos = start_pos + erase_count;

                                if start_pos <= existing_binary.bytes.len() && end_pos <= existing_binary.bytes.len() {
                                    existing_binary.bytes.drain(start_pos..end_pos);
                                }
                                return Some(EetfTerm::Binary(existing_binary));
                            }
                        }
                    }
                    "binary_insert" => {
                        // Handle binary insert (insert bytes at position)
                        let mut existing_binary = match &existing_value {
                            Some(EetfTerm::Binary(binary)) => binary.clone(),
                            _ => eetf::Binary { bytes: Vec::new() },
                        };

                        if tuple.elements.len() >= 3 {
                            if let (EetfTerm::FixInteger(pos), EetfTerm::Binary(insert_binary)) = (&tuple.elements[1], &tuple.elements[2]) {
                                let insert_pos = pos.value as usize;

                                if insert_pos <= existing_binary.bytes.len() {
                                    // Insert bytes at the specified position
                                    for (i, &byte) in insert_binary.bytes.iter().enumerate() {
                                        existing_binary.bytes.insert(insert_pos + i, byte);
                                    }
                                }
                                return Some(EetfTerm::Binary(existing_binary));
                            }
                        }
                    }
                    "binary_replace" => {
                        // Handle binary replace (replace bytes at position)
                        let mut existing_binary = match &existing_value {
                            Some(EetfTerm::Binary(binary)) => binary.clone(),
                            _ => eetf::Binary { bytes: Vec::new() },
                        };

                        if tuple.elements.len() >= 4 {
                            if let (EetfTerm::FixInteger(pos), EetfTerm::FixInteger(count), EetfTerm::Binary(replace_binary)) =
                                (&tuple.elements[1], &tuple.elements[2], &tuple.elements[3]) {
                                let start_pos = pos.value as usize;
                                let replace_count = count.value as usize;
                                let end_pos = start_pos + replace_count;

                                if start_pos <= existing_binary.bytes.len() && end_pos <= existing_binary.bytes.len() {
                                    // Remove the bytes to be replaced
                                    existing_binary.bytes.drain(start_pos..end_pos);

                                    // Insert the replacement bytes
                                    for (i, &byte) in replace_binary.bytes.iter().enumerate() {
                                        existing_binary.bytes.insert(start_pos + i, byte);
                                    }
                                }
                                return Some(EetfTerm::Binary(existing_binary));
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    // If we can't parse as a tuple operation, return existing value
    existing_value
}

/// Bitset merge operator that handles bit manipulation operations
pub fn bitset_merge(
    _key: &[u8],
    existing_val: Option<&[u8]>,
    operands: &MergeOperands,
) -> Option<Vec<u8>> {
    // Initialize bitset from existing value or empty
    let mut bitset = match existing_val {
        Some(val) => val.to_vec(),
        None => Vec::new(),
    };

    // Process each operand
    for operand_bytes in operands.iter() {
        if let Ok(operand_str) = std::str::from_utf8(operand_bytes) {
            let trimmed = operand_str.trim();

            if trimmed.is_empty() {
                // Empty string means clear the bitset
                bitset.clear();
            } else if trimmed.starts_with('+') {
                // Set bit at position
                if let Ok(pos) = trimmed[1..].parse::<usize>() {
                    set_bit(&mut bitset, pos);
                }
            } else if trimmed.starts_with('-') {
                // Clear bit at position
                if let Ok(pos) = trimmed[1..].parse::<usize>() {
                    clear_bit(&mut bitset, pos);
                }
            }
        }
    }

    Some(bitset)
}

/// Set a bit at the specified position in the bitset
fn set_bit(bitset: &mut Vec<u8>, pos: usize) {
    let byte_index = pos / 8;
    let bit_index = pos % 8;

    // Expand bitset if needed
    if byte_index >= bitset.len() {
        bitset.resize(byte_index + 1, 0);
    }

    bitset[byte_index] |= 1 << bit_index;
}

/// Clear a bit at the specified position in the bitset
fn clear_bit(bitset: &mut Vec<u8>, pos: usize) {
    let byte_index = pos / 8;
    let bit_index = pos % 8;

    // Only clear if the byte exists
    if byte_index < bitset.len() {
        bitset[byte_index] &= !(1 << bit_index);
    }
}