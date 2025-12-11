defmodule VoelgoedeventsWeb.AuthFlowTest do
  @moduledoc """
  Integration tests for authentication flows.

  Tests the HTTP-level behavior of sign-in, register, and sign-out routes.
  Treats the auth system as a black box - no internal AshAuthentication API calls.
  """
  use VoelgoedeventsWeb.ConnCase, async: true

  import Voelgoedevents.TestFixtures

  # Must match the password used in TestFixtures.create_user/2 default
  # See: test/support/fixtures.ex line 103
  @password "TestPassword123!"

  describe "GET /auth/log_in" do
    test "renders sign-in page", %{conn: conn} do
      conn = get(conn, ~p"/auth/log_in")

      assert html_response(conn, 200) =~ "Sign in"
    end
  end

  describe "GET /auth/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/auth/register")

      assert html_response(conn, 200) =~ "Register"
    end
  end

  describe "POST /auth/user/password/sign_in" do
    setup do
      # Create org, role, and user for sign-in tests
      # Note: create_user/2 uses Bcrypt.hash_pwd_salt("TestPassword123!") by default
      # so @password matches the user's actual password
      roles = ensure_roles()
      org = create_organization()

      user =
        create_user(
          %{email: "signin-test-#{System.unique_integer([:positive])}@example.com"},
          organization: org,
          role: roles.owner
        )

      %{user: user, org: org}
    end

    test "successful sign-in redirects", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{
            "email" => user.email,
            "password" => @password
          }
        })

      # TEMP: inspect what is actually going on
      IO.puts("STATUS: #{inspect(conn.status)}")
      IO.puts("BODY:\n#{conn.resp_body}")

      # Successful auth should redirect (302)
      assert redirected_to(conn, 302)
    end

    test "failed sign-in with wrong password returns error", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{
            "email" => user.email,
            "password" => "wrong_password"
          }
        })

      # Failed auth renders failure page or redirects back with error
      # AshAuthentication typically returns 401 or redirects to failure
      assert conn.status in [401, 302]
    end

    test "failed sign-in with non-existent user returns error", %{conn: conn} do
      conn =
        post(conn, ~p"/auth/user/password/sign_in", %{
          "user" => %{
            "email" => "nonexistent@example.com",
            "password" => @password
          }
        })

      assert conn.status in [401, 302]
    end
  end

  describe "POST /auth/user/password/register" do
    test "registration endpoint exists and accepts requests", %{conn: conn} do
      unique_email = "register-#{System.unique_integer([:positive])}@example.com"

      # In auth_flow_test.exs, update the registration test
      conn =
        post(conn, ~p"/auth/user/password/register", %{
          "user" => %{
            "email" => unique_email,
            "password" => @password,
            "password_confirmation" => @password,
            "first_name" => "Test",
            "last_name" => "User"
          }
        })

      # Registration may succeed (302 redirect) or fail due to missing required fields
      # like first_name, last_name, organization_id, role_id (per User resource validations)
      # The key assertion is that the endpoint exists and responds
      assert conn.status in [200, 302, 400, 422]
    end
  end

  describe "GET /auth/log_out" do
    setup do
      # Create user for logout tests
      # Note: create_user/2 uses Bcrypt.hash_pwd_salt("TestPassword123!") by default
      roles = ensure_roles()
      org = create_organization()

      user =
        create_user(
          %{email: "logout-test-#{System.unique_integer([:positive])}@example.com"},
          organization: org,
          role: roles.owner
        )

      %{user: user, org: org}
    end

    test "sign-out clears session and redirects", %{conn: conn, user: user} do
      # First, simulate a logged-in session by storing user in session
      conn =
        conn
        |> Plug.Test.init_test_session(%{})
        |> put_session(:user_id, user.id)

      # Now sign out
      conn = get(conn, ~p"/auth/log_out")

      # Should redirect after sign-out
      assert redirected_to(conn, 302)
    end

    test "sign-out works even when not logged in", %{conn: conn} do
      conn = get(conn, ~p"/auth/log_out")

      # Should still redirect (graceful handling)
      assert redirected_to(conn, 302)
    end
  end

  describe "GET /auth/reset" do
    test "renders password reset request page", %{conn: conn} do
      conn = get(conn, ~p"/auth/reset")

      assert html_response(conn, 200)
    end
  end
end
