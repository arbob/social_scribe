defmodule SocialScribeWeb.MeetingLive.HubspotUpdateComponent do
  @moduledoc """
  LiveComponent for reviewing and submitting HubSpot contact updates
  based on AI-generated suggestions from meeting transcripts.
  """

  use SocialScribeWeb, :live_component

  alias SocialScribe.Accounts
  alias SocialScribe.HubSpotApi

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-full max-w-2xl">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-semibold text-gray-900">
          Review Hubspot Updates
        </h2>
      </div>

      <%= if @hubspot_connected do %>
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Search HubSpot Contact
          </label>
          <form phx-change="search_contact" phx-target={@myself} phx-debounce="300">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search by name or email..."
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-orange-500 focus:border-orange-500"
              autocomplete="off"
            />
          </form>

          <%= if @searching do %>
            <div class="mt-2 text-sm text-gray-500">
              <span class="inline-block animate-spin mr-2">⟳</span>
              Searching...
            </div>
          <% end %>

          <%= if @search_results != [] and @selected_contact == nil do %>
            <ul class="mt-2 border border-gray-200 rounded-lg divide-y divide-gray-200 max-h-48 overflow-y-auto">
              <li
                :for={contact <- @search_results}
                phx-click="select_contact"
                phx-value-id={contact.id}
                phx-target={@myself}
                class="px-4 py-3 hover:bg-gray-50 cursor-pointer"
              >
                <div class="font-medium text-gray-900">
                  {contact.firstname} {contact.lastname}
                </div>
                <div class="text-sm text-gray-500">
                  {contact.email}
                </div>
              </li>
            </ul>
          <% end %>
        </div>

        <%= if @selected_contact do %>
          <div class="mb-4 p-3 bg-orange-50 rounded-lg flex items-center justify-between">
            <div>
              <span class="font-medium text-gray-900">
                {@selected_contact.firstname} {@selected_contact.lastname}
              </span>
              <span class="text-sm text-gray-500 ml-2">
                ({@selected_contact.email})
              </span>
            </div>
            <button
              type="button"
              phx-click="clear_contact"
              phx-target={@myself}
              class="text-gray-400 hover:text-gray-600"
            >
              <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <%= if @loading_suggestions do %>
            <div class="py-8 text-center text-gray-500">
              <div class="inline-block animate-spin text-2xl mb-2">⟳</div>
              <p>Analyzing transcript for contact updates...</p>
            </div>
          <% else %>
            <%= if @suggestions == [] do %>
              <div class="py-8 text-center text-gray-500">
                <p>No suggested updates found in the meeting transcript.</p>
              </div>
            <% else %>
              <form phx-submit="update_hubspot" phx-target={@myself}>
                <div class="space-y-3">
                  <div
                    :for={{suggestion, index} <- Enum.with_index(@suggestions)}
                    class="flex items-start gap-3 p-4 bg-gray-50 rounded-lg"
                  >
                    <input
                      type="checkbox"
                      name={"suggestions[#{index}][selected]"}
                      value="true"
                      checked={suggestion.selected}
                      phx-click="toggle_suggestion"
                      phx-value-index={index}
                      phx-target={@myself}
                      class="mt-1 h-4 w-4 rounded border-gray-300 text-orange-600 focus:ring-orange-500"
                    />
                    <input type="hidden" name={"suggestions[#{index}][field]"} value={suggestion.field} />
                    <input type="hidden" name={"suggestions[#{index}][suggested_value]"} value={suggestion.suggested_value} />

                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-2 mb-1">
                        <span class="font-medium text-gray-900">{suggestion.label}</span>
                      </div>
                      <div class="flex items-center gap-2 text-sm">
                        <span class="text-gray-500 truncate">
                          {suggestion.current_value || "(empty)"}
                        </span>
                        <svg class="h-4 w-4 text-gray-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                        </svg>
                        <span class="text-orange-600 font-medium truncate">
                          {suggestion.suggested_value}
                        </span>
                      </div>
                      <p class="text-xs text-gray-400 mt-1 italic">
                        {suggestion.reason}
                      </p>
                    </div>
                  </div>
                </div>

                <div class="mt-6 flex justify-end gap-3">
                  <button
                    type="button"
                    phx-click={JS.patch(@patch)}
                    class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={@updating or not Enum.any?(@suggestions, & &1.selected)}
                    class="px-4 py-2 text-sm font-medium text-white bg-orange-600 rounded-lg hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <%= if @updating do %>
                      <span class="inline-block animate-spin mr-2">⟳</span>
                      Updating...
                    <% else %>
                      Update Hubspot
                    <% end %>
                  </button>
                </div>
              </form>
            <% end %>
          <% end %>
        <% end %>
      <% else %>
        <div class="py-8 text-center">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
          </svg>
          <h3 class="mt-2 text-sm font-medium text-gray-900">HubSpot Not Connected</h3>
          <p class="mt-1 text-sm text-gray-500">
            Connect your HubSpot account in Settings to sync contact updates.
          </p>
          <div class="mt-6">
            <.link
              navigate={~p"/dashboard/settings"}
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-orange-600 hover:bg-orange-700"
            >
              Go to Settings
            </.link>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, [])
     |> assign(:selected_contact, nil)
     |> assign(:suggestions, [])
     |> assign(:loading_suggestions, false)
     |> assign(:searching, false)
     |> assign(:updating, false)
     |> assign(:hubspot_connected, false)
     |> assign(:hubspot_credential, nil)}
  end

  @impl true
  def update(assigns, socket) do
    # Handle partial updates (from send_update) vs full updates (initial render)
    socket = assign(socket, assigns)

    # Only fetch HubSpot credential if current_user is provided (initial render)
    # or if we don't have the credential info yet
    socket =
      if Map.has_key?(assigns, :current_user) do
        hubspot_credential = Accounts.get_user_credential(assigns.current_user, "hubspot")
        hubspot_connected = hubspot_credential != nil

        socket
        |> assign(:hubspot_connected, hubspot_connected)
        |> assign(:hubspot_credential, hubspot_credential)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("search_contact", %{"query" => query}, socket) do
    if String.length(query) >= 2 and socket.assigns.hubspot_credential do
      send(self(), {:search_hubspot_contacts, query, socket.assigns.myself})

      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:searching, true)}
    else
      {:noreply,
       socket
       |> assign(:search_query, query)
       |> assign(:search_results, [])
       |> assign(:searching, false)}
    end
  end

  @impl true
  def handle_event("select_contact", %{"id" => contact_id}, socket) do
    credential = socket.assigns.hubspot_credential

    case HubSpotApi.get_contact(credential.token, contact_id) do
      {:ok, contact} ->
        send(self(), {:generate_hubspot_suggestions, socket.assigns.meeting, contact, socket.assigns.myself})

        {:noreply,
         socket
         |> assign(:selected_contact, contact)
         |> assign(:search_results, [])
         |> assign(:loading_suggestions, true)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to load contact details")}
    end
  end

  @impl true
  def handle_event("clear_contact", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_contact, nil)
     |> assign(:suggestions, [])
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("toggle_suggestion", %{"index" => index}, socket) do
    index = String.to_integer(index)

    suggestions =
      socket.assigns.suggestions
      |> Enum.with_index()
      |> Enum.map(fn {suggestion, i} ->
        if i == index do
          Map.update!(suggestion, :selected, &(!&1))
        else
          suggestion
        end
      end)

    {:noreply, assign(socket, :suggestions, suggestions)}
  end

  @impl true
  def handle_event("update_hubspot", _params, socket) do
    credential = socket.assigns.hubspot_credential
    contact = socket.assigns.selected_contact

    selected_suggestions =
      socket.assigns.suggestions
      |> Enum.filter(& &1.selected)

    if Enum.empty?(selected_suggestions) do
      {:noreply, socket}
    else
      properties =
        selected_suggestions
        |> Enum.reduce(%{}, fn suggestion, acc ->
          Map.put(acc, suggestion.field, suggestion.suggested_value)
        end)

      {:noreply, assign(socket, :updating, true)}

      case HubSpotApi.update_contact(credential.token, contact.id, properties) do
        {:ok, _updated_contact} ->
          {:noreply,
           socket
           |> assign(:updating, false)
           |> put_flash(:info, "HubSpot contact updated successfully!")
           |> push_patch(to: socket.assigns.patch)}

        {:error, error} ->
          {:noreply,
           socket
           |> assign(:updating, false)
           |> put_flash(:error, "Failed to update HubSpot contact: #{inspect(error)}")}
      end
    end
  end

  # These handle_info callbacks need to be in the parent LiveView
  # We use send/2 to communicate with the parent
end
