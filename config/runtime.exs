import Config
import Dotenvy

app_root = System.get_env("RELEASE_ROOT") || Path.expand("..", __DIR__)

source!([
  System.get_env(),
  Path.join(app_root, ".env"),
  System.get_env()
])

config :req_llm,
  anthropic_api_key: env!("ANTHROPIC_API_KEY", :string, nil)
