import Config

config :jidoka,
  model_aliases: %{
    fast: "anthropic:claude-haiku-4-5"
  }

config :anubis_mcp,
  log: false,
  session_store: [enabled: false]

mcp_sandbox = Path.expand("../tmp/mcp-sandbox", __DIR__)

config :jido_mcp, :endpoints,
  local_fs: %{
    transport:
      {:stdio,
       [
         command: "sh",
         args: [
           "-c",
           "exec npx -y @modelcontextprotocol/server-filesystem \"$1\" 2>/dev/null",
           "jidoka-fs-mcp",
           mcp_sandbox
         ]
       ]},
    client_info: %{name: "jidoka-demo", version: "0.1.0"},
    timeouts: %{request_ms: 60_000}
  }

env_config = Path.expand("#{config_env()}.exs", __DIR__)

if File.exists?(env_config) do
  import_config "#{config_env()}.exs"
end
