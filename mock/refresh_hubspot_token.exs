# Manually refresh HubSpot token
alias SocialScribe.{Repo, Accounts, Accounts.UserCredential, TokenRefresher}
import Ecto.Query

cred = Repo.one(from c in UserCredential, where: c.provider == "hubspot")

if cred do
  IO.puts("Current token expires at: #{cred.expires_at}")
  IO.puts("Refreshing token...")
  
  case TokenRefresher.refresh_hubspot_token(cred.refresh_token) do
    {:ok, response} ->
      IO.puts("Token refreshed successfully!")
      IO.inspect(response, label: "Response")
      
      # Update the credential in the database
      new_expires_at = DateTime.add(DateTime.utc_now(), response["expires_in"], :second)
      {:ok, updated} = Accounts.update_user_credential(cred, %{
        token: response["access_token"],
        refresh_token: response["refresh_token"],
        expires_at: new_expires_at
      })
      IO.puts("New token expires at: #{updated.expires_at}")
    {:error, reason} ->
      IO.puts("Failed to refresh token: #{inspect(reason)}")
  end
else
  IO.puts("No HubSpot credential found!")
end
