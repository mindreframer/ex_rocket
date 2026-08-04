# ExRocket Cheatsheet

A comprehensive reference for all ExRocket features and functions.

## Database Operations

### Opening/Closing Databases
```elixir
# Open database (creates if missing)
{:ok, db} = ExRocket.open("path/to/db", %{create_if_missing: true})

# Open for read-only
{:ok, db} = ExRocket.open_for_read_only("path/to/db")

# Open with column families
{:ok, db} = ExRocket.open_cf("path/to/db", ["cf1", "cf2"])

# Open column families read-only
{:ok, db} = ExRocket.open_cf_for_read_only("path/to/db", ["cf1"])

# Explicit close is deterministic and idempotent
:ok = ExRocket.close(db)
:ok = ExRocket.close(db)
{:error, :closed} = ExRocket.get(db, "key")
```

`close/1` returns `{:error, :resource_busy}` while a live iterator or snapshot
retains the database. Release those child resources before retrying. Successful
close releases the RocksDB path lock before returning; garbage-collection close
remains available when explicit close is omitted.

### Database Management
```elixir
# Get database path
{:ok, path} = ExRocket.get_db_path(db)

# Destroy database
:ok = ExRocket.destroy("path/to/db")

# Repair database
:ok = ExRocket.repair("path/to/db")

# Get latest sequence number
{:ok, seq} = ExRocket.latest_sequence_number(db)
```

## Basic Key-Value Operations

### Standard Operations
```elixir
# Put key-value
:ok = ExRocket.put(db, "key", "value")

# Get value
{:ok, "value"} = ExRocket.get(db, "key")
:undefined = ExRocket.get(db, "missing_key")

# Get with default
{:ok, "default"} = ExRocket.get(db, "missing_key", "default")

# Delete key
:ok = ExRocket.delete(db, "key")
```

### Binary Operations (ETF Serialization)
```elixir
# Get and automatically deserialize Erlang terms
{:ok, term} = ExRocket.getb(db, "key")  # Calls :erlang.binary_to_term/1

# Merge with automatic ETF serialization
:ok = ExRocket.mergeb(db, "key", {:int_add, 5})  # Calls :erlang.term_to_binary/1
```

## Column Family Operations

### Managing Column Families
```elixir
# Create column family
:ok = ExRocket.create_cf(db, "my_cf")

# Create with options
:ok = ExRocket.create_cf(db, "my_cf", %{merge_operator: "counter_merge_operator"})

# List all column families
{:ok, ["default", "my_cf"]} = ExRocket.list_cf("path/to/db")

# Drop column family
:ok = ExRocket.drop_cf(db, "my_cf")
```

### Column Family Operations
```elixir
# Put in column family
:ok = ExRocket.put_cf(db, "my_cf", "key", "value")

# Get from column family
{:ok, "value"} = ExRocket.get_cf(db, "my_cf", "key")
{:ok, "default"} = ExRocket.get_cf(db, "my_cf", "key", "default")

# Binary get from column family (ETF deserialization)
{:ok, term} = ExRocket.get_cfb(db, "my_cf", "key")

# Delete from column family
:ok = ExRocket.delete_cf(db, "my_cf", "key")
```

## Merge Operations

### Setup Merge Operators
```elixir
# Counter merge operator
{:ok, db} = ExRocket.open("path/to/db", %{
  create_if_missing: true,
  merge_operator: "counter_merge_operator"
})

# Erlang term merge operator
{:ok, db} = ExRocket.open("path/to/db", %{
  create_if_missing: true,
  merge_operator: "erlang_merge_operator"
})

# Bitset merge operator
{:ok, db} = ExRocket.open("path/to/db", %{
  create_if_missing: true,
  merge_operator: "bitset_merge_operator"
})
```

