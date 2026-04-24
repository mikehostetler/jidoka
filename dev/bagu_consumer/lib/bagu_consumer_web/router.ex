defmodule BaguConsumerWeb.Router do
  use BaguConsumerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BaguConsumerWeb do
    pipe_through :browser

    live "/", SupportChatLive, :index
  end
end
