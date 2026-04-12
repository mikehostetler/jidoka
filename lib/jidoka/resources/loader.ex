defmodule Jidoka.Resources.Loader do
  @moduledoc false

  @project_resource_files ["AGENTS.md"]
  @home_resource_files ["AGENTS.md", "config.toml"]

  @spec load(keyword()) :: map()
  def load(opts \\ []) do
    cwd = Keyword.get_lazy(opts, :cwd, &File.cwd!/0)
    home = Keyword.get(opts, :home, default_home())
    epoch = Keyword.get(opts, :epoch, 1)

    manifest =
      project_entries(cwd)
      |> Kernel.++(home_entries(home))

    %{
      epoch: epoch,
      cwd: cwd,
      home: home,
      manifest: manifest,
      version: manifest_version(manifest),
      effective_prompt: effective_prompt(manifest)
    }
  end

  @spec refresh(map(), keyword()) :: map()
  def refresh(resources, opts \\ []) do
    load(
      cwd: Keyword.get(opts, :cwd, resources.cwd),
      home: Keyword.get(opts, :home, resources.home),
      epoch: resources.epoch + 1
    )
  end

  @spec default_home() :: String.t()
  def default_home do
    System.get_env("JIDOKA_HOME") || Path.join(System.user_home!(), ".jidoka")
  end

  defp project_entries(cwd) do
    build_entries(cwd, @project_resource_files, :project)
  end

  defp home_entries(home) do
    build_entries(home, @home_resource_files, :home)
  end

  defp build_entries(root, files, scope) do
    Enum.flat_map(files, fn relative ->
      path = Path.join(root, relative)

      if File.regular?(path) do
        content = File.read!(path)

        [
          %{
            scope: scope,
            kind: Path.basename(relative),
            path: path,
            digest: digest(content),
            content: content
          }
        ]
      else
        []
      end
    end)
  end

  defp manifest_version(manifest) do
    manifest
    |> Enum.map_join(":", & &1.digest)
    |> digest()
  end

  defp effective_prompt(manifest) do
    manifest
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")
  end

  defp digest(content) when is_binary(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end
end
