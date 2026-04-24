defmodule JidokaConsumerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :jidoka_consumer

  @session_options [
    store: :cookie,
    key: "_jidoka_consumer_key",
    signing_salt: "jidoka-live-view"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug JidokaConsumerWeb.Router
end
