defmodule SocialScribe.Recall do
  @moduledoc "The real implementation for the Recall.ai API client."
  @behaviour SocialScribe.RecallApi

  defp client do
    api_key = Application.fetch_env!(:social_scribe, :recall_api_key)
    recall_region = Application.fetch_env!(:social_scribe, :recall_region)

    Tesla.client([
      {Tesla.Middleware.BaseUrl, "https://#{recall_region}.recall.ai/api"},
      {Tesla.Middleware.JSON, engine_opts: [keys: :atoms]},
      {Tesla.Middleware.Headers,
       [
         {"Authorization", "Token #{api_key}"},
         {"Content-Type", "application/json"},
         {"Accept", "application/json"}
       ]}
    ])
  end

  @impl SocialScribe.RecallApi
  def create_bot(meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      join_at: Timex.format!(join_at, "{ISO:Extended}"),
      # Enable transcription
      recording_config: %{
        transcript: %{}
      }
    }

    Tesla.post(client(), "/v1/bot", body)
  end

  @impl SocialScribe.RecallApi
  def update_bot(recall_bot_id, meeting_url, join_at) do
    body = %{
      meeting_url: meeting_url,
      join_at: Timex.format!(join_at, "{ISO:Extended}")
    }

    Tesla.patch(client(), "/v1/bot/#{recall_bot_id}", body)
  end

  @impl SocialScribe.RecallApi
  def delete_bot(recall_bot_id) do
    Tesla.delete(client(), "/v1/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot(recall_bot_id) do
    Tesla.get(client(), "/v1/bot/#{recall_bot_id}")
  end

  @impl SocialScribe.RecallApi
  def get_bot_transcript(recall_bot_id) do
    # Use the v2 transcript endpoint
    Tesla.get(client(), "/v2/bot/#{recall_bot_id}/transcript")
  end
end
