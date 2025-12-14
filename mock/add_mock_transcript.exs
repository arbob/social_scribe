# Add mock transcript data for testing
alias SocialScribe.{Repo, Meetings}
alias SocialScribe.Meetings.MeetingTranscript

# Mock transcript that mentions people with contact info
mock_transcript = [
  %{
    speaker: "Arbob Mehmood",
    speaker_id: 1,
    words: [
      %{text: "Hi Sarah, thanks for joining.", start_time: 0.0, end_time: 2.5}
    ],
    language: "en"
  },
  %{
    speaker: "Arbob Mehmood", 
    speaker_id: 1,
    words: [
      %{text: "I'm Arbob, the founder of TechStart Solutions.", start_time: 2.5, end_time: 5.0}
    ],
    language: "en"
  },
  %{
    speaker: "Sarah Chen",
    speaker_id: 2,
    words: [
      %{text: "Great to meet you! I'm Sarah Chen, Director of Business Development at Acme Corp.", start_time: 5.0, end_time: 9.0}
    ],
    language: "en"
  },
  %{
    speaker: "Sarah Chen",
    speaker_id: 2,
    words: [
      %{text: "My email is sarah.chen@acmecorp.com", start_time: 9.0, end_time: 11.5}
    ],
    language: "en"
  },
  %{
    speaker: "Arbob Mehmood",
    speaker_id: 1,
    words: [
      %{text: "We should loop in Mike Johnson, our CTO at mike@techstart.io", start_time: 11.5, end_time: 15.0}
    ],
    language: "en"
  },
  %{
    speaker: "Sarah Chen",
    speaker_id: 2,
    words: [
      %{text: "Let me include David Park, our Head of Engineering at david.park@acmecorp.com", start_time: 15.0, end_time: 19.0}
    ],
    language: "en"
  },
  %{
    speaker: "Arbob Mehmood",
    speaker_id: 1,
    words: [
      %{text: "So to summarize - we'll set up a technical demo next week and Sarah will prepare the partnership proposal.", start_time: 19.0, end_time: 25.0}
    ],
    language: "en"
  },
  %{
    speaker: "Sarah Chen",
    speaker_id: 2,
    words: [
      %{text: "Looking forward to working together! My direct line is 555-123-4567", start_time: 25.0, end_time: 28.0}
    ],
    language: "en"
  }
]

# Update the transcript for meeting ID 4
transcript = Repo.get_by!(MeetingTranscript, meeting_id: 4)

{:ok, updated} = Meetings.update_meeting_transcript(transcript, %{
  content: %{data: mock_transcript},
  language: "en"
})

IO.puts("Transcript updated successfully!")
IO.puts("Content preview:")
IO.inspect(updated.content, pretty: true)
