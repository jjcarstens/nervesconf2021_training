defmodule Setup.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Setup
    ]

    opts = [strategy: :one_for_one, name: Setup.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
