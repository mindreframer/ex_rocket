defmodule ExRocket.Iterator.Test do
  use ExRocket.Case, async: true

  describe "iterator" do
    test "create_iterator", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")

      {:ok, start_ref} = ExRocket.iterator(db, {:start})
      assert is_reference(start_ref)

      {:ok, end_ref} = ExRocket.iterator(db, {:end})
      assert is_reference(end_ref)

      {:ok, from_ref1} = ExRocket.iterator(db, {:from, "k0", :forward})
      assert is_reference(from_ref1)

      {:ok, from_ref2} = ExRocket.iterator(db, {:from, "k0", :reverse})
      assert is_reference(from_ref2)

      {:ok, from_ref3} = ExRocket.iterator(db, {:from, "k1", :forward})
      assert is_reference(from_ref3)

      {:ok, from_ref4} = ExRocket.iterator(db, {:from, "k1", :reverse})
      assert is_reference(from_ref4)
      {:ok, "k0", _} = ExRocket.next(from_ref4)
    end

    test "next_start", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")
      :ok = ExRocket.put(db, "k1", "v1")
      :ok = ExRocket.put(db, "k2", "v2")

      {:ok, iter} = ExRocket.iterator(db, {:start})
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_end", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")
      :ok = ExRocket.put(db, "k1", "v1")
      :ok = ExRocket.put(db, "k2", "v2")

      {:ok, iter} = ExRocket.iterator(db, {:end})
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_from_forward", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")
      :ok = ExRocket.put(db, "k1", "v1")
      :ok = ExRocket.put(db, "k2", "v2")

      {:ok, iter} = ExRocket.iterator(db, {:from, "k1", :forward})
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_from_reverse", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")
      :ok = ExRocket.put(db, "k1", "v1")
      :ok = ExRocket.put(db, "k2", "v2")

      {:ok, iter} = ExRocket.iterator(db, {:from, "k1", :reverse})
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "prefix_iterator", context do
      {:ok, db} =
        ExRocket.open(context.db_path, %{
          set_prefix_extractor_prefix_length: 3,
          create_if_missing: true
        })

      :ok = ExRocket.put(db, "aaa1", "va1")
      :ok = ExRocket.put(db, "bbb1", "vb1")
      :ok = ExRocket.put(db, "aaa2", "va2")
      {:ok, iter} = ExRocket.prefix_iterator(db, "aaa")
      true = is_reference(iter)
      {:ok, "aaa1", "va1"} = ExRocket.next(iter)
      {:ok, "aaa2", "va2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)

      {:ok, iter2} = ExRocket.prefix_iterator(db, "bbb")
      true = is_reference(iter2)
      {:ok, "bbb1", "vb1"} = ExRocket.next(iter2)
      :end_of_iterator = ExRocket.next(iter2)
    end

    test "iterator_range_start", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:start}, "k2", "k4")
      true = is_reference(iter)

      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k3", "v3"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_end", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:end}, "k2", "k4")
      true = is_reference(iter)

      {:ok, "k3", "v3"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_from", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:from, "k3", :forward}, "k2", "k5")
      true = is_reference(iter)

      {:ok, "k3", "v3"} = ExRocket.next(iter)
      {:ok, "k4", "v4"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_from_reverse", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:from, "k3", :reverse}, "k2", "k5")
      true = is_reference(iter)

      {:ok, "k3", "v3"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_undefined_left_border", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:start}, :undefined, "k4")
      true = is_reference(iter)

      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k3", "v3"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_undefined_right_border", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:start}, "k2", :undefined)
      true = is_reference(iter)

      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k3", "v3"} = ExRocket.next(iter)
      {:ok, "k4", "v4"} = ExRocket.next(iter)
      {:ok, "k5", "v5"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "iterator_range_undefined_both_borders", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"},
          {:put, "k4", "v4"},
          {:put, "k5", "v5"}
        ])

      {:ok, iter} = ExRocket.iterator_range(db, {:start}, :undefined, :undefined)
      true = is_reference(iter)

      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k3", "v3"} = ExRocket.next(iter)
      {:ok, "k4", "v4"} = ExRocket.next(iter)
      {:ok, "k5", "v5"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end
  end

  describe "iterator_take/2" do
    test "returns an empty exhausted page", context do
      {:ok, db} = ExRocket.open(context.db_path)
      {:ok, iter} = ExRocket.iterator(db, {:start})

      assert {:ok, [], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 10})
    end

    test "preserves exact entry-bound status and exact-once continuation", context do
      {:ok, db} = ExRocket.open(context.db_path)

      assert {:ok, 3} =
               ExRocket.write_batch(db, [
                 {:put, "k1", "v1"},
                 {:put, "k2", "v2"},
                 {:put, "k3", "v3"}
               ])

      {:ok, iter} = ExRocket.iterator(db, {:start})

      assert {:ok, [{"k1", "v1"}, {"k2", "v2"}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 2})

      assert {:ok, [{"k3", "v3"}], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 2})

      assert {:ok, [], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 2})

      {:ok, exact_iter} = ExRocket.iterator(db, {:start})

      assert {:ok, [{"k1", "v1"}, {"k2", "v2"}, {"k3", "v3"}], :more} =
               ExRocket.iterator_take(exact_iter, %{max_entries: 3})

      assert {:ok, [], :end_of_iterator} =
               ExRocket.iterator_take(exact_iter, %{max_entries: 3})
    end

    test "enforces payload bounds without losing a buffered row", context do
      {:ok, db} = ExRocket.open(context.db_path)

      assert {:ok, 3} =
               ExRocket.write_batch(db, [
                 {:put, "a", "111"},
                 {:put, "b", "222"},
                 {:put, "c", "333"}
               ])

      {:ok, iter} = ExRocket.iterator(db, {:start})

      assert {:ok, [{"a", "111"}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 10, max_bytes: 5})

      assert {:ok, "b", "222"} = ExRocket.next(iter)

      assert {:ok, [{"c", "333"}], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 10, max_bytes: 5})
    end

    test "returns one oversized first row to guarantee progress", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "oversized", :binary.copy(<<0, 255>>, 32))
      {:ok, iter} = ExRocket.iterator(db, {:start})

      assert {:ok, [{"oversized", value}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 10, max_bytes: 1})

      assert value == :binary.copy(<<0, 255>>, 32)
      assert {:ok, [], :end_of_iterator} = ExRocket.iterator_take(iter, %{max_entries: 10})
    end

    test "works with range and prefix iterator boundaries", context do
      {:ok, db} = ExRocket.open(context.db_path, %{set_prefix_extractor_prefix_length: 3})

      assert {:ok, 4} =
               ExRocket.write_batch(db, [
                 {:put, "pre1", "v1"},
                 {:put, "pre2", "v2"},
                 {:put, "pre3", "v3"},
                 {:put, "zzz1", "v4"}
               ])

      {:ok, range_iter} = ExRocket.iterator_range(db, {:start}, "pre2", "zzz1")

      assert {:ok, [{"pre2", "v2"}, {"pre3", "v3"}], :end_of_iterator} =
               ExRocket.iterator_take(range_iter, %{max_entries: 10})

      {:ok, prefix_iter} = ExRocket.prefix_iterator(db, "pre")

      assert {:ok, [{"pre1", "v1"}, {"pre2", "v2"}], :more} =
               ExRocket.iterator_take(prefix_iter, %{max_entries: 2})

      assert {:ok, [{"pre3", "v3"}], :end_of_iterator} =
               ExRocket.iterator_take(prefix_iter, %{max_entries: 2})
    end

    test "rejects invalid options without advancing and supports reverse binary rows", context do
      {:ok, db} = ExRocket.open(context.db_path)
      key1 = <<0, 1>>
      key2 = <<0, 2>>
      :ok = ExRocket.put(db, key1, <<255, 1>>)
      :ok = ExRocket.put(db, key2, <<255, 2>>)
      {:ok, iter} = ExRocket.iterator(db, {:end})

      assert {:error, :invalid_iterator_options} = ExRocket.iterator_take(iter, %{})

      assert {:error, :invalid_iterator_options} =
               ExRocket.iterator_take(iter, %{max_entries: 0})

      assert {:error, :invalid_iterator_options} =
               ExRocket.iterator_take(iter, %{max_entries: 100_001})

      assert {:error, :invalid_iterator_options} =
               ExRocket.iterator_take(iter, %{max_entries: 1, max_bytes: 67_108_865})

      assert {:error, {:unknown_option, :limit}} =
               ExRocket.iterator_take(iter, %{max_entries: 1, limit: 1})

      assert {:ok, [{^key2, <<255, 2>>}, {^key1, <<255, 1>>}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 2})
    end
  end
end