### Counter Merge Operations
```elixir
# String-based integer arithmetic
:ok = ExRocket.merge(db, "counter", "10")    # counter = 10
:ok = ExRocket.merge(db, "counter", "5")     # counter = 15
:ok = ExRocket.merge(db, "counter", "-3")    # counter = 12
{:ok, "12"} = ExRocket.get(db, "counter")
```

### Erlang Term Merge Operations

#### Integer Operations
```elixir
# Using binary encoding
operand = :erlang.term_to_binary({:int_add, 5})
:ok = ExRocket.merge(db, "int_counter", operand)

# Using binary helper
:ok = ExRocket.mergeb(db, "int_counter", {:int_add, 5})
```

#### List Operations
```elixir
# List append
:ok = ExRocket.mergeb(db, "my_list", {:list_append, [:d, :e]})

# List prepend (add to beginning)
:ok = ExRocket.mergeb(db, "my_list", {:list_prepend, [:start, :beginning]})

# List subtract (remove elements)
:ok = ExRocket.mergeb(db, "my_list", {:list_subtract, [:b]})

# Set element at position
:ok = ExRocket.mergeb(db, "my_list", {:list_set, 1, :new_value})

# Delete element at position
:ok = ExRocket.mergeb(db, "my_list", {:list_delete, 0})

# Delete range of elements
:ok = ExRocket.mergeb(db, "my_list", {:list_delete, 1, 3})

# Insert elements at position
:ok = ExRocket.mergeb(db, "my_list", {:list_insert, 1, [:x, :y]})
```

#### Binary Operations
```elixir
# Binary append
:ok = ExRocket.mergeb(db, "my_binary", {:binary_append, " world"})

# Binary erase (position, count)
:ok = ExRocket.mergeb(db, "my_binary", {:binary_erase, 5, 6})

# Binary insert (position, data)
:ok = ExRocket.mergeb(db, "my_binary", {:binary_insert, 5, " there"})

# Binary replace (position, count, new_data)
:ok = ExRocket.mergeb(db, "my_binary", {:binary_replace, 6, 5, "everyone"})
```

### Bitset Merge Operations
```elixir
# Set bits
:ok = ExRocket.merge(db, "bitset", "+0")     # Set bit 0
:ok = ExRocket.merge(db, "bitset", "+5")     # Set bit 5
:ok = ExRocket.merge(db, "bitset", "+12")    # Set bit 12

# Clear bits
:ok = ExRocket.merge(db, "bitset", "-5")     # Clear bit 5

# Clear entire bitset
:ok = ExRocket.merge(db, "bitset", "")       # Clear all bits
```

### Column Family Merge Operations
```elixir
# Standard merge in column family
:ok = ExRocket.merge_cf(db, "my_cf", "key", "operand")

# Binary merge in column family (ETF serialization)
:ok = ExRocket.merge_cfb(db, "my_cf", "key", {:int_add, 10})
```

## Batch Operations

