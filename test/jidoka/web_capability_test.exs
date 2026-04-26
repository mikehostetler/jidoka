defmodule JidokaTest.WebCapabilityTest do
  use JidokaTest.Support.Case, async: false

  alias Jidoka.Web.Tools.{ReadPage, SearchWeb, SnapshotUrl}
  alias JidokaTest.{WebReadOnlyAgent, WebSearchAgent}

  test "compiled agents expose search-only web capabilities" do
    assert [%Jidoka.Web{mode: :search, tools: [SearchWeb]}] = WebSearchAgent.web()
    assert WebSearchAgent.web_tool_names() == ["search_web"]
    assert WebSearchAgent.tools() == [SearchWeb]
    assert WebSearchAgent.tool_names() == ["search_web"]
  end

  test "compiled agents expose read-only web capabilities" do
    assert [
             %Jidoka.Web{
               mode: :read_only,
               tools: [SearchWeb, ReadPage, SnapshotUrl]
             }
           ] = WebReadOnlyAgent.web()

    assert WebReadOnlyAgent.web_tool_names() == ["search_web", "read_page", "snapshot_url"]
    assert WebReadOnlyAgent.tools() == [SearchWeb, ReadPage, SnapshotUrl]
  end

  test "web page tools reject local and private URLs before browser startup" do
    assert {:error, %Jidoka.Error.ValidationError{} = read_error} =
             ReadPage.run(%{url: "http://localhost:4000"}, %{})

    assert read_error.field == :url
    assert Jidoka.format_error(read_error) =~ "private network URLs are not allowed"

    assert {:error, %Jidoka.Error.ValidationError{} = snapshot_error} =
             SnapshotUrl.run(%{url: "http://192.168.1.10"}, %{})

    assert snapshot_error.field == :url
  end

  test "web page tools reject IPv6 loopback and embedded private IPv4 forms" do
    assert {:error, %Jidoka.Error.ValidationError{} = mapped_error} =
             ReadPage.run(%{url: "http://[::ffff:127.0.0.1]"}, %{})

    assert mapped_error.field == :url

    assert {:error, %Jidoka.Error.ValidationError{} = unspecified_error} =
             SnapshotUrl.run(%{url: "http://[::]"}, %{})

    assert unspecified_error.field == :url
  end

  test "web capability names conflict with other tool-like capabilities" do
    assert_raise Spark.Error.DslError, ~r/duplicate tool names.*search_web/s, fn ->
      Code.compile_string("""
      defmodule JidokaTest.WebDuplicateToolAgent do
        use Jidoka.Agent

        agent do
          id :web_duplicate_tool_agent
        end

        defaults do
          instructions "This should fail."
        end

        capabilities do
          tool JidokaTest.DuplicateSearchWebTool
          web :search
        end
      end
      """)
    end
  end

  test "web capability rejects unsupported modes" do
    assert_raise Spark.Error.DslError, ~r/web capability mode must be :search or :read_only/s, fn ->
      Code.compile_string("""
      defmodule JidokaTest.WebBadModeAgent do
        use Jidoka.Agent

        agent do
          id :web_bad_mode_agent
        end

        defaults do
          instructions "This should fail."
        end

        capabilities do
          web :interactive
        end
      end
      """)
    end
  end

  test "web capability allows only one declaration" do
    assert_raise Spark.Error.DslError, ~r/at most one web capability/s, fn ->
      Code.compile_string("""
      defmodule JidokaTest.WebDuplicateDeclarationAgent do
        use Jidoka.Agent

        agent do
          id :web_duplicate_declaration_agent
        end

        defaults do
          instructions "This should fail."
        end

        capabilities do
          web :search
          web :read_only
        end
      end
      """)
    end
  end
end
