# Check v2 transcript endpoint
IO.puts("Fetching transcript with v2 API...")
case SocialScribe.RecallApi.get_bot_transcript("88df276f-2afe-47eb-8f26-b6e8dbcc2c38") do
  {:ok, response} ->
    IO.puts("Status code: #{response.status}")
    IO.inspect(response.body, pretty: true, limit: :infinity)
  {:error, error} ->
    IO.puts("Error: #{inspect(error)}")
end
