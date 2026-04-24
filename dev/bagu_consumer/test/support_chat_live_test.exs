defmodule BaguConsumerWeb.SupportChatLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint BaguConsumerWeb.Endpoint

  test "renders separate visible message and LLM context panels" do
    {:ok, _view, html} =
      build_conn()
      |> init_test_session(%{"conversation_id" => "live-view-test"})
      |> live("/")

    assert html =~ "Bagu Support Agent"
    assert html =~ "Visible Messages"
    assert html =~ "LLM Context"
    assert html =~ "Debug Events"
    assert html =~ "Runtime Context"
  end
end
