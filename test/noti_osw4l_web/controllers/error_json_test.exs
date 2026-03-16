defmodule NotiOsw4lWeb.ErrorJSONTest do
  use NotiOsw4lWeb.ConnCase, async: true

  test "renders 404" do
    assert NotiOsw4lWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert NotiOsw4lWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
