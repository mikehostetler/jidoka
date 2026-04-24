import Config

config :jidoka, :model_aliases, fast: "anthropic:claude-haiku-4-5"

config :jidoka_consumer, JidokaConsumerWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  url: [host: "localhost"],
  secret_key_base: "jidoka-consumer-dev-secret-key-base-at-least-64-bytes-for-live-view-demo",
  render_errors: [
    formats: [html: JidokaConsumerWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: JidokaConsumer.PubSub,
  live_view: [signing_salt: "jidoka-live-view"]

config :phoenix, :json_library, Jason
