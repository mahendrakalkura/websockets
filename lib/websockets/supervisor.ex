defmodule WebSockets.Supervisor do
  @moduledoc """
  """

  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [])
  end

  def init([]) do
    {:ok, _} = :cowboy.start_http(
      :http,
      100,
      [
        {:port, Application.get_env(:websockets, :port)},
      ],
      [
        {
          :env,
          [
            {
              :dispatch,
              :cowboy_router.compile([{:_, [{"/", WebSockets.Router, []}]}]),
            },
          ],
        },
      ]
    )
    supervise(
      [
        worker(WebSockets.Clients, [[], []]),
        worker(WebSockets.Repo, []),
      ],
      strategy: :one_for_one,
    )
  end
end