```elixir
# Write batch operations - all operations are atomic
ops = [
  {:put, "key1", "value1"},
  {:put, "key2", "value2"},
  {:delete, "key3"},
  {:merge, "counter", "5"},                    # NEW: Merge operations supported!
  {:put_cf, "my_cf", "cf_key", "cf_value"},
  {:delete_cf, "my_cf", "old_key"},
  {:merge_cf, "my_cf", "cf_counter", "10"}     # NEW: Column family merge too!
]
{:ok, 7} = ExRocket.write_batch(db, ops)  # Returns {:ok, count} on success

# Atomic and synchronously durable before success is returned
{:ok, 1} = ExRocket.write_batch(
  db,
  [{:put, "materialization/checkpoint", "clean:42"}],
  %{sync: true}
)

# Example: Counter batch operations
{:ok, db} = ExRocket.open("my_db", %{
  create_if_missing: true,
  merge_operator: "counter_merge_operator"
})

:ok = ExRocket.put(db, "total", "100")

{:ok, 3} = ExRocket.write_batch(db, [
  {:merge, "total", "25"},        # total becomes 125
  {:merge, "total", "15"},        # total becomes 140
  {:put, "status", "updated"}     # set status
])

{:ok, "140"} = ExRocket.get(db, "total")
{:ok, "updated"} = ExRocket.get(db, "status")

# Atomicity controls all-or-nothing visibility. Durability controls whether an
# acknowledged write survives machine failure. Default batches use
# %{sync: false, disable_wal: false}: WAL enabled without a synchronous flush.
# WAL-disabled writes are suitable only for rebuildable bulk-load data.

# Establish a separate WAL durability boundary after grouped writes
:ok = ExRocket.flush_wal(db, true)

# Example: ETF merge in batch (requires erlang_merge_operator)
{:ok, db} = ExRocket.open("my_db", %{
  merge_operator: "erlang_merge_operator"
})

# Use binary encoded operands
operand1 = :erlang.term_to_binary({:int_add, 5})
operand2 = :erlang.term_to_binary({:list_append, [:x, :y]})

{:ok, 2} = ExRocket.write_batch(db, [
  {:merge, "counter", operand1},
  {:merge, "my_list", operand2}
])
```

## Iterator Operations

### Basic Iterators
```elixir
# Create iterator (forward/reverse)
{:ok, iter} = ExRocket.iterator(db, :start)     # Start from beginning
{:ok, iter} = ExRocket.iterator(db, :end)       # Start from end

# Iterate through keys
{:ok, "key1", "value1"} = ExRocket.next(iter)
{:ok, "key2", "value2"} = ExRocket.next(iter)
:end_of_iterator = ExRocket.next(iter)
```

### Bounded Bulk Reads
```elixir
{:ok, iter} = ExRocket.iterator(db, {:start})

{:ok, rows, status} = ExRocket.iterator_take(iter, %{
  max_entries: 1_000,
  max_bytes: 4 * 1024 * 1024
})

case status do
  :more -> ExRocket.iterator_take(iter, %{max_entries: 1_000})
  :end_of_iterator -> :done
end
```

`max_entries` is required and has a 100,000-entry hard limit. `max_bytes` has a
64 MiB hard limit and counts only copied key/value bytes, not Erlang term
overhead. One oversized first row is returned so iteration always progresses.
Reusing the same iterator preserves its RocksDB view; use a snapshot iterator
when every page must represent an explicit point in time.

### Range Iterators
```elixir
# Iterator with range
{:ok, iter} = ExRocket.iterator_range(db, :start, "from_key", "to_key")

# With read options
{:ok, iter} = ExRocket.iterator_range(db, :start, "from_key", "to_key", %{
  iterate_upper_bound: "upper_key"
})
```

### Prefix Iterators
```elixir
# Iterate keys with prefix
{:ok, iter} = ExRocket.prefix_iterator(db, "prefix_")
```

### Column Family Iterators
```elixir
# Iterator for column family
{:ok, iter} = ExRocket.iterator_cf(db, "my_cf", :start)

# Prefix iterator for column family
{:ok, iter} = ExRocket.prefix_iterator_cf(db, "my_cf", "prefix_")
```

## Range Operations

```elixir
# Delete range of keys
:ok = ExRocket.delete_range(db, "from_key", "to_key")

# Delete range in column family
:ok = ExRocket.delete_range_cf(db, "my_cf", "from_key", "to_key")
```

## Multi-get Operations

```elixir
# Get multiple keys at once
keys = ["key1", "key2", "key3"]
{:ok, [
  {:ok, "value1"},
  :undefined,
  {:ok, "value3"}
]} = ExRocket.multi_get(db, keys)

# Multi-get from column families
cf_keys = [
  {"cf1", "key1"},
  {"cf2", "key2"}
]
{:ok, results} = ExRocket.multi_get_cf(db, cf_keys)
```

## Key Existence Check

