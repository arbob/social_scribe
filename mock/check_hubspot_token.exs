# Check HubSpot token status
alias SocialScribe.{Repo, Accounts.UserCredential}
import Ecto.Query

cred = Repo.one(from c in UserCredential, where: c.provider == "hubspot")

if cred do
  IO.puts("Token expires at: #{cred.expires_at}")
  IO.puts("Current time: #{DateTime.utc_now()}")
  IO.puts("Expired? #{DateTime.compare(cred.expires_at, DateTime.utc_now()) == :lt}")
else
  IO.puts("No HubSpot credential found!")
end
