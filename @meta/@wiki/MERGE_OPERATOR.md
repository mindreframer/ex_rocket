# RocksDB Merge Operator Implementation Plan for ExRocket

## Analysis Summary

**Current ExRocket State:**
- Rust-based NIFs using Rustler 0.32.1 with rocksdb 0.22.0
- Complete CRUD operations, iterators, column families, snapshots
- **Missing:** merge operator support entirely

**Reference Implementation Features:**
- Integer arithmetic: `{int_add, Value}`
- List operations: append, subtract, set, delete, insert
- Binary operations: append, erase, insert, replace
- Bitset and counter merge operators
- Uses Erlang term serialization for complex data types

## Incremental Implementation Plan

### **Phase 1: Foundation (Minimal Viable Merge) ✅ COMPLETED**
1. **Add merge function to Elixir API**
   - `def merge(_db_ref, _key, _operand), do: Erlang.nif_error(:nif_not_loaded)`
   - `def merge_cf(_db_ref, _cf_name, _key, _operand), do: Erlang.nif_error(:nif_not_loaded)`

2. **Add basic merge NIF functions**
   - `nif::merge` - basic merge operation
   - `nif::merge_cf` - column family merge
   - Register in lib.rs

3. **Implement simple counter merge operator**
   - Support basic integer addition only
   - Input: binary encoded integers
   - Test: counter increments

**Status:** ✅ Complete
- Added `merge/3` function to Elixir API
- Implemented Rust NIF with `counter_merge_operator`
- String-based integer arithmetic (addition/subtraction)
- Comprehensive test suite
- All 64 existing tests still pass

### **Phase 2: Erlang Term Merge Operator ✅ BASIC COMPLETED**
4. **Add serde/term serialization support**
   - ✅ Added basic framework for Erlang term handling
   - 🔄 Full term serialization implementation pending (Phase 2.1)

5. **Implement ErlangMergeOperator in Rust**
   - ✅ Basic framework implemented with fallback to counter behavior
   - 🔄 Full tuple parsing for `{:int_add, value}` pending (Phase 2.1)

6. **Add merge operator configuration**
   - ✅ Added `"erlang_merge_operator"` option to RockerOptions
   - ✅ Wired into Options::from implementation
   - ✅ Basic tests passing with string-based operations

**Status:** ✅ Basic framework complete
- `erlang_merge_operator` configuration works
- Falls back to counter behavior for simple operations
- Infrastructure ready for full Erlang term implementation
- All 65 tests pass

### **Phase 2.1: Full Erlang Term Implementation (Next Step)**
**Implementation needed for full tuple-based operations:**
- Proper Erlang term binary deserialization in Rust
- Tuple pattern matching for operation types
- Full `{:int_add, value}`, `{:list_append, list}`, `{:binary_append, data}` support
- Type-safe operation handling with proper error reporting

### **Phase 3: List Operations ✅ COMPLETED + ENHANCED**
7. **Implement list merge operations**
   - ✅ `{:list_append, list}` - Append elements to existing list
   - ✅ `{:list_prepend, list}` - Prepend elements to existing list *(NEW)*
   - ✅ `{:list_subtract, list}` - Remove elements from existing list
   - ✅ `{:list_set, pos, value}` - Set element at specific position
   - ✅ `{:list_delete, pos}` - Delete element at position
   - ✅ `{:list_delete, start, end}` - Delete range of elements
   - ✅ `{:list_insert, pos, list}` - Insert elements at position

**Status:** ✅ Complete + Enhanced
- All list operations implemented with proper ETF handling
- Added `list_prepend` for beginning-of-list insertion
- Comprehensive test coverage for all operations including new prepend tests
- Proper bounds checking and error handling
- All 90 tests pass including 29 merge operation tests

### **Phase 4: Binary Operations ✅ COMPLETED**
8. **Implement binary merge operations**
   - ✅ `{:binary_append, binary}` - Append binary data to existing binary
   - ✅ `{:binary_erase, pos, count}` - Erase bytes at position
   - ✅ `{:binary_insert, pos, binary}` - Insert binary data at position
   - ✅ `{:binary_replace, pos, count, binary}` - Replace bytes at position

