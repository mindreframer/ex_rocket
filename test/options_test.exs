defmodule ExRocket.OptionsTest do
  use ExRocket.Case, async: true

  @root Path.expand("..", __DIR__)

  test "database option keys are exact across decoder and canonical documentation" do
    source = File.read!(Path.join(@root, "native/rocker/src/options.rs"))
    docs = File.read!(Path.join(@root, "OPTIONS.md"))

    decoder = source |> section("pub fn decode(term", "fn validate(&self)") |> decoder_keys()

    documented =
      docs
      |> section("## Database And Column-Family Options", "## Range-Iterator Read Options")
      |> table_keys()

    fields =
      source
      |> section("pub struct RockerOptions", "impl Default for RockerOptions")
      |> then(&Regex.scan(~r/^\s*pub (\w+): Option</m, &1, capture: :all_but_first))
      |> List.flatten()
      |> MapSet.new()

    assert decoder == documented
    assert MapSet.subset?(decoder, fields)
    assert MapSet.size(decoder) == 96
  end

  test "read, write, and iterator option keys match canonical documentation" do
    docs = File.read!(Path.join(@root, "OPTIONS.md"))

    assert decoder_keys(File.read!(Path.join(@root, "native/rocker/src/read_options.rs"))) ==
             documented_keys(docs, "## Range-Iterator Read Options", "## Batch Write Options")

    assert decoder_keys(File.read!(Path.join(@root, "native/rocker/src/write_options.rs"))) ==
             documented_keys(docs, "## Batch Write Options", "## Iterator-Take Options")

    assert decoder_keys(File.read!(Path.join(@root, "native/rocker/src/iterator_options.rs"))) ==
             documented_keys(docs, "## Iterator-Take Options", nil)
  end

  test "unknown database options fail before open or maintenance", %{db_path: path} do
    assert {:error, {:unknown_option, :max_open_files}} =
             ExRocket.open(path, %{max_open_files: 10})

    refute File.exists?(path)

    assert {:error, {:unknown_option, :unknown_destroy_option}} =
             ExRocket.destroy(path, %{unknown_destroy_option: true})

    assert {:error, {:unknown_option, :unknown_repair_option}} =
             ExRocket.repair(path, %{unknown_repair_option: true})

    assert {:error, {:unknown_option, :unknown_list_option}} =
             ExRocket.list_cf(path, %{unknown_list_option: true})
  end

  test "unknown database options fail for CF lifecycle calls", %{db_path: path} do
    assert {:ok, db} = ExRocket.open(path)

    assert {:error, {:unknown_option, :unknown_cf_option}} =
             ExRocket.create_cf(db, "rows", %{unknown_cf_option: true})

    assert :ok = ExRocket.close(db)

    assert {:error, {:unknown_option, :unknown_open_cf_option}} =
             ExRocket.open_cf(path, [], %{unknown_open_cf_option: true})

    assert {:error, {:unknown_option, :unknown_read_only_option}} =
             ExRocket.open_cf_for_read_only(path, [], %{unknown_read_only_option: true})
  end

  test "malformed database values and constrained strings return named errors", %{db_path: path} do
    assert {:error, {:invalid_option, :options}} = ExRocket.open(path, [])

    assert {:error, {:invalid_option, :set_max_open_files}} =
             ExRocket.open(path, %{set_max_open_files: "many"})

    assert {:error, {:invalid_option, :set_compaction_style}} =
             ExRocket.open(path, %{set_compaction_style: "surprise"})

    assert {:error, {:invalid_option, :set_compression_type}} =
             ExRocket.open(path, %{set_compression_type: "brotli"})

    assert {:error, {:invalid_option, :set_max_bytes_for_level_multiplier_additional}} =
             ExRocket.open(path, %{set_max_bytes_for_level_multiplier_additional: "1,nope"})

    assert {:error, {:invalid_option, :set_ratelimiter}} =
             ExRocket.open(path, %{set_ratelimiter: "100,200"})

    refute File.exists?(path)
  end

  test "read options reject unknown and malformed values without returning an iterator", %{
    db_path: path
  } do
    assert {:ok, db} = ExRocket.open(path)

    assert {:error, {:unknown_option, :upper_bound}} =
             ExRocket.iterator_range(
               db,
               {:start},
               :undefined,
               :undefined,
               %{upper_bound: "z"}
             )

    assert {:error, {:invalid_option, :iterate_upper_bound}} =
             ExRocket.iterator_range(
               db,
               {:start},
               :undefined,
               :undefined,
               %{iterate_upper_bound: 123}
             )
  end

  test "canonical option examples open successfully", %{db_path: path} do
    assert {:ok, db} =
             ExRocket.open(path, %{
               create_if_missing: true,
               set_max_open_files: 128,
               set_write_buffer_size: 8 * 1024 * 1024,
               set_target_file_size_base: 8 * 1024 * 1024,
               set_max_bytes_for_level_base: 32 * 1024 * 1024,
               set_compaction_style: "Level",
               set_compression_type: "Lz4"
             })

    assert :ok = ExRocket.close(db)
  end

  test "public examples contain no stale option aliases or iterator terminal", _context do
    docs =
      Enum.map_join(["README.md", "CHEATSHEET.md"], "\n", fn path ->
        File.read!(Path.join(@root, path))
      end)

    refute docs =~ ~r/(?<!set_)max_open_files:/
    refute docs =~ ~r/(?<!set_)write_buffer_size:/
    refute docs =~ ~r/(?<!set_)target_file_size_base:/
    refute docs =~ ~r/(?<!set_)max_bytes_for_level_base:/
    refute docs =~ ":end_of_table"
  end

  defp documented_keys(docs, start_marker, nil) do
    docs |> section(start_marker, nil) |> table_keys()
  end

  defp documented_keys(docs, start_marker, end_marker) do
    docs |> section(start_marker, end_marker) |> table_keys()
  end

  defp decoder_keys(source) do
    source
    |> then(&Regex.scan(~r/^\s+"([a-z0-9_]+)" =>/m, &1, capture: :all_but_first))
    |> List.flatten()
    |> MapSet.new()
  end

  defp table_keys(source) do
    source
    |> then(&Regex.scan(~r/^\| `([a-z0-9_]+)` \|/m, &1, capture: :all_but_first))
    |> List.flatten()
    |> MapSet.new()
  end

  defp section(source, start_marker, nil) do
    [_before, selected] = String.split(source, start_marker, parts: 2)
    selected
  end

  defp section(source, start_marker, end_marker) do
    [_before, rest] = String.split(source, start_marker, parts: 2)
    [selected, _after] = String.split(rest, end_marker, parts: 2)
    selected
  end
end
