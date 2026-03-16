defmodule NotiOsw4lWeb.Presence do
  use Phoenix.Presence,
    otp_app: :noti_osw4l,
    pubsub_server: NotiOsw4l.PubSub
end