**Status:** ✅ Complete
- All binary operations implemented with proper ETF handling
- Comprehensive test coverage including mixed operations
- Proper bounds checking and error handling
- All 77 tests pass including 16 merge operation tests

### **Phase 5: Additional Merge Operators ✅ COMPLETED**
9. **Counter merge operator** ✅ COMPLETED (Phase 1)
   - ✅ Simple string-based counter (like reference)
   - ✅ Handles string addition/subtraction

10. **Bitset merge operator** ✅ COMPLETED
    - ✅ Bit manipulation operations
    - ✅ `+pos` - Set bit at position
    - ✅ `-pos` - Clear bit at position
    - ✅ `""` (empty string) - Clear entire bitset

**Status:** ✅ Complete
- Counter merge operator implemented in Phase 1
- Bitset merge operator with full bit manipulation support
- Comprehensive test coverage for all bitset operations
- Proper bounds checking and dynamic bitset expansion
- All 83 tests pass including 22 merge operation tests

### **Phase 6: Column Family Support ✅ COMPLETED**
11. **Add merge_cf function** ✅ COMPLETED
    - ✅ Column family specific merge operations
    - ✅ All merge operators work with CFs
    - ✅ Proper error handling for non-existent column families
    - ✅ Per-column-family merge operator configuration

**Status:** ✅ Complete
- `merge_cf/4` function implemented in Elixir API
- Rust NIF implementation with proper error handling
- Column families require explicit merge operator configuration when created
- Comprehensive test coverage for all merge operators with column families
- All 88 tests pass including 27 merge operation tests

## Reference Implementation Details

### **Erlang Reference Merge Operators:**

#### **Integer Operations**
```erlang
rocksdb:merge(Db, <<"i">>, term_to_binary({int_add, 1}), [])
```

#### **List Operations**
```erlang
% Append
rocksdb:merge(Db, <<"list">>, term_to_binary({list_append, [c, d]}), [])

% Subtract (remove elements)
rocksdb:merge(Db, <<"list">>, term_to_binary({list_substract, [c, a]}), [])

% Set element at position
rocksdb:merge(Db, <<"list">>, term_to_binary({list_set, 2, 'c1'}), [])

% Delete element at position
rocksdb:merge(Db, <<"list">>, term_to_binary({list_delete, 2}), [])

% Delete range
rocksdb:merge(Db, <<"list">>, term_to_binary({list_delete, 2, 4}), [])

% Insert elements at position
rocksdb:merge(Db, <<"list">>, term_to_binary({list_insert, 2, [h, i]}), [])
```

#### **Binary Operations**
```erlang
% Append
rocksdb:merge(Db, <<"encbin">>, term_to_binary({binary_append, <<"abc">>}), [])

% Erase bytes
rocksdb:merge(Db, <<"eraseterm">>, term_to_binary({binary_erase, 2, 4}), [])

% Insert bytes
rocksdb:merge(Db, <<"insertterm">>, term_to_binary({binary_insert, 2, <<"1234">>}), [])

% Replace bytes
rocksdb:merge(Db, <<"encbin">>, term_to_binary({binary_replace, 10, 5, <<"red">>}), [])
```

## Testing Strategy
- **Test-driven**: Write tests for each phase before implementation
- **Port reference tests**: Adapt erlang test cases to Elixir
- **Integration tests**: Full workflow with various data types
- **Performance tests**: Compare with reference implementation

## Implementation Notes

### **Dependencies**
- Rustler handles Erlang term serialization
- No additional crates needed for basic functionality

### **API Design**
- Follow exact tuple format as reference: `{:int_add, value}`
- Return error tuples for failures: `{:error, reason}`

### **Current Usage (Phase 1)**
```elixir
# Open with merge operator
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "counter_merge_operator"
})

# Use merge operations
ExRocket.merge(db, "counter", "1")    # counter = 1
ExRocket.merge(db, "counter", "5")    # counter = 6
ExRocket.merge(db, "counter", "-2")   # counter = 4
{:ok, "4"} = ExRocket.get(db, "counter")
```

### **Current Usage (All Phases)**

