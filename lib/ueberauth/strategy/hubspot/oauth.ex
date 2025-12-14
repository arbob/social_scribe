defmodule Ueberauth.Strategy.HubSpot.OAuth do
  @moduledoc """
  OAuth2 client for HubSpot.

  Configuration is loaded from runtime environment variables:
  - HUBSPOT_CLIENT_ID
  - HUBSPOT_CLIENT_SECRET
  - HUBSPOT_REDIRECT_URI
  """

  use OAuth2.Strategy

  @defaults [
    strategy: __MODULE__,
    site: "https://api.hubapi.com",
    authorize_url: "https://app.hubspot.com/oauth/authorize",
    token_url: "https://api.hubapi.com/oauth/v1/token"
  ]

  @doc """
  Constructs a client for requests to HubSpot.
  """
  def client(opts \\ []) do
    config =
      :ueberauth
      |> Application.fetch_env!(Ueberauth.Strategy.HubSpot.OAuth)
      |> check_credential(:client_id)
      |> check_credential(:client_secret)

    client_opts =
      @defaults
      |> Keyword.merge(config)
      |> Keyword.merge(opts)

    json_library = Ueberauth.json_library()

    OAuth2.Client.new(client_opts)
    |> OAuth2.Client.put_serializer("application/json", json_library)
  end

  @doc """
  Provides the authorize URL for the request phase.
  """
  def authorize_url!(params \\ [], opts \\ []) do
    opts
    |> client()
    |> OAuth2.Client.authorize_url!(params)
  end

  @doc """
  Fetches an OAuth2 token.
  """
  def get_token!(params \\ [], opts \\ []) do
    client =
      opts
      |> client()
      |> OAuth2.Client.get_token!(params)

    client.token
  end

  @doc """
  Makes an authenticated GET request to the HubSpot API.
  """
  def get(token, url, headers \\ [], opts \\ []) do
    [token: token]
    |> client()
    |> put_param(:client_secret, client().client_secret)
    |> OAuth2.Client.get(url, headers, opts)
  end

  # OAuth2.Strategy callbacks

  @impl OAuth2.Strategy
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl OAuth2.Strategy
  def get_token(client, params, headers) do
    client
    |> put_param(:client_id, client.client_id)
    |> put_param(:client_secret, client.client_secret)
    |> put_param(:grant_type, "authorization_code")
    |> put_header("Accept", "application/json")
    |> OAuth2.Strategy.AuthCode.get_token(params, headers)
  end

  defp check_credential(config, key) do
    check_config_key_exists(config, key)

    case Keyword.get(config, key) do
      value when is_binary(value) ->
        config

      {:system, env_key} ->
        case System.get_env(env_key) do
          nil ->
            raise "#{inspect(env_key)} missing from environment, expected in config :ueberauth, Ueberauth.Strategy.HubSpot.OAuth"

          value ->
            Keyword.put(config, key, value)
        end
    end
  end

  defp check_config_key_exists(config, key) when is_list(config) do
    unless Keyword.has_key?(config, key) do
      raise "#{inspect(key)} missing from config :ueberauth, Ueberauth.Strategy.HubSpot.OAuth"
    end

    config
  end

  defp check_config_key_exists(_, _) do
    raise "Config :ueberauth, Ueberauth.Strategy.HubSpot.OAuth is not a keyword list, as expected"
  end
end
