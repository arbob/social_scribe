defmodule SocialScribe.AIContentGeneratorHubSpotTest do
  use SocialScribe.DataCase, async: true

  import Mox

  alias SocialScribe.AIContentGeneratorApi

  setup :verify_on_exit!

  describe "generate_hubspot_suggestions/2" do
    test "generates contact update suggestions from transcript" do
      transcript = """
      John: Hi, I'm John Smith from Acme Corp. My new email is john.smith@acme.com
      Jane: Great to meet you John. What's your role there?
      John: I'm the VP of Sales now, got promoted last month.
      """

      contact = %{
        "properties" => %{
          "email" => "john@oldcompany.com",
          "firstname" => "John",
          "lastname" => "Smith",
          "company" => "",
          "jobtitle" => "Sales Manager"
        }
      }

      expected_suggestions = [
        %{
          "field" => "email",
          "current_value" => "john@oldcompany.com",
          "suggested_value" => "john.smith@acme.com",
          "reason" => "John mentioned his new email during the meeting"
        },
        %{
          "field" => "company",
          "current_value" => "",
          "suggested_value" => "Acme Corp",
          "reason" => "John introduced himself as being from Acme Corp"
        },
        %{
          "field" => "jobtitle",
          "current_value" => "Sales Manager",
          "suggested_value" => "VP of Sales",
          "reason" => "John mentioned he was promoted to VP of Sales"
        }
      ]

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn ^transcript, ^contact ->
        {:ok, expected_suggestions}
      end)

      assert {:ok, suggestions} = AIContentGeneratorApi.generate_hubspot_suggestions(transcript, contact)
      assert length(suggestions) == 3
      assert Enum.any?(suggestions, fn s -> s["field"] == "email" end)
      assert Enum.any?(suggestions, fn s -> s["field"] == "company" end)
      assert Enum.any?(suggestions, fn s -> s["field"] == "jobtitle" end)
    end

    test "returns empty list when no updates found" do
      transcript = "Just a general conversation with no contact info."
      contact = %{"properties" => %{"email" => "test@example.com"}}

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn ^transcript, ^contact ->
        {:ok, []}
      end)

      assert {:ok, []} = AIContentGeneratorApi.generate_hubspot_suggestions(transcript, contact)
    end

    test "handles API errors gracefully" do
      transcript = "Some transcript"
      contact = %{"properties" => %{}}

      SocialScribe.AIContentGeneratorMock
      |> expect(:generate_hubspot_suggestions, fn ^transcript, ^contact ->
        {:error, "API rate limit exceeded"}
      end)

      assert {:error, _reason} = AIContentGeneratorApi.generate_hubspot_suggestions(transcript, contact)
    end
  end
end