#### **Counter Merge Operator**
```elixir
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "counter_merge_operator"
})

ExRocket.merge(db, "counter", "5")     # counter = 5
ExRocket.merge(db, "counter", "3")     # counter = 8
ExRocket.merge(db, "counter", "-2")    # counter = 6
{:ok, "6"} = ExRocket.get(db, "counter")
```

#### **Erlang Term Merge Operator**
```elixir
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "erlang_merge_operator"
})

# Integer operations
operand = :erlang.term_to_binary({:int_add, 5})
ExRocket.merge(db, "int_counter", operand)

# List operations
operand = :erlang.term_to_binary({:list_append, [:d, :e]})
ExRocket.merge(db, "my_list", operand)

operand = :erlang.term_to_binary({:list_prepend, [:start, :beginning]})
ExRocket.merge(db, "my_list", operand)

operand = :erlang.term_to_binary({:list_subtract, [:b]})
ExRocket.merge(db, "my_list", operand)

operand = :erlang.term_to_binary({:list_set, 1, :x})
ExRocket.merge(db, "my_list", operand)

operand = :erlang.term_to_binary({:list_delete, 0})
ExRocket.merge(db, "my_list", operand)

operand = :erlang.term_to_binary({:list_insert, 1, [:y, :z]})
ExRocket.merge(db, "my_list", operand)

# Binary operations
operand = :erlang.term_to_binary({:binary_append, " world"})
ExRocket.merge(db, "my_binary", operand)

operand = :erlang.term_to_binary({:binary_erase, 5, 6})
ExRocket.merge(db, "my_binary", operand)

operand = :erlang.term_to_binary({:binary_insert, 5, " there"})
ExRocket.merge(db, "my_binary", operand)

operand = :erlang.term_to_binary({:binary_replace, 6, 5, "everyone"})
ExRocket.merge(db, "my_binary", operand)
```

#### **Bitset Merge Operator**
```elixir
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "bitset_merge_operator"
})

ExRocket.merge(db, "bitset", "+0")     # Set bit 0
ExRocket.merge(db, "bitset", "+5")     # Set bit 5
ExRocket.merge(db, "bitset", "+12")    # Set bit 12
ExRocket.merge(db, "bitset", "-5")     # Clear bit 5
ExRocket.merge(db, "bitset", "")       # Clear entire bitset
```

#### **Column Family Merge Operations**
```elixir
# Open database with merge operator
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "erlang_merge_operator"
})

# Create column families with specific merge operators
ExRocket.create_cf(db, "counters", %{merge_operator: "counter_merge_operator"})
ExRocket.create_cf(db, "data", %{merge_operator: "erlang_merge_operator"})
ExRocket.create_cf(db, "flags", %{merge_operator: "bitset_merge_operator"})

# Use merge operations in specific column families
ExRocket.merge_cf(db, "counters", "total", "100")        # Counter in CF
ExRocket.merge_cf(db, "counters", "total", "50")         # total = 150

# ETF operations in data CF
operand = :erlang.term_to_binary({:int_add, 25})
ExRocket.merge_cf(db, "data", "etf_counter", operand)

# Bitset operations in flags CF
ExRocket.merge_cf(db, "flags", "user_flags", "+5")       # Set bit 5
ExRocket.merge_cf(db, "flags", "user_flags", "+12")      # Set bit 12
ExRocket.merge_cf(db, "flags", "user_flags", "-5")       # Clear bit 5
```

## Files Modified in Phase 1

### **Elixir Files:**
- `lib/ex_rock.ex`: Added `merge/3` function

### **Rust Files:**
- `native/rocker/src/lib.rs`: Added `nif::merge` to exports
- `native/rocker/src/nif.rs`: Implemented `merge` NIF function
- `native/rocker/src/options.rs`: Added `merge_operator` option and `counter_merge` implementation

### **Test Files:**
- `test/merge_test.exs`: Comprehensive test suite for merge functionality

## Next Phase Preparation

For Phase 2 (Erlang Term Merge Operator), we'll need to:
1. Implement Erlang term serialization/deserialization in Rust
2. Create the main `ErlangMergeOperator` struct
3. Handle tuple pattern matching for different operation types
4. Add comprehensive error handling for malformed operations

This plan provides a clear roadmap for implementing full RocksDB merge operator support while maintaining incremental, testable progress.