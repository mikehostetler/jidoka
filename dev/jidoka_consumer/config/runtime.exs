import Config
import Dotenvy

app_root = System.get_env("RELEASE_ROOT") || Path.expand("..", __DIR__)
workspace_root = Path.expand("../..", app_root)

default_react_token_secret =
  :crypto.hash(:sha256, "jidoka_consumer:react_token_secret:#{Path.expand(app_root)}")
  |> Base.url_encode64(padding: false)

source!([
  System.get_env(),
  Path.join(workspace_root, ".env"),
  Path.join(app_root, ".env"),
  System.get_env()
])

config :req_llm,
  anthropic_api_key: env!("ANTHROPIC_API_KEY", :string, nil)

config :jido_ai,
  react_token_secret:
    env!("REACT_TOKEN_SECRET", :string, System.get_env("REACT_TOKEN_SECRET")) ||
      default_react_token_secret
