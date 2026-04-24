import Config

config :bagu, :model_aliases, fast: "anthropic:claude-haiku-4-5"

config :bagu_consumer, BaguConsumerWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  server: false,
  url: [host: "localhost"],
  secret_key_base: "bagu-consumer-dev-secret-key-base-at-least-64-bytes-for-live-view-demo",
  render_errors: [
    formats: [html: BaguConsumerWeb.ErrorHTML],
    layout: false
  ],
  pubsub_server: BaguConsumer.PubSub,
  live_view: [signing_salt: "bagu-live-view"]

config :phoenix, :json_library, Jason
