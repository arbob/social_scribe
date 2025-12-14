defmodule SocialScribe.HubSpot do
  @moduledoc """
  HubSpot API implementation.

  Provides functions for interacting with HubSpot CRM contacts.
  Uses Tesla HTTP client for API requests.
  """

  @behaviour SocialScribe.HubSpotApi

  use Tesla

  plug Tesla.Middleware.BaseUrl, "https://api.hubapi.com"
  plug Tesla.Middleware.JSON

  @doc """
  Search for contacts in HubSpot by email or name.
  Returns a list of matching contacts with their properties.
  """
  @impl SocialScribe.HubSpotApi
  def search_contacts(access_token, query) when is_binary(query) and byte_size(query) > 0 do
    # Use wildcard search with * suffix for prefix matching
    # This allows searching for "ma" to find "Maria", "Mark", etc.
    wildcard_query = "#{query}*"

    body = %{
      "filterGroups" => [
        %{
          "filters" => [
            %{
              "propertyName" => "email",
              "operator" => "CONTAINS_TOKEN",
              "value" => wildcard_query
            }
          ]
        },
        %{
          "filters" => [
            %{
              "propertyName" => "firstname",
              "operator" => "CONTAINS_TOKEN",
              "value" => wildcard_query
            }
          ]
        },
        %{
          "filters" => [
            %{
              "propertyName" => "lastname",
              "operator" => "CONTAINS_TOKEN",
              "value" => wildcard_query
            }
          ]
        }
      ],
      "properties" => contact_properties(),
      "limit" => 20
    }

    case post("/crm/v3/objects/contacts/search", body, headers: auth_headers(access_token)) do
      {:ok, %Tesla.Env{status: 200, body: %{"results" => results}}} ->
        contacts = Enum.map(results, &format_contact/1)
        {:ok, contacts}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def search_contacts(_access_token, _query), do: {:ok, []}

  @doc """
  Get a single contact by ID with all standard properties.
  """
  @impl SocialScribe.HubSpotApi
  def get_contact(access_token, contact_id) do
    properties_param = Enum.join(contact_properties(), ",")
    url = "/crm/v3/objects/contacts/#{contact_id}?properties=#{properties_param}"

    case get(url, headers: auth_headers(access_token)) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, format_contact(body)}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update a contact's properties in HubSpot.
  """
  @impl SocialScribe.HubSpotApi
  def update_contact(access_token, contact_id, properties) when is_map(properties) do
    body = %{"properties" => properties}

    case patch("/crm/v3/objects/contacts/#{contact_id}", body, headers: auth_headers(access_token)) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        {:ok, format_contact(body)}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get all available contact properties from HubSpot.
  """
  @impl SocialScribe.HubSpotApi
  def get_contact_properties(access_token) do
    case get("/crm/v3/properties/contacts", headers: auth_headers(access_token)) do
      {:ok, %Tesla.Env{status: 200, body: %{"results" => results}}} ->
        properties =
          Enum.map(results, fn prop ->
            %{
              name: prop["name"],
              label: prop["label"],
              type: prop["type"],
              field_type: prop["fieldType"],
              group_name: prop["groupName"],
              description: prop["description"]
            }
          end)

        {:ok, properties}

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helpers

  defp auth_headers(access_token) do
    [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp contact_properties do
    [
      "email",
      "firstname",
      "lastname",
      "phone",
      "mobilephone",
      "company",
      "jobtitle",
      "address",
      "city",
      "state",
      "zip",
      "country",
      "website",
      "lifecyclestage",
      "hs_lead_status",
      "notes_last_updated",
      "hs_object_id"
    ]
  end

  defp format_contact(%{"id" => id, "properties" => properties}) do
    %{
      id: id,
      email: properties["email"],
      firstname: properties["firstname"],
      lastname: properties["lastname"],
      phone: properties["phone"],
      mobilephone: properties["mobilephone"],
      company: properties["company"],
      jobtitle: properties["jobtitle"],
      address: properties["address"],
      city: properties["city"],
      state: properties["state"],
      zip: properties["zip"],
      country: properties["country"],
      website: properties["website"],
      lifecyclestage: properties["lifecyclestage"],
      hs_lead_status: properties["hs_lead_status"]
    }
  end

  defp format_contact(body), do: body
end
