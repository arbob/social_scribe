defmodule Ueberauth.Strategy.HubSpot do
  @moduledoc """
  HubSpot OAuth2 Strategy for Ueberauth.

  Implements OAuth2 authentication flow for HubSpot CRM integration.
  """

  use Ueberauth.Strategy,
    uid_field: :hub_id,
    default_scope: "crm.objects.contacts.read crm.objects.contacts.write oauth",
    oauth2_module: Ueberauth.Strategy.HubSpot.OAuth

  alias Ueberauth.Auth.Info
  alias Ueberauth.Auth.Credentials
  alias Ueberauth.Auth.Extra

  @doc """
  Handles initial request for HubSpot authentication.
  """
  def handle_request!(conn) do
    scopes = conn.params["scope"] || option(conn, :default_scope)

    opts =
      [scope: scopes]
      |> with_optional(:prompt, conn)
      |> with_param(:prompt, conn)
      |> with_state_param(conn)

    module = option(conn, :oauth2_module)
    redirect!(conn, apply(module, :authorize_url!, [opts]))
  end

  @doc """
  Handles the callback from HubSpot.
  """
  def handle_callback!(%Plug.Conn{params: %{"code" => code}} = conn) do
    module = option(conn, :oauth2_module)

    token =
      apply(module, :get_token!, [[code: code, redirect_uri: callback_url(conn)]])

    if token.access_token == nil do
      set_errors!(conn, [
        error(token.other_params["error"], token.other_params["error_description"])
      ])
    else
      fetch_user(conn, token)
    end
  end

  def handle_callback!(conn) do
    set_errors!(conn, [error("missing_code", "No code received")])
  end

  @doc """
  Cleans up the private area of the connection.
  """
  def handle_cleanup!(conn) do
    conn
    |> put_private(:hubspot_user, nil)
    |> put_private(:hubspot_token, nil)
  end

  @doc """
  Returns the HubSpot hub_id as the uid.
  """
  def uid(conn) do
    conn.private.hubspot_user["hub_id"] |> to_string()
  end

  @doc """
  Returns the credentials from the HubSpot response.
  """
  def credentials(conn) do
    token = conn.private.hubspot_token

    %Credentials{
      token: token.access_token,
      refresh_token: token.refresh_token,
      expires_at: token.expires_at,
      token_type: token.token_type,
      expires: !!token.expires_at,
      scopes: String.split(token.other_params["scope"] || "", " ")
    }
  end

  @doc """
  Returns user info from HubSpot.
  """
  def info(conn) do
    user = conn.private.hubspot_user

    %Info{
      email: user["user"],
      name: user["user"]
    }
  end

  @doc """
  Returns extra information from HubSpot.
  """
  def extra(conn) do
    %Extra{
      raw_info: %{
        token: conn.private.hubspot_token,
        user: conn.private.hubspot_user
      }
    }
  end

  defp fetch_user(conn, token) do
    conn = put_private(conn, :hubspot_token, token)

    # Fetch access token info from HubSpot
    case Ueberauth.Strategy.HubSpot.OAuth.get(token, "/oauth/v1/access-tokens/#{token.access_token}") do
      {:ok, %OAuth2.Response{status_code: 200, body: user}} ->
        put_private(conn, :hubspot_user, user)

      {:ok, %OAuth2.Response{status_code: status_code, body: body}} ->
        set_errors!(conn, [error("OAuth2", "#{status_code}: #{inspect(body)}")])

      {:error, %OAuth2.Error{reason: reason}} ->
        set_errors!(conn, [error("OAuth2", reason)])
    end
  end

  defp with_param(opts, key, conn) do
    if value = conn.params[to_string(key)], do: Keyword.put(opts, key, value), else: opts
  end

  defp with_optional(opts, key, conn) do
    if option(conn, key), do: Keyword.put(opts, key, option(conn, key)), else: opts
  end

  defp option(conn, key) do
    Keyword.get(options(conn), key, Keyword.get(default_options(), key))
  end
end
