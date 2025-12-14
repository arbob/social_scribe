# Update transcript with richer contact info including emails
alias SocialScribe.Repo
alias SocialScribe.Meetings.MeetingTranscript
import Ecto.Query

# Get the transcript for meeting 4
transcript = Repo.one(from t in MeetingTranscript, where: t.meeting_id == 4)

if transcript do
  new_content = %{
    "data" => [
      %{
        "words" => [%{"text" => "Hi everyone, thanks for joining today's product review meeting."}],
        "language" => "en-us",
        "speaker" => "Arbob Mehmood",
        "speaker_id" => 1
      },
      %{
        "words" => [%{"text" => "Thanks for having me. By the way, I've got a new email address - it's sarah.chen@newcompany.com"}],
        "language" => "en-us",
        "speaker" => "Sarah Chen",
        "speaker_id" => 2
      },
      %{
        "words" => [%{"text" => "Good to know Sarah! For anyone who needs to reach me, my work email is mike.johnson@techcorp.io and my cell phone is 555-123-4567."}],
        "language" => "en-us",
        "speaker" => "Mike Johnson",
        "speaker_id" => 3
      },
      %{
        "words" => [%{"text" => "I should mention I was recently promoted to Senior Product Manager at Acme Inc."}],
        "language" => "en-us",
        "speaker" => "David Park",
        "speaker_id" => 4
      },
      %{
        "words" => [%{"text" => "Congratulations David! Let's discuss the Q1 roadmap."}],
        "language" => "en-us",
        "speaker" => "Arbob Mehmood",
        "speaker_id" => 1
      },
      %{
        "words" => [%{"text" => "Sure. Also my direct line at the new office is 888-555-9999 if anyone needs it."}],
        "language" => "en-us",
        "speaker" => "David Park",
        "speaker_id" => 4
      },
      %{
        "words" => [%{"text" => "Perfect. Sarah, can you share more about the integration features?"}],
        "language" => "en-us",
        "speaker" => "Arbob Mehmood",
        "speaker_id" => 1
      },
      %{
        "words" => [%{"text" => "Absolutely. You can also reach me on my mobile at 415-555-7890 anytime."}],
        "language" => "en-us",
        "speaker" => "Sarah Chen",
        "speaker_id" => 2
      }
    ]
  }

  transcript
  |> MeetingTranscript.changeset(%{content: new_content})
  |> Repo.update!()
  |> IO.inspect(label: "Updated transcript")

  IO.puts("\nTranscript updated with emails and phone numbers!")
else
  IO.puts("No transcript found for meeting 4")
end
