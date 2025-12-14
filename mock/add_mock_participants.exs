# Add mock participants to the meeting
alias SocialScribe.Repo
alias SocialScribe.Meetings.MeetingParticipant

# Add participants matching our mock transcript
participants = [
  %{
    meeting_id: 4,
    name: "Arbob Mehmood",
    recall_participant_id: "participant-1",
    is_host: true,
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    meeting_id: 4,
    name: "Sarah Chen",
    recall_participant_id: "participant-2",
    is_host: false,
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    meeting_id: 4,
    name: "Mike Johnson",
    recall_participant_id: "participant-3",
    is_host: false,
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  },
  %{
    meeting_id: 4,
    name: "David Park",
    recall_participant_id: "participant-4",
    is_host: false,
    inserted_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now()
  }
]

Enum.each(participants, fn attrs ->
  %MeetingParticipant{}
  |> MeetingParticipant.changeset(attrs)
  |> Repo.insert!()
  |> IO.inspect(label: "Inserted")
end)

IO.puts("\nParticipants added successfully!")
