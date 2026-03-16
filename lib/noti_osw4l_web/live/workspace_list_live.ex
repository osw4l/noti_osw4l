defmodule NotiOsw4lWeb.WorkspaceListLive do
  use NotiOsw4lWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Mis Espacios")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8">
      <h1 class="text-2xl font-bold">Mis Espacios de Trabajo</h1>
      <p class="text-zinc-500 mt-2">Próximamente...</p>
    </div>
    """
  end
end
