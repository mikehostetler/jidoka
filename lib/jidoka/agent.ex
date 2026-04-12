defmodule Jidoka.Agent do
  @moduledoc """
  Primary public runtime API for Jidoka sessions.
  """

  alias Jido.Signal
  alias Jidoka.Bus
  alias Jidoka.Runtime
  alias Jidoka.Signals

  @typedoc "Canonical stable handle for a Jidoka session."
  @type session_ref :: String.t()

  @typedoc "Public runtime calls accept a stable session ref or a live pid."
  @type session_handle :: session_ref() | pid()

  @type request_id :: String.t()
  @type snapshot :: map()

  @spec open(keyword()) :: {:ok, session_ref()} | {:error, term()}
  def open(opts \\ []) do
    Runtime.open(opts)
  end

  @spec resume(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def resume(session) do
    Runtime.resume(session)
  end

  @spec lookup(session_handle()) :: {:ok, %{session_ref: session_ref(), pid: pid()}} | {:error, term()}
  def lookup(session) do
    Runtime.lookup(session)
  end

  @spec close(session_handle()) :: :ok | {:error, term()}
  def close(session) do
    with {:ok, session_ref} <- normalize_session(session) do
      Runtime.close(session_ref)
    end
  end

  @spec ask(session_handle(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ask(session, prompt, opts \\ []) when is_binary(prompt) do
    with {:ok, session_ref} <- normalize_session(session) do
      request_id = Keyword.get_lazy(opts, :request_id, fn -> Signals.generate_id("req") end)

      signal =
        Signals.command(session_ref, :ask, %{
          action: "ask",
          prompt: prompt,
          request_id: request_id,
          opts: Map.new(opts)
        })

      dispatch(session_ref, signal)
    end
  end

  @spec await(session_handle(), request_id() | map(), keyword()) :: {:ok, map()} | {:error, term()}
  def await(session, request, opts \\ []) do
    with {:ok, session_ref} <- normalize_session(session) do
      request_id =
        case request do
          %{id: id} -> id
          id when is_binary(id) -> id
        end

      signal =
        Signals.command(session_ref, :await, %{
          action: "await",
          request_id: request_id,
          opts: Map.new(opts)
        })

      dispatch(session_ref, signal)
    end
  end

  @spec steer(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def steer(session, message, opts \\ []) when is_binary(message) do
    with {:ok, session_ref} <- normalize_session(session) do
      signal =
        Signals.command(session_ref, :steer, %{
          action: "steer",
          message: message,
          opts: Map.new(opts)
        })

      case dispatch(session_ref, signal) do
        {:ok, :ok} -> :ok
        other -> other
      end
    end
  end

  @spec inject(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def inject(session, message, opts \\ []) when is_binary(message) do
    with {:ok, session_ref} <- normalize_session(session) do
      signal =
        Signals.command(session_ref, :inject, %{
          action: "inject",
          message: message,
          role: Keyword.get(opts, :role, "system"),
          opts: Map.new(opts)
        })

      case dispatch(session_ref, signal) do
        {:ok, :ok} -> :ok
        other -> other
      end
    end
  end

  @spec branch(session_handle(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def branch(session, opts \\ []) do
    with {:ok, session_ref} <- normalize_session(session) do
      signal =
        Signals.command(session_ref, :branch, %{
          action: "branch",
          label: Keyword.get(opts, :label),
          branch_id: Keyword.get(opts, :branch_id),
          opts: Map.new(opts)
        })

      dispatch(session_ref, signal)
    end
  end

  @spec navigate(session_handle(), String.t(), keyword()) :: {:ok, snapshot()} | {:error, term()}
  def navigate(session, branch_id, opts \\ []) when is_binary(branch_id) do
    with {:ok, session_ref} <- normalize_session(session) do
      signal =
        Signals.command(session_ref, :navigate, %{
          action: "navigate",
          branch_id: branch_id,
          opts: Map.new(opts)
        })

      dispatch(session_ref, signal)
    end
  end

  @spec refresh_resources(session_handle(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_resources(session, opts \\ []) do
    with {:ok, session_ref} <- normalize_session(session) do
      signal =
        Signals.command(session_ref, :refresh_resources, %{
          action: "refresh_resources",
          opts: Map.new(opts)
        })

      dispatch(session_ref, signal)
    end
  end

  @spec snapshot(session_handle()) :: {:ok, snapshot()} | {:error, term()}
  def snapshot(session) do
    with {:ok, session_ref} <- normalize_session(session) do
      Runtime.snapshot(session_ref)
    end
  end

  @spec dispatch(session_handle(), Signal.t()) :: {:ok, term()} | {:error, term()}
  def dispatch(session, %Signal{} = signal) do
    with {:ok, session_ref} <- normalize_session(session),
         {:ok, _published} <- Bus.publish(signal) do
      Runtime.dispatch(session_ref, signal)
    end
  end

  @spec normalize_session(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def normalize_session(session_ref) when is_binary(session_ref), do: {:ok, session_ref}

  def normalize_session(pid) when is_pid(pid) do
    Runtime.session_ref(pid)
  end

  def normalize_session(other), do: {:error, {:invalid_session_handle, other}}
end
