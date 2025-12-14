# Manually process the completed bot
alias SocialScribe.{Bots, Meetings, RecallApi}

bot = Bots.list_recall_bots() |> List.first()
IO.puts("Bot ID: #{bot.id}, Status: #{bot.status}")

# Get bot info from Recall.ai
{:ok, %{body: bot_api_info}} = RecallApi.get_bot(bot.recall_bot_id)
IO.puts("Bot API status: #{List.last(bot_api_info.status_changes).code}")

# Get transcript (will be an error, but we'll handle it)
transcript_result = RecallApi.get_bot_transcript(bot.recall_bot_id)
IO.puts("Transcript result: #{inspect(elem(transcript_result, 0))}")

transcript_data = 
  case transcript_result do
    {:ok, %{body: data}} when is_list(data) -> data
    _ -> []
  end

IO.puts("Using empty transcript list: #{inspect(transcript_data)}")

# Create meeting
case Meetings.create_meeting_from_recall_data(bot, bot_api_info, transcript_data) do
  {:ok, meeting} ->
    IO.puts("SUCCESS! Meeting created with ID: #{meeting.id}")
    IO.inspect(meeting, pretty: true)
  {:error, reason} ->
    IO.puts("ERROR: #{inspect(reason)}")
end
