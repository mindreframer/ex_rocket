defmodule ExRocket.Snapshot.Test do
  use ExRocket.Case, async: true

  describe "snapshot" do
    test "create_snapshot", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 2} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"}
        ])

      {:ok, {:snap, _, snap_ref} = snap} = ExRocket.snapshot(db)
      assert is_reference(snap_ref)
      :ok = ExRocket.put(db, "k3", "v3")

      {:ok, "v1"} = ExRocket.snapshot_get(snap, "k1")
      {:ok, "v2"} = ExRocket.snapshot_get(snap, "k2")
      :undefined = ExRocket.snapshot_get(snap, "k3")
      {:ok, "v3"} = ExRocket.get(db, "k3")
    end

    test "snapshot_multi_get", context do
      {:ok, db} = ExRocket.open(context.db_path)

      {:ok, 3} =
        ExRocket.write_batch(db, [
          {:put, "k1", "v1"},
          {:put, "k2", "v2"},
          {:put, "k3", "v3"}
        ])

      {:ok, snap} = ExRocket.snapshot(db)
      :ok = ExRocket.put(db, "k4", "v4")

      {:ok,
       [
         :undefined,
         {:ok, "v1"},
         {:ok, "v2"},
         {:ok, "v3"},
         :undefined,
         :undefined
       ]} =
        ExRocket.snapshot_multi_get(snap, [
          "k0",
          "k1",
          "k2",
          "k3",
          "k4",
          "k5"
        ])
    end

    test "snapshot_get_cf", context do
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

      :ok = ExRocket.put_cf(db, "testcf", "key1", "value1")
      {:ok, snap} = ExRocket.snapshot(db)
      :ok = ExRocket.put_cf(db, "testcf", "key2", "value2")

      {:ok, "value1"} = ExRocket.get_cf(db, "testcf", "key1")
      {:ok, "value2"} = ExRocket.get_cf(db, "testcf", "key2")

      {:ok, "value1"} = ExRocket.snapshot_get_cf(snap, "testcf", "key1")
      :undefined = ExRocket.snapshot_get_cf(snap, "testcf", "key2")
    end

    test "snapshot_multi_get_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf1 = "test_cf1"
      :ok = ExRocket.create_cf(db, cf1)
      cf2 = "test_cf2"
      :ok = ExRocket.create_cf(db, cf2)
      cf3 = "test_cf3"
      :ok = ExRocket.create_cf(db, cf3)

      {:ok, 3} =
        ExRocket.write_batch(db, [
          {:put_cf, cf1, "k1", "v1"},
          {:put_cf, cf2, "k2", "v2"},
          {:put_cf, cf3, "k3", "v3"}
        ])

      {:ok, snap} = ExRocket.snapshot(db)

      {:ok, 3} =
        ExRocket.write_batch(db, [
          {:put_cf, cf1, "k11", "v11"},
          {:put_cf, cf2, "k22", "v23"},
          {:put_cf, cf3, "k33", "v33"}
        ])

      {:ok,
       [
         {:ok, "v1"},
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         {:ok, "v2"},
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         :undefined,
         {:ok, "v3"},
         :undefined,
         :undefined,
         :undefined
       ]} =
        ExRocket.snapshot_multi_get_cf(snap, [
          {cf1, "k1"},
          {cf1, "k2"},
          {cf1, "k3"},
          {cf1, "k11"},
          {cf1, "k22"},
          {cf1, "k33"},
          {cf2, "k1"},
          {cf2, "k2"},
          {cf2, "k3"},
          {cf2, "k11"},
          {cf2, "k22"},
          {cf2, "k33"},
          {cf3, "k1"},
          {cf3, "k2"},
          {cf3, "k3"},
          {cf3, "k11"},
          {cf3, "k22"},
          {cf3, "k33"}
        ])
    end

    test "snapshot_iterator", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.put(db, "k0", "v0")
      {:ok, snap} = ExRocket.snapshot(db)

      {:ok, start_ref} = ExRocket.snapshot_iterator(snap, {:start})
      assert is_reference(start_ref)

      {:ok, end_ref} = ExRocket.snapshot_iterator(snap, {:end})
      assert is_reference(end_ref)

      {:ok, from_ref1} = ExRocket.snapshot_iterator(snap, {:from, "k0", :forward})
      assert is_reference(from_ref1)

      {:ok, from_ref2} = ExRocket.snapshot_iterator(snap, {:from, "k0", :reverse})
      assert is_reference(from_ref2)

      {:ok, from_ref3} = ExRocket.snapshot_iterator(snap, {:from, "k1", :forward})
      assert is_reference(from_ref3)

      {:ok, from_ref4} = ExRocket.snapshot_iterator(snap, {:from, "k1", :reverse})
      assert is_reference(from_ref4)

      {:ok, "k0", _} = ExRocket.next(from_ref4)
    end

    test "snapshot_iterator_cf", context do
      {:ok, db} = ExRocket.open(context.db_path)
      cf = "test_cf"
      :ok = ExRocket.create_cf(db, cf)
      :ok = ExRocket.put_cf(db, cf, "k0", "v0")

      {:ok, snap} = ExRocket.snapshot(db)

      {:ok, start_ref} = ExRocket.snapshot_iterator_cf(snap, cf, {:start})
      assert is_reference(start_ref)

      {:ok, end_ref} = ExRocket.snapshot_iterator_cf(snap, cf, {:end})
      assert is_reference(end_ref)

      {:ok, from_ref1} = ExRocket.snapshot_iterator_cf(snap, cf, {:from, "k0", :forward})
      assert is_reference(from_ref1)

      {:ok, from_ref2} = ExRocket.snapshot_iterator_cf(snap, cf, {:from, "k0", :reverse})
      assert is_reference(from_ref2)

      {:ok, from_ref3} = ExRocket.snapshot_iterator_cf(snap, cf, {:from, "k1", :forward})
      assert is_reference(from_ref3)

      {:ok, from_ref4} = ExRocket.snapshot_iterator_cf(snap, cf, {:from, "k1", :reverse})
      assert is_reference(from_ref4)

      {:ok, "k0", _} = ExRocket.next(from_ref4)
    end

    test "iterator_take preserves default and CF snapshot views across pages", context do
      {:ok, db} = ExRocket.open(context.db_path)
      :ok = ExRocket.create_cf(db, "rows")

      assert {:ok, 4} =
               ExRocket.write_batch(db, [
                 {:put, "k1", "before-1"},
                 {:put, "k2", "before-2"},
                 {:put_cf, "rows", "k1", "cf-before-1"},
                 {:put_cf, "rows", "k2", "cf-before-2"}
               ])

      {:ok, snap} = ExRocket.snapshot(db)
      {:ok, iter} = ExRocket.snapshot_iterator(snap, {:start})
      {:ok, cf_iter} = ExRocket.snapshot_iterator_cf(snap, "rows", {:start})

      assert {:ok, 4} =
               ExRocket.write_batch(db, [
                 {:put, "k1", "after-1"},
                 {:put, "k3", "after-3"},
                 {:put_cf, "rows", "k1", "cf-after-1"},
                 {:put_cf, "rows", "k3", "cf-after-3"}
               ])

      assert {:ok, [{"k1", "before-1"}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 1})

      assert {:ok, [{"k2", "before-2"}], :more} =
               ExRocket.iterator_take(iter, %{max_entries: 1})

      assert {:ok, [], :end_of_iterator} =
               ExRocket.iterator_take(iter, %{max_entries: 1})

      assert {:ok, [{"k1", "cf-before-1"}, {"k2", "cf-before-2"}], :end_of_iterator} =
               ExRocket.iterator_take(cf_iter, %{max_entries: 10})
    end
  end
end
