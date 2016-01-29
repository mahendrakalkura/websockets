defmodule WebSocketsTest do
  @moduledoc ""

  alias ExUnit.DocTest, as: DocTest

  require WebSockets

  use ExUnit.Case, async: true

  DocTest.doctest(WebSockets)
end
