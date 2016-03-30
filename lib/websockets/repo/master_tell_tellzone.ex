defmodule WebSockets.Repo.MasterTellTellzone do
  @moduledoc false

  use Ecto.Schema

  schema "api_master_tells_tellzones" do
    belongs_to :master_tell, WebSockets.Repo.MasterTell
    belongs_to :tellzone, WebSockets.Repo.Tellzone
  end
end
