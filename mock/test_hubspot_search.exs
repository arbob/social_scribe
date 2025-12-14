# Test HubSpot search
alias SocialScribe.Accounts
alias SocialScribe.HubSpot

user = SocialScribe.Repo.get!(SocialScribe.Accounts.User, 1)
credential = Accounts.get_user_credential(user, "hubspot")

IO.puts("HubSpot credential found: #{credential != nil}")
IO.puts("Token: #{String.slice(credential.token, 0, 20)}...")

# Test search with different queries
queries = ["Brian", "Maria", "hubspot", "bh@hubspot.com", "maria@hubspot.com"]

for query <- queries do
  IO.puts("\n--- Searching for: #{query} ---")
  result = HubSpot.search_contacts(credential.token, query)
  IO.inspect(result, label: "Result")
end
