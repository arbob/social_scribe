# Check meeting state
alias SocialScribe.Repo
alias SocialScribe.Meetings
alias SocialScribe.Meetings.Meeting

meeting = Meetings.get_meeting_with_details(4)

IO.puts("Meeting ID: #{meeting.id}")
IO.puts("Title: #{meeting.title}")
IO.puts("Participants count: #{length(meeting.meeting_participants)}")
IO.puts("Has transcript: #{meeting.meeting_transcript != nil}")

if meeting.meeting_transcript do
  data = meeting.meeting_transcript.content["data"]
  IO.puts("Transcript segments: #{length(data || [])}")
end

IO.puts("\nParticipants:")
Enum.each(meeting.meeting_participants, fn p ->
  IO.puts("  - #{p.name} (host: #{p.is_host})")
end)

IO.puts("\nTrying to generate prompt...")
case Meetings.generate_prompt_for_meeting(meeting) do
  {:ok, prompt} ->
    IO.puts("SUCCESS - Prompt generated")
    IO.puts(String.slice(prompt, 0, 500))
  {:error, reason} ->
    IO.puts("ERROR: #{inspect(reason)}")
end
