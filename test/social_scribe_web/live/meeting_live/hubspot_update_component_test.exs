defmodule SocialScribeWeb.MeetingLive.HubSpotUpdateComponentTest do
  use SocialScribeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SocialScribe.AccountsFixtures
  import SocialScribe.MeetingsFixtures
  import SocialScribe.CalendarFixtures
  import SocialScribe.BotsFixtures
  import Mox

  setup :verify_on_exit!

  describe "HubSpot Update Component" do
    setup :register_and_log_in_user

    setup %{user: user} do
      # Create HubSpot credential for the user
      hubspot_credential = user_credential_fixture(%{
        user_id: user.id,
        provider: "hubspot",
        uid: "hub-123456",
        token: "test_hubspot_token",
        email: "hubspot_user@example.com"
      })

      # Create Google credential (required for calendar events)
      google_credential = user_credential_fixture(%{
        user_id: user.id,
        provider: "google",
        uid: "google-123456",
        token: "test_google_token",
        email: "test@example.com"
      })

      # Create a calendar event for the user
      calendar_event = calendar_event_fixture(%{
        user_id: user.id,
        user_credential_id: google_credential.id,
        title: "Test Meeting with John"
      })

      # Create recall bot for the meeting
      recall_bot = recall_bot_fixture(%{
        user_id: user.id,
        calendar_event_id: calendar_event.id
      })

      # Create a meeting with transcript
      meeting = meeting_fixture(%{
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot.id,
        title: "Test Meeting"
      })

      # Add transcript to meeting
      _transcript = meeting_transcript_fixture(%{
        meeting_id: meeting.id,
        content: %{
          "text" => "John: Hi, I'm John Smith, VP of Sales at TechCorp. My email is john@techcorp.com"
        }
      })

      %{
        hubspot_credential: hubspot_credential,
        meeting: meeting,
        calendar_event: calendar_event
      }
    end

    test "renders HubSpot update button on meeting show page", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}")

      assert has_element?(view, "a", "Update HubSpot")
    end

    test "opens HubSpot modal when navigating to hubspot_update route", %{
      conn: conn,
      meeting: meeting
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot_update")

      # Should show the modal with the title and search input
      assert has_element?(view, "h2", "Review Hubspot Updates")
      assert has_element?(view, "input[placeholder=\"Search by name or email...\"]")
    end

    test "shows no HubSpot connection message when user has no HubSpot credential", %{
      conn: conn
    } do
      # Create a new user without HubSpot credential
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Create required data for meeting
      google_credential = user_credential_fixture(%{
        user_id: user.id,
        provider: "google",
        uid: "google-no-hubspot",
        token: "test_google_token",
        email: "nohubspot@example.com"
      })

      calendar_event = calendar_event_fixture(%{
        user_id: user.id,
        user_credential_id: google_credential.id,
        title: "Meeting without HubSpot"
      })

      recall_bot = recall_bot_fixture(%{
        user_id: user.id,
        calendar_event_id: calendar_event.id
      })

      meeting = meeting_fixture(%{
        calendar_event_id: calendar_event.id,
        recall_bot_id: recall_bot.id,
        title: "Test Meeting No HubSpot"
      })

      {:ok, view, _html} = live(conn, ~p"/dashboard/meetings/#{meeting.id}/hubspot_update")

      # Should show message about connecting HubSpot
      assert has_element?(view, "p", "Connect your HubSpot account")
    end
  end
end
