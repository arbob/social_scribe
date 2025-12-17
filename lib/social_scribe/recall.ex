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
      # Enable transcription with meeting captions provider
      recording_config: %{
        transcript: %{
          provider: %{
            meeting_captions: %{}
          }
        }
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
    # First get bot info to extract transcript download URL
    case get_bot(recall_bot_id) do
      {:ok, %Tesla.Env{body: bot_info}} ->
        fetch_transcript_from_bot_info(bot_info)

      error ->
        error
    end
  end

  defp fetch_transcript_from_bot_info(bot_info) do
    # Extract transcript download URL from recordings -> media_shortcuts -> transcript
    with recording when not is_nil(recording) <- List.first(bot_info.recordings || []),
         transcript_url when is_binary(transcript_url) <-
           get_in(recording, [:media_shortcuts, :transcript, :data, :download_url]) do
      # Fetch the transcript JSON from the S3 URL
      case Tesla.get(transcript_client(), transcript_url) do
        {:ok, %Tesla.Env{status: 200, body: transcript_data}} when is_list(transcript_data) ->
          {:ok, %Tesla.Env{body: transcript_data}}

        {:ok, %Tesla.Env{status: 200, body: transcript_data}} when is_binary(transcript_data) ->
          # S3 may return as plain text, parse JSON manually
          case Jason.decode(transcript_data, keys: :atoms) do
            {:ok, parsed} -> {:ok, %Tesla.Env{body: parsed}}
            {:error, _} -> {:ok, %Tesla.Env{body: []}}
          end

        {:ok, %Tesla.Env{status: status, body: body}} ->
          {:error, {:transcript_download_failed, status, body}}

        error ->
          error
      end
    else
      nil -> {:ok, %Tesla.Env{body: []}}
      _ -> {:ok, %Tesla.Env{body: []}}
    end
  end

  # Simple client for downloading transcript from S3 (no auth headers needed)
  defp transcript_client do
    Tesla.client([
      {Tesla.Middleware.JSON, engine_opts: [keys: :atoms]}
    ])
  end
end
