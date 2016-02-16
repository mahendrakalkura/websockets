defmodule WebSockets.Repo.Category do
  @moduledoc false

  use Ecto.Schema

  schema "api_categories" do
    field :name, :string
  end
end
