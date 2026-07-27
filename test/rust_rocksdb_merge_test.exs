defmodule ExRocket.RustRocksDBMergeTest do
  use ExUnit.Case, async: false

  setup do
    db_path =
      Path.join(System.tmp_dir!(), "rust_rocksdb_merge_#{System.unique_integer([:positive])}")

    ExRocket.RustRocksDB.destroy(db_path)
    on_exit(fn -> ExRocket.RustRocksDB.destroy(db_path) end)
    %{db_path: db_path}
  end

  describe "counter merge operator" do
    test "counter merge basic functionality", context do
      path = context.db_path

      # Open database with counter merge operator
      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "counter_merge_operator"
        })

      # Test merging with no existing value
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "1")
      assert {:ok, "1"} == ExRocket.RustRocksDB.get(db, "counter")

      # Test merging with existing value
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "2")
      assert {:ok, "3"} == ExRocket.RustRocksDB.get(db, "counter")

      # Test merging with negative value
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "-1")
      assert {:ok, "2"} == ExRocket.RustRocksDB.get(db, "counter")

      # Test multiple merges
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "5")
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "3")
      assert {:ok, "10"} == ExRocket.RustRocksDB.get(db, "counter")

      # Test with new key
      assert :ok == ExRocket.RustRocksDB.merge(db, "new_counter", "42")
      assert {:ok, "42"} == ExRocket.RustRocksDB.get(db, "new_counter")
    end

    test "counter merge with put operation", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "counter_merge_operator"
        })

      # Put initial value
      assert :ok == ExRocket.RustRocksDB.put(db, "counter", "10")
      assert {:ok, "10"} == ExRocket.RustRocksDB.get(db, "counter")

      # Merge with existing put value
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "5")
      assert {:ok, "15"} == ExRocket.RustRocksDB.get(db, "counter")

      # Put over merged value
      assert :ok == ExRocket.RustRocksDB.put(db, "counter", "0")
      assert {:ok, "0"} == ExRocket.RustRocksDB.get(db, "counter")

      # Merge again
      assert :ok == ExRocket.RustRocksDB.merge(db, "counter", "7")
      assert {:ok, "7"} == ExRocket.RustRocksDB.get(db, "counter")
    end

    test "counter merge error handling", context do
      path = context.db_path

      # Test without merge operator - should fail
      {:ok, db} = ExRocket.RustRocksDB.open(path, %{create_if_missing: true})

      # This should return an error since no merge operator is configured
      case ExRocket.RustRocksDB.merge(db, "counter", "1") do
        {:error, _reason} -> :ok
        :ok -> flunk("Expected merge to fail without merge operator")
      end
    end
  end

  describe "erlang merge operator" do
    test "basic functionality (simple string merge)", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # For now, the erlang merge operator falls back to counter behavior for simple strings
      assert :ok == ExRocket.RustRocksDB.merge(db, "simple_counter", "5")
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "simple_counter")
      assert "5" == result1

      # Test merging with existing value
      assert :ok == ExRocket.RustRocksDB.merge(db, "simple_counter", "3")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "simple_counter")
      assert "8" == result2
    end

    test "int_add operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Test merging with no existing value
      operand1 = :erlang.term_to_binary({:int_add, 5})
      assert :ok == ExRocket.RustRocksDB.merge(db, "int_counter", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "int_counter")
      assert 5 == :erlang.binary_to_term(result1)

      # Test merging with existing value
      operand2 = :erlang.term_to_binary({:int_add, 3})
      assert :ok == ExRocket.RustRocksDB.merge(db, "int_counter", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "int_counter")
      assert 8 == :erlang.binary_to_term(result2)

      # Test negative values
      operand3 = :erlang.term_to_binary({:int_add, -2})
      assert :ok == ExRocket.RustRocksDB.merge(db, "int_counter", operand3)
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "int_counter")
      assert 6 == :erlang.binary_to_term(result3)
    end

    test "list_append operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :b])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Append to existing list
      operand1 = :erlang.term_to_binary({:list_append, [:c, :d]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :b, :c, :d] == :erlang.binary_to_term(result1)

      # Append more elements
      operand2 = :erlang.term_to_binary({:list_append, [:e]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :b, :c, :d, :e] == :erlang.binary_to_term(result2)
    end

    test "list_prepend operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:c, :d])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Prepend elements to existing list
      operand1 = :erlang.term_to_binary({:list_prepend, [:a, :b]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :b, :c, :d] == :erlang.binary_to_term(result1)

      # Prepend more elements
      operand2 = :erlang.term_to_binary({:list_prepend, [:x, :y]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:x, :y, :a, :b, :c, :d] == :erlang.binary_to_term(result2)

      # Test prepend with empty list
      operand3 = :erlang.term_to_binary({:list_prepend, []})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand3)
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:x, :y, :a, :b, :c, :d] == :erlang.binary_to_term(result3)

      # Test prepend to non-existent key (should create new list)
      operand4 = :erlang.term_to_binary({:list_prepend, [:new, :list]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "new_list", operand4)
      {:ok, result4} = ExRocket.RustRocksDB.get(db, "new_list")
      assert [:new, :list] == :erlang.binary_to_term(result4)
    end

    test "combined list_append and list_prepend operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:middle])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Prepend elements
      operand1 = :erlang.term_to_binary({:list_prepend, [:start]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)

      # Append elements
      operand2 = :erlang.term_to_binary({:list_append, [:end]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)

      # Verify final result
      {:ok, result} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:start, :middle, :end] == :erlang.binary_to_term(result)

      # Test multiple prepends and appends
      operand3 = :erlang.term_to_binary({:list_prepend, [:very, :beginning]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand3)

      operand4 = :erlang.term_to_binary({:list_append, [:very, :end]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand4)

      {:ok, final_result} = ExRocket.RustRocksDB.get(db, "my_list")

      assert [:very, :beginning, :start, :middle, :end, :very, :end] ==
               :erlang.binary_to_term(final_result)
    end

    test "binary_append operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial binary
      initial_binary = :erlang.term_to_binary("hello")
      assert :ok == ExRocket.RustRocksDB.put(db, "my_binary", initial_binary)

      # Append to existing binary
      operand1 = :erlang.term_to_binary({:binary_append, " world"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello world" == :erlang.binary_to_term(result1)

      # Append more text
      operand2 = :erlang.term_to_binary({:binary_append, "!"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello world!" == :erlang.binary_to_term(result2)
    end

    test "list_subtract operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :b, :c, :d, :e])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Subtract elements
      operand1 = :erlang.term_to_binary({:list_subtract, [:b, :d]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :c, :e] == :erlang.binary_to_term(result1)

      # Subtract more elements
      operand2 = :erlang.term_to_binary({:list_subtract, [:a, :e]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:c] == :erlang.binary_to_term(result2)
    end

    test "list_set operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :b, :c])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Set element at position 1
      operand1 = :erlang.term_to_binary({:list_set, 1, :x})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :x, :c] == :erlang.binary_to_term(result1)

      # Set element at position 0
      operand2 = :erlang.term_to_binary({:list_set, 0, :y})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:y, :x, :c] == :erlang.binary_to_term(result2)
    end

    test "list_delete single position operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :b, :c, :d, :e])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Delete element at position 2
      operand1 = :erlang.term_to_binary({:list_delete, 2})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :b, :d, :e] == :erlang.binary_to_term(result1)

      # Delete element at position 0
      operand2 = :erlang.term_to_binary({:list_delete, 0})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:b, :d, :e] == :erlang.binary_to_term(result2)
    end

    test "list_delete range operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :b, :c, :d, :e, :f])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Delete range from position 1 to 4 (elements :b, :c, :d)
      operand1 = :erlang.term_to_binary({:list_delete, 1, 4})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :e, :f] == :erlang.binary_to_term(result1)

      # Delete range from position 0 to 2 (elements :a, :e)
      operand2 = :erlang.term_to_binary({:list_delete, 0, 2})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:f] == :erlang.binary_to_term(result2)
    end

    test "list_insert operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial list
      initial_list = :erlang.term_to_binary([:a, :c, :e])
      assert :ok == ExRocket.RustRocksDB.put(db, "my_list", initial_list)

      # Insert elements at position 1
      operand1 = :erlang.term_to_binary({:list_insert, 1, [:b, :x]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:a, :b, :x, :c, :e] == :erlang.binary_to_term(result1)

      # Insert elements at position 0 (beginning)
      operand2 = :erlang.term_to_binary({:list_insert, 0, [:start]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:start, :a, :b, :x, :c, :e] == :erlang.binary_to_term(result2)

      # Insert elements at end
      list_len = length(:erlang.binary_to_term(result2))
      operand3 = :erlang.term_to_binary({:list_insert, list_len, [:end]})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_list", operand3)
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "my_list")
      assert [:start, :a, :b, :x, :c, :e, :end] == :erlang.binary_to_term(result3)
    end

    test "binary_erase operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial binary
      initial_binary = :erlang.term_to_binary("hello world!")
      assert :ok == ExRocket.RustRocksDB.put(db, "my_binary", initial_binary)

      # Erase 6 bytes starting at position 5 (remove " world")
      operand1 = :erlang.term_to_binary({:binary_erase, 5, 6})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello!" == :erlang.binary_to_term(result1)

      # Erase 1 byte at position 5 (remove "!")
      operand2 = :erlang.term_to_binary({:binary_erase, 5, 1})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello" == :erlang.binary_to_term(result2)
    end

    test "binary_insert operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial binary
      initial_binary = :erlang.term_to_binary("hello")
      assert :ok == ExRocket.RustRocksDB.put(db, "my_binary", initial_binary)

      # Insert " world" at position 5 (end)
      operand1 = :erlang.term_to_binary({:binary_insert, 5, " world"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello world" == :erlang.binary_to_term(result1)

      # Insert "beautiful " at position 6 (after "hello ")
      operand2 = :erlang.term_to_binary({:binary_insert, 6, "beautiful "})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello beautiful world" == :erlang.binary_to_term(result2)

      # Insert "!" at the end
      current_len = byte_size(:erlang.binary_to_term(result2))
      operand3 = :erlang.term_to_binary({:binary_insert, current_len, "!"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand3)
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello beautiful world!" == :erlang.binary_to_term(result3)
    end

    test "binary_replace operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial binary
      initial_binary = :erlang.term_to_binary("hello world!")
      assert :ok == ExRocket.RustRocksDB.put(db, "my_binary", initial_binary)

      # Replace 5 bytes starting at position 6 (replace "world" with "there")
      operand1 = :erlang.term_to_binary({:binary_replace, 6, 5, "there"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand1)
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello there!" == :erlang.binary_to_term(result1)

      # Replace 1 byte at position 11 (replace "!" with "?")
      operand2 = :erlang.term_to_binary({:binary_replace, 11, 1, "?"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand2)
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello there?" == :erlang.binary_to_term(result2)

      # Replace with longer text
      operand3 = :erlang.term_to_binary({:binary_replace, 6, 5, "everyone"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand3)
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "hello everyone?" == :erlang.binary_to_term(result3)
    end

    test "mixed binary operations", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Start with initial binary
      initial_binary = :erlang.term_to_binary("test")
      assert :ok == ExRocket.RustRocksDB.put(db, "my_binary", initial_binary)

      # Multiple operations in sequence
      # 1. Append " string"
      operand1 = :erlang.term_to_binary({:binary_append, " string"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand1)

      # 2. Insert "ing " at position 4
      operand2 = :erlang.term_to_binary({:binary_insert, 4, "ing "})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand2)

      # 3. Replace "test" with "work"
      operand3 = :erlang.term_to_binary({:binary_replace, 0, 4, "work"})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand3)

      # 4. Erase "ing " (4 bytes at position 4)
      operand4 = :erlang.term_to_binary({:binary_erase, 4, 4})
      assert :ok == ExRocket.RustRocksDB.merge(db, "my_binary", operand4)

      {:ok, result} = ExRocket.RustRocksDB.get(db, "my_binary")
      assert "work string" == :erlang.binary_to_term(result)
    end
  end

  describe "bitset merge operator" do
    test "basic bit setting and clearing", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set bit at position 0
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+0")
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")
      assert <<1>> == result1

      # Set bit at position 3
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+3")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "bitset")
      # 00001001 (bits 0 and 3 set)
      assert <<9>> == result2

      # Clear bit at position 0
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "-0")
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "bitset")
      # 00001000 (only bit 3 set)
      assert <<8>> == result3
    end

    test "setting bits across byte boundaries", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set bit at position 15 (second byte, bit 7)
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+15")
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")
      # Second byte: 10000000
      assert <<0, 128>> == result1

      # Set bit at position 8 (second byte, bit 0)
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+8")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "bitset")
      # Second byte: 10000001
      assert <<0, 129>> == result2

      # Set bit at position 0 (first byte)
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+0")
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "bitset")
      assert <<1, 129>> == result3
    end

    test "clearing entire bitset", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set multiple bits
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+0")
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+5")
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+12")

      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")
      assert byte_size(result1) > 0

      # Clear entire bitset
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "bitset")
      assert <<>> == result2
    end

    test "multiple operations in sequence", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set bits 1, 3, 5
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+1")
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+3")
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+5")

      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")
      # 00101010 (bits 1, 3, 5 set)
      assert <<42>> == result1

      # Clear bit 3
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "-3")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "bitset")
      # 00100010 (bits 1, 5 set)
      assert <<34>> == result2

      # Set bit 7
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+7")
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "bitset")
      # 10100010 (bits 1, 5, 7 set)
      assert <<162>> == result3
    end

    test "clearing non-existent bits", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set bit 3
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+3")
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")
      assert <<8>> == result1

      # Try to clear bit 10 (beyond current bitset size)
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "-10")
      {:ok, result2} = ExRocket.RustRocksDB.get(db, "bitset")
      # Should remain unchanged
      assert <<8>> == result2

      # Clear existing bit 3
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "-3")
      {:ok, result3} = ExRocket.RustRocksDB.get(db, "bitset")
      assert <<0>> == result3
    end

    test "large bit positions", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Set bit at position 100
      assert :ok == ExRocket.RustRocksDB.merge(db, "bitset", "+100")
      {:ok, result1} = ExRocket.RustRocksDB.get(db, "bitset")

      # Should have 13 bytes (100 / 8 = 12, + 1 for the bit at position 100 % 8 = 4)
      assert byte_size(result1) == 13

      # Check that bit 4 in the 13th byte (index 12) is set
      <<_::binary-size(12), last_byte::integer>> = result1
      # 00010000 (bit 4 set)
      assert last_byte == 16
    end
  end

  describe "column family merge operations" do
    test "counter merge operator with column families", context do
      path = context.db_path

      # Open database with merge operator first
      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "counter_merge_operator"
        })

      # Create additional column family with merge operator
      assert :ok ==
               ExRocket.RustRocksDB.create_cf(db, "counters", %{
                 merge_operator: "counter_merge_operator"
               })

      # Test merge in custom column family
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "cf_counter", "10")
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "cf_counter", "3")
      {:ok, result1} = ExRocket.RustRocksDB.get_cf(db, "counters", "cf_counter")
      assert "13" == result1

      # Test more merge operations
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "cf_counter", "-5")
      {:ok, result2} = ExRocket.RustRocksDB.get_cf(db, "counters", "cf_counter")
      assert "8" == result2

      # Test merge in a different key
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "another_counter", "20")
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "another_counter", "5")
      {:ok, result3} = ExRocket.RustRocksDB.get_cf(db, "counters", "another_counter")
      assert "25" == result3
    end

    test "erlang merge operator with column families", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Create additional column family with merge operator
      assert :ok ==
               ExRocket.RustRocksDB.create_cf(db, "data", %{
                 merge_operator: "erlang_merge_operator"
               })

      # Test int_add operations in column family
      operand1 = :erlang.term_to_binary({:int_add, 5})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "int_counter", operand1)

      operand2 = :erlang.term_to_binary({:int_add, 10})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "int_counter", operand2)

      # Verify operations
      {:ok, result1} = ExRocket.RustRocksDB.get_cf(db, "data", "int_counter")
      assert 15 == :erlang.binary_to_term(result1)

      # Test list operations in column families
      initial_list = :erlang.term_to_binary([:b, :c])
      assert :ok == ExRocket.RustRocksDB.put_cf(db, "data", "my_list", initial_list)

      # Test append
      operand3 = :erlang.term_to_binary({:list_append, [:d, :e]})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "my_list", operand3)

      # Test prepend
      operand4 = :erlang.term_to_binary({:list_prepend, [:a]})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "my_list", operand4)

      {:ok, result3} = ExRocket.RustRocksDB.get_cf(db, "data", "my_list")
      assert [:a, :b, :c, :d, :e] == :erlang.binary_to_term(result3)
    end

    test "bitset merge operator with column families", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "bitset_merge_operator"
        })

      # Create additional column family with merge operator
      assert :ok ==
               ExRocket.RustRocksDB.create_cf(db, "flags", %{
                 merge_operator: "bitset_merge_operator"
               })

      # Test bitset operations in main database
      assert :ok == ExRocket.RustRocksDB.merge(db, "main_flags", "+0")
      assert :ok == ExRocket.RustRocksDB.merge(db, "main_flags", "+3")

      {:ok, result1} = ExRocket.RustRocksDB.get(db, "main_flags")
      # 00001001 (bits 0 and 3 set)
      assert <<9>> == result1

      # Test bitset operations in custom column family
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "flags", "user_flags", "+1")
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "flags", "user_flags", "+5")
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "flags", "user_flags", "+7")

      {:ok, result2} = ExRocket.RustRocksDB.get_cf(db, "flags", "user_flags")
      # 10100010 (bits 1, 5, 7 set)
      assert <<162>> == result2

      # Test clearing in one location doesn't affect the other
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "flags", "user_flags", "")

      {:ok, result3} = ExRocket.RustRocksDB.get(db, "main_flags")
      # Should remain unchanged
      assert <<9>> == result3

      {:ok, result4} = ExRocket.RustRocksDB.get_cf(db, "flags", "user_flags")
      # Should be cleared
      assert <<>> == result4
    end

    test "mixed merge operations across column families", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "erlang_merge_operator"
        })

      # Create column families with appropriate merge operators
      assert :ok ==
               ExRocket.RustRocksDB.create_cf(db, "counters", %{
                 merge_operator: "counter_merge_operator"
               })

      assert :ok ==
               ExRocket.RustRocksDB.create_cf(db, "data", %{
                 merge_operator: "erlang_merge_operator"
               })

      # Counter operations in counters CF (fallback behavior)
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "total", "100")
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "counters", "total", "50")

      # ETF operations in data CF
      operand1 = :erlang.term_to_binary({:int_add, 25})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "etf_counter", operand1)

      list_data = :erlang.term_to_binary([:item1])
      assert :ok == ExRocket.RustRocksDB.put_cf(db, "data", "items", list_data)

      operand2 = :erlang.term_to_binary({:list_append, [:item2, :item3]})
      assert :ok == ExRocket.RustRocksDB.merge_cf(db, "data", "items", operand2)

      # Verify all operations worked independently
      {:ok, counter_result} = ExRocket.RustRocksDB.get_cf(db, "counters", "total")
      assert "150" == counter_result

      {:ok, etf_result} = ExRocket.RustRocksDB.get_cf(db, "data", "etf_counter")
      assert 25 == :erlang.binary_to_term(etf_result)

      {:ok, list_result} = ExRocket.RustRocksDB.get_cf(db, "data", "items")
      assert [:item1, :item2, :item3] == :erlang.binary_to_term(list_result)
    end

    test "error handling for non-existent column families", context do
      path = context.db_path

      {:ok, db} =
        ExRocket.RustRocksDB.open(path, %{
          create_if_missing: true,
          merge_operator: "counter_merge_operator"
        })

      # Attempt to merge in non-existent column family should fail
      case ExRocket.RustRocksDB.merge_cf(db, "non_existent", "key", "5") do
        {:error, _reason} -> :ok
        :ok -> flunk("Expected merge_cf to fail for non-existent column family")
      end
    end
  end
end
