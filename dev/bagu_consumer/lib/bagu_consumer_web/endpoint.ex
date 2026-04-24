defmodule BaguConsumerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :bagu_consumer

  @session_options [
    store: :cookie,
    key: "_bagu_consumer_key",
    signing_salt: "bagu-live-view"
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
  plug BaguConsumerWeb.Router
end
