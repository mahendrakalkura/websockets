defmodule WebSockets.Supervisor do
  @moduledoc false

  use Supervisor

  alias Supervisor.Spec, as: Spec
  alias WebSockets.Clients, as: Clients
  alias WebSockets.RabbitMQ, as: RabbitMQ
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Router, as: Router

  require Application

  def start_link() do
    Supervisor.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, _} = :cowboy.start_http(
      :http,
      100,
      [
        {:port, Application.get_env(:websockets, :port)}
      ],
      [
        {
          :env,
          [
            {
              :dispatch,
              :cowboy_router.compile(
                [
                  {
                    :_,
                    [
                      {"/", Router, []}
                    ]
                  }
                ]
              )
            }
          ]
        }
      ]
    )
    Spec.supervise(
      [
        Spec.worker(Clients, []),
        Spec.worker(RabbitMQ, []),
        Spec.worker(Repo, [])
      ],
      strategy: :one_for_one
    )
  end
end
