defmodule SocialScribe.HubSpotApi do
  @moduledoc """
  Behaviour for HubSpot API interactions.

  This follows the behaviour + implementation pattern used throughout the app
  for testability with Mox.
  """

  @type contact :: map()
  @type contact_id :: String.t()
  @type access_token :: String.t()
  @type search_query :: String.t()

  @doc """
  Search for contacts in HubSpot by email or name.
  """
  @callback search_contacts(access_token, search_query) ::
              {:ok, [contact]} | {:error, any()}

  @doc """
  Get a single contact by ID with all properties.
  """
  @callback get_contact(access_token, contact_id) ::
              {:ok, contact} | {:error, any()}

  @doc """
  Update a contact's properties in HubSpot.
  """
  @callback update_contact(access_token, contact_id, map()) ::
              {:ok, contact} | {:error, any()}

  @doc """
  Get all available contact properties from HubSpot.
  """
  @callback get_contact_properties(access_token) ::
              {:ok, [map()]} | {:error, any()}

  # Delegator functions

  def search_contacts(access_token, query) do
    impl().search_contacts(access_token, query)
  end

  def get_contact(access_token, contact_id) do
    impl().get_contact(access_token, contact_id)
  end

  def update_contact(access_token, contact_id, properties) do
    impl().update_contact(access_token, contact_id, properties)
  end

  def get_contact_properties(access_token) do
    impl().get_contact_properties(access_token)
  end

  defp impl do
    Application.get_env(:social_scribe, :hubspot_api, SocialScribe.HubSpot)
  end
end