```elixir
# Fast check if key might exist (bloom filter)
true = ExRocket.key_may_exist(db, "key")
false = ExRocket.key_may_exist(db, "definitely_missing")

# Check in column family
true = ExRocket.key_may_exist_cf(db, "my_cf", "key")
```

## Snapshot Operations

### Creating and Using Snapshots
```elixir
# Create snapshot
{:ok, snap} = ExRocket.snapshot(db)

# Get from snapshot
{:ok, "value"} = ExRocket.snapshot_get(snap, "key")
{:ok, "default"} = ExRocket.snapshot_get(snap, "key", "default")

# Get from snapshot column family
{:ok, "value"} = ExRocket.snapshot_get_cf(snap, "my_cf", "key")
{:ok, "default"} = ExRocket.snapshot_get_cf(snap, "my_cf", "key", "default")
```

### Snapshot Multi-get
```elixir
# Multi-get from snapshot
{:ok, results} = ExRocket.snapshot_multi_get(snap, ["key1", "key2"])

# Multi-get from snapshot column families
{:ok, results} = ExRocket.snapshot_multi_get_cf(snap, [{"cf1", "key1"}])
```

### Snapshot Iterators
```elixir
# Iterator from snapshot
{:ok, iter} = ExRocket.snapshot_iterator(snap, :start)

# Iterator from snapshot column family
{:ok, iter} = ExRocket.snapshot_iterator_cf(snap, "my_cf", :start)
```

## Backup and Checkpoint Operations

### Checkpoints (Online Backups)
```elixir
# Create checkpoint
:ok = ExRocket.create_checkpoint(db, "/path/to/checkpoint")
```

### Backup Operations
```elixir
# Create backup
:ok = ExRocket.create_backup(db, "/path/to/backup")

# Get backup info
{:ok, backup_info} = ExRocket.get_backup_info("/path/to/backup")

# Purge old backups (keep only N most recent)
:ok = ExRocket.purge_old_backups("/path/to/backup", 5)

# Restore from latest backup
:ok = ExRocket.restore_from_backup("/path/to/backup", "/path/to/restore")

# Restore from specific backup ID
:ok = ExRocket.restore_from_backup("/path/to/backup", "/path/to/restore", 3)
```

## Common Patterns

### Database Options

Use exact native decoder keys. Unknown keys return
`{:error, {:unknown_option, key}}` and malformed values return
`{:error, {:invalid_option, key}}`; they are never silently ignored. See
[`OPTIONS.md`](OPTIONS.md) for the complete accepted inventory.

```elixir
options = %{
  create_if_missing: true,
  merge_operator: "erlang_merge_operator",
  set_max_open_files: 1000,
  set_write_buffer_size: 64 * 1024 * 1024,  # 64MB
  set_target_file_size_base: 64 * 1024 * 1024,
  set_max_bytes_for_level_base: 256 * 1024 * 1024
}

{:ok, db} = ExRocket.open("path/to/db", options)
```

### Error Handling
```elixir
case ExRocket.get(db, "key") do
  {:ok, value} ->
    IO.puts("Found: #{value}")
  :undefined ->
    IO.puts("Key not found")
  {:error, reason} ->
    IO.puts("Error: #{reason}")
end
```

### ETF Serialization Best Practices
```elixir
# Store complex Elixir terms
term = %{users: ["alice", "bob"], count: 42}
binary_term = :erlang.term_to_binary(term)
:ok = ExRocket.put(db, "complex_data", binary_term)

# Retrieve and deserialize
{:ok, restored_term} = ExRocket.getb(db, "complex_data")
# restored_term == %{users: ["alice", "bob"], count: 42}

# Or use merge operations with automatic serialization
:ok = ExRocket.mergeb(db, "settings", {:list_append, [:new_setting]})
```

## Utilities

```elixir
# Check ExRocket version/code
{:ok, :vsn1} = ExRocket.lxcode()
```

---

*For more detailed information about specific features, see the test files in `test/` directory.*