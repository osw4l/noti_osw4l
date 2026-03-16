defmodule NotiOsw4lWeb.Router do
  use NotiOsw4lWeb, :router

  import NotiOsw4lWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NotiOsw4lWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", NotiOsw4lWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [{NotiOsw4lWeb.UserAuth, :ensure_authenticated}] do
      live "/workspaces", WorkspaceListLive
      live "/workspaces/:id", WorkspaceShowLive
    end
  end

  scope "/", NotiOsw4lWeb do
    pipe_through [:browser]

    live_session :public,
      on_mount: [{NotiOsw4lWeb.UserAuth, :redirect_if_authenticated}] do
      live "/login", LoginLive
      live "/register", RegisterLive
    end

    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
    get "/", PageController, :home
  end

  if Application.compile_env(:noti_osw4l, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NotiOsw4lWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
