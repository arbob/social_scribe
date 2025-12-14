defmodule SocialScribeWeb.MeetingLive.Show do
  use SocialScribeWeb, :live_view

  import SocialScribeWeb.PlatformLogo
  import SocialScribeWeb.ClipboardButton

  alias SocialScribe.Meetings
  alias SocialScribe.Automations
  alias SocialScribe.Accounts
  alias SocialScribe.HubSpotApi
  alias SocialScribe.AIContentGeneratorApi
  alias SocialScribe.TokenRefresher

  @impl true
  def mount(%{"id" => meeting_id}, _session, socket) do
    meeting = Meetings.get_meeting_with_details(meeting_id)

    user_has_automations =
      Automations.list_active_user_automations(socket.assigns.current_user.id)
      |> length()
      |> Kernel.>(0)

    automation_results = Automations.list_automation_results_for_meeting(meeting_id)

    if meeting.calendar_event.user_id != socket.assigns.current_user.id do
      socket =
        socket
        |> put_flash(:error, "You do not have permission to view this meeting.")
        |> redirect(to: ~p"/dashboard/meetings")

      {:error, socket}
    else
      socket =
        socket
        |> assign(:page_title, "Meeting Details: #{meeting.title}")
        |> assign(:meeting, meeting)
        |> assign(:automation_results, automation_results)
        |> assign(:user_has_automations, user_has_automations)
        |> assign(
          :follow_up_email_form,
          to_form(%{
            "follow_up_email" => ""
          })
        )

      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"automation_result_id" => automation_result_id}, _uri, socket) do
    automation_result = Automations.get_automation_result!(automation_result_id)
    automation = Automations.get_automation!(automation_result.automation_id)

    socket =
      socket
      |> assign(:automation_result, automation_result)
      |> assign(:automation, automation)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate-follow-up-email", params, socket) do
    socket =
      socket
      |> assign(:follow_up_email_form, to_form(params))

    {:noreply, socket}
  end

  @impl true
  def handle_info({:search_hubspot_contacts, query, component_id}, socket) do
    credential = Accounts.get_user_credential(socket.assigns.current_user, "hubspot")

    if credential do
      # Check if token needs refresh (expired or will expire in the next minute)
      credential = maybe_refresh_hubspot_token(credential)

      case HubSpotApi.search_contacts(credential.token, query) do
        {:ok, results} ->
          send_update(component_id, search_results: results, searching: false)

        {:error, {401, _}} ->
          # Token might still be invalid, try one more refresh
          case refresh_hubspot_token(credential) do
            {:ok, refreshed_credential} ->
              case HubSpotApi.search_contacts(refreshed_credential.token, query) do
                {:ok, results} ->
                  send_update(component_id, search_results: results, searching: false)

                {:error, _} ->
                  send_update(component_id, search_results: [], searching: false)
              end

            {:error, _} ->
              send_update(component_id, search_results: [], searching: false)
          end

        {:error, _} ->
          send_update(component_id, search_results: [], searching: false)
      end
    else
      send_update(component_id, search_results: [], searching: false)
    end

    {:noreply, socket}
  end

  defp maybe_refresh_hubspot_token(credential) do
    # Check if token is expired or will expire soon (within 5 minutes)
    # Refresh 5 minutes before expiry to avoid race conditions
    five_minutes_from_now = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

    should_refresh =
      credential.expires_at &&
        DateTime.compare(credential.expires_at, five_minutes_from_now) == :lt

    if should_refresh do
      case refresh_hubspot_token(credential) do
        {:ok, refreshed_credential} -> refreshed_credential
        {:error, _} -> credential
      end
    else
      credential
    end
  end

  defp refresh_hubspot_token(credential) do
    case TokenRefresher.refresh_hubspot_token(credential.refresh_token) do
      {:ok, %{"access_token" => new_token, "expires_in" => expires_in}} ->
        expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second)

        case Accounts.update_user_credential(credential, %{
               token: new_token,
               expires_at: expires_at
             }) do
          {:ok, updated_credential} -> {:ok, updated_credential}
          error -> error
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def handle_info({:generate_hubspot_suggestions, meeting, contact, component_id}, socket) do
    require Logger
    Logger.info("Generating HubSpot suggestions for meeting #{meeting.id}, contact: #{inspect(contact.id)}")

    case AIContentGeneratorApi.generate_hubspot_suggestions(meeting, contact) do
      {:ok, suggestions} ->
        Logger.info("Generated #{length(suggestions)} suggestions")
        send_update(component_id, suggestions: suggestions, loading_suggestions: false)

      {:error, reason} ->
        Logger.error("Failed to generate HubSpot suggestions: #{inspect(reason)}")
        send_update(component_id, suggestions: [], loading_suggestions: false)
    end

    {:noreply, socket}
  end

  defp format_duration(nil), do: "N/A"

  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    cond do
      minutes > 0 && remaining_seconds > 0 -> "#{minutes} min #{remaining_seconds} sec"
      minutes > 0 -> "#{minutes} min"
      seconds > 0 -> "#{seconds} sec"
      true -> "Less than a second"
    end
  end

  attr :meeting_transcript, :map, required: true

  defp transcript_content(assigns) do
    has_transcript =
      assigns.meeting_transcript &&
        assigns.meeting_transcript.content &&
        Map.get(assigns.meeting_transcript.content, "data") &&
        Enum.any?(Map.get(assigns.meeting_transcript.content, "data"))

    assigns =
      assigns
      |> assign(:has_transcript, has_transcript)

    ~H"""
    <div class="bg-white shadow-xl rounded-lg p-6 md:p-8">
      <h2 class="text-2xl font-semibold mb-4 text-slate-700">
        Meeting Transcript
      </h2>
      <div class="prose prose-sm sm:prose max-w-none h-96 overflow-y-auto pr-2">
        <%= if @has_transcript do %>
          <div :for={segment <- @meeting_transcript.content["data"]} class="mb-3">
            <p>
              <span class="font-semibold text-indigo-600">
                {segment["speaker"] || "Unknown Speaker"}:
              </span>
              {Enum.map_join(segment["words"] || [], " ", & &1["text"])}
            </p>
          </div>
        <% else %>
          <p class="text-slate-500">
            Transcript not available for this meeting.
          </p>
        <% end %>
      </div>
    </div>
    """
  end
end
