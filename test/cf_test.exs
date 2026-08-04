defmodule ExRocket.CF.Test do
  use ExRocket.Case, async: true

  describe "cf" do
    test "create_default", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "testcf")
    end

    test "open_cf_default", context do
      test = self()

      spawn(fn ->
        {:ok, db} = ExRocket.open(context.db_path)
        :ok = ExRocket.create_cf(db, "testcf1")
        :ok = ExRocket.create_cf(db, "testcf2")
        :ok = ExRocket.create_cf(db, "testcf3")

        send(test, :ok)
      end)

      assert_receive(:ok, 1000)
      {:error, _} = ExRocket.open(context.db_path)

      {:ok, db} =
        ExRocket.open_cf(
          context.db_path,
          ["testcf1", "testcf2", "testcf3"]
        )

      assert is_reference(db)
    end

    test "open_cf_for_read_only", context do
      test = self()

      spawn(fn ->
        {:ok, db} = ExRocket.open(context.db_path)
        :ok = ExRocket.create_cf(db, "testcf")
        :ok = ExRocket.put_cf(db, "testcf", "k1", "v1")

        send(test, :ok)
      end)

      assert_receive(:ok, 1000)

      {:ok, db} =
        ExRocket.open_cf_for_read_only(
          context.db_path,
          ["testcf"]
        )

      {:ok, "v1"} = ExRocket.get_cf(db, "testcf", "k1")

      {:error, "Not implemented: Not supported operation in read only mode."} =
        ExRocket.put_cf(db, "testcf", "k1", "v2")
    end

    test "list_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "testcf")
      {:ok, ["default", "testcf"]} = ExRocket.list_cf(context.db_path)
    end

    test "drop_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "testcf")
      {:ok, ["default", "testcf"]} = ExRocket.list_cf(context.db_path)
      :ok = ExRocket.drop_cf(db, "testcf")
      {:ok, ["default"]} = ExRocket.list_cf(context.db_path)
      {:error, _} = ExRocket.drop_cf(db, "testcf")
    end

    test "put_cf_get_cf", context do
      test = self()

      spawn(fn ->
        {:ok, db} = ExRocket.open(context.db_path)
        :ok = ExRocket.create_cf(db, "testcf")
        send(test, :ok)
      end)

      assert_receive(:ok, 1000)

      {:ok, db} =
        ExRocket.open_cf(
          context.db_path,
          ["testcf"]
        )

      :ok = ExRocket.put_cf(db, "testcf", "key", "value")
      {:ok, "value"} = ExRocket.get_cf(db, "testcf", "key")
      :undefined = ExRocket.get_cf(db, "testcf", "unknown")
    end

    test "put_cf_get_cf_multi", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "testcf")
      :ok = ExRocket.put_cf(db, "testcf", "key", "value")
      {:ok, "value"} = ExRocket.get_cf(db, "testcf", "key")
      :undefined = ExRocket.get_cf(db, "testcf", "unknown")
    end

    test "delete_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "testcf")
      :ok = ExRocket.put_cf(db, "testcf", "key", "value")
      {:ok, "value"} = ExRocket.get_cf(db, "testcf", "key")
      :ok = ExRocket.delete_cf(db, "testcf", "key")
      :undefined = ExRocket.get_cf(db, "testcf", "key")
    end

    test "create_iterator_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)
      :ok = ExRocket.put_cf(db, cf, "k0", "v0")

      {:ok, start_ref} = ExRocket.iterator_cf(db, cf, {:start})
      assert is_reference(start_ref)

      {:ok, end_ref} = ExRocket.iterator_cf(db, cf, {:end})
      assert is_reference(end_ref)

      {:ok, from_ref1} = ExRocket.iterator_cf(db, cf, {:from, "k0", :forward})
      assert is_reference(from_ref1)

      {:ok, from_ref2} = ExRocket.iterator_cf(db, cf, {:from, "k0", :reverse})
      assert is_reference(from_ref2)

      {:ok, from_ref3} = ExRocket.iterator_cf(db, cf, {:from, "k1", :forward})
      assert is_reference(from_ref3)

      {:ok, from_ref4} = ExRocket.iterator_cf(db, cf, {:from, "k1", :reverse})
      assert is_reference(from_ref4)
      {:ok, "k0", _} = ExRocket.next(from_ref4)
    end

    test "create_iterator_cf_not_found_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      {:error, :unknown_cf} = ExRocket.iterator_cf(db, cf, {:start})
    end

    test "next_start_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)
      :ok = ExRocket.put_cf(db, cf, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf, "k1", "v1")
      :ok = ExRocket.put_cf(db, cf, "k2", "v2")

      {:ok, iter} = ExRocket.iterator_cf(db, cf, {:start})
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_end_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)

      :ok = ExRocket.put_cf(db, cf, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf, "k1", "v1")
      :ok = ExRocket.put_cf(db, cf, "k2", "v2")

      {:ok, iter} = ExRocket.iterator_cf(db, cf, {:end})
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_from_forward_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)

      :ok = ExRocket.put_cf(db, cf, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf, "k1", "v1")
      :ok = ExRocket.put_cf(db, cf, "k2", "v2")

      {:ok, iter} = ExRocket.iterator_cf(db, cf, {:from, "k1", :forward})
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k2", "v2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "next_from_reverse_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)

      :ok = ExRocket.put_cf(db, cf, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf, "k1", "v1")
      :ok = ExRocket.put_cf(db, cf, "k2", "v2")

      {:ok, iter} = ExRocket.iterator_cf(db, cf, {:from, "k1", :reverse})
      {:ok, "k1", "v1"} = ExRocket.next(iter)
      {:ok, "k0", "v0"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)
    end

    test "prefix_iterator_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"

      :ok =
        ExRocket.create_cf(db, cf, %{
          set_prefix_extractor_prefix_length: 3
        })

      :ok = ExRocket.put_cf(db, cf, "aaa1", "va1")
      :ok = ExRocket.put_cf(db, cf, "bbb1", "vb1")
      :ok = ExRocket.put_cf(db, cf, "aaa2", "va2")
      {:ok, iter} = ExRocket.prefix_iterator_cf(db, cf, "aaa")
      true = is_reference(iter)
      {:ok, "aaa1", "va1"} = ExRocket.next(iter)
      {:ok, "aaa2", "va2"} = ExRocket.next(iter)
      :end_of_iterator = ExRocket.next(iter)

      {:ok, iter2} = ExRocket.prefix_iterator_cf(db, cf, "bbb")
      true = is_reference(iter2)
      {:ok, "bbb1", "vb1"} = ExRocket.next(iter2)
      :end_of_iterator = ExRocket.next(iter2)
    end

    test "write_batch_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf1 = "test_cf1"
      :ok = ExRocket.create_cf(db, cf1)
      cf2 = "test_cf2"
      :ok = ExRocket.create_cf(db, cf2)

      :ok = ExRocket.put(db, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf1, "k0", "v0")
      :ok = ExRocket.put_cf(db, cf2, "k0", "v0")

      {:ok, 12} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:delete, "k0", "v0"},
          {:put, "k3", "v3"},
          {:put_cf, cf1, "k1", "v1"},
          {:put_cf, cf1, "k2", "v2"},
          {:delete_cf, cf1, "k0", "v0"},
          {:put_cf, cf1, "k3", "v3"},
          {:put_cf, cf2, "k1", "v1"},
          {:put_cf, cf2, "k2", "v2"},
          {:delete_cf, cf2, "k0", "v0"},
          {:put_cf, cf2, "k3", "v3"}
        ])

      :undefined = ExRocket.get(db, "k0")
      {:ok, "v1"} = ExRocket.get(db, "k1")
      {:ok, "v2"} = ExRocket.get(db, "k2")
      {:ok, "v3"} = ExRocket.get(db, "k3")

      :undefined = ExRocket.get_cf(db, cf1, "k0")
      {:ok, "v1"} = ExRocket.get_cf(db, cf1, "k1")
      {:ok, "v2"} = ExRocket.get_cf(db, cf1, "k2")
      {:ok, "v3"} = ExRocket.get_cf(db, cf1, "k3")

      :undefined = ExRocket.get_cf(db, cf2, "k0")
      {:ok, "v1"} = ExRocket.get_cf(db, cf2, "k1")
      {:ok, "v2"} = ExRocket.get_cf(db, cf2, "k2")
      {:ok, "v3"} = ExRocket.get_cf(db, cf2, "k3")
    end

    test "delete_range_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf1"
      :ok = ExRocket.create_cf(db, cf)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put_cf, cf, "k1", "v1"},
          {:put_cf, cf, "k2", "v2"},
          {:put_cf, cf, "k3", "v3"},
          {:put_cf, cf, "k4", "v4"},
          {:put_cf, cf, "k5", "v5"}
        ])

      :ok = ExRocket.delete_range_cf(db, cf, "k2", "k4")
      {:ok, "v1"} = ExRocket.get_cf(db, cf, "k1")
      :undefined = ExRocket.get_cf(db, cf, "k2")
      :undefined = ExRocket.get_cf(db, cf, "k3")
      {:ok, "v4"} = ExRocket.get_cf(db, cf, "k4")
      {:ok, "v5"} = ExRocket.get_cf(db, cf, "k5")
    end

    test "multi_get_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf1 = "test_cf1"
      :ok = ExRocket.create_cf(db, cf1)
      cf2 = "test_cf2"
      :ok = ExRocket.create_cf(db, cf2)
      cf3 = "test_cf3"
      :ok = ExRocket.create_cf(db, cf3)

      {:ok, 5} =
        ExRocket.write_batch(db, [
          {:put_cf, cf1, "k1", "v1"},
          {:put_cf, cf2, "k2", "v2"},
          {:put_cf, cf3, "k3", "v3"},
          {:put_cf, cf1, "k4", "v4"},
          {:put_cf, cf2, "k5", "v5"}
        ])

      {:ok,
       [
         {:ok, "v1"},
         :undefined,
         :undefined,
         {:ok, "v4"},
         :undefined,
         :undefined,
         {:ok, "v2"},
         :undefined,
         :undefined,
         {:ok, "v5"},
         :undefined,
         :undefined,
         {:ok, "v3"},
         :undefined,
         :undefined
       ]} =
        ExRocket.multi_get_cf(db, [
          {cf1, "k1"},
          {cf1, "k2"},
          {cf1, "k3"},
          {cf1, "k4"},
          {cf1, "k5"},
          {cf2, "k1"},
          {cf2, "k2"},
          {cf2, "k3"},
          {cf2, "k4"},
          {cf2, "k5"},
          {cf3, "k1"},
          {cf3, "k2"},
          {cf3, "k3"},
          {cf3, "k4"},
          {cf3, "k5"}
        ])
    end

    test "iterator_take pages column-family and prefix iterators", context do
      {:ok, db} =
        ExRocket.open(context.db_path, %{set_prefix_extractor_prefix_length: 3})

      :ok = ExRocket.create_cf(db, "rows", %{set_prefix_extractor_prefix_length: 3})

      assert {:ok, 3} =
               ExRocket.write_batch(db, [
                 {:put_cf, "rows", "pre1", "v1"},
                 {:put_cf, "rows", "pre2", "v2"},
                 {:put_cf, "rows", "zzz1", "v3"}
               ])

      {:ok, iter} = ExRocket.iterator_cf(db, "rows", {:start})

      assert {:ok, [{"pre1", "v1"}, {"pre2", "v2"}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 2})

      assert {:ok, [{"zzz1", "v3"}], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 2})

      {:ok, prefix_iter} = ExRocket.prefix_iterator_cf(db, "rows", "pre")

      assert {:ok, [{"pre1", "v1"}, {"pre2", "v2"}], :end_of_iterator} =
               ExRocket.iterator_take(prefix_iter, %{max_entries: 10})
    end

    test "key_may_exist_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf1"
      :ok = ExRocket.create_cf(db, cf)
      {:ok, false} = ExRocket.key_may_exist_cf(db, cf, "k1")
      :ok = ExRocket.put_cf(db, cf, "k1", "v1")
      {:ok, true} = ExRocket.key_may_exist_cf(db, cf, "k1")
    end
  end
end
