defmodule SocialScribe.AIContentGenerator do
  @moduledoc "Generates content using Google Gemini."

  @behaviour SocialScribe.AIContentGeneratorApi

  alias SocialScribe.Meetings
  alias SocialScribe.Automations

  @gemini_model "gemini-2.0-flash"
  @gemini_api_base_url "https://generativelanguage.googleapis.com/v1beta/models"

  @impl SocialScribe.AIContentGeneratorApi
  def generate_follow_up_email(meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        Based on the following meeting transcript, please draft a concise and professional follow-up email.
        The email should summarize the key discussion points and clearly list any action items assigned, including who is responsible if mentioned.
        Keep the tone friendly and action-oriented.

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_automation(automation, meeting) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = """
        #{Automations.generate_prompt_for_automation(automation)}

        #{meeting_prompt}
        """

        call_gemini(prompt)
    end
  end

  @impl SocialScribe.AIContentGeneratorApi
  def generate_hubspot_suggestions(meeting, contact) do
    case Meetings.generate_prompt_for_meeting(meeting) do
      {:error, reason} ->
        {:error, reason}

      {:ok, meeting_prompt} ->
        prompt = build_hubspot_suggestions_prompt(meeting_prompt, contact)

        case call_gemini(prompt) do
          {:ok, response} -> parse_hubspot_suggestions(response, contact)
          error -> error
        end
    end
  end

  defp build_hubspot_suggestions_prompt(meeting_prompt, contact) do
    current_values = """
    Current HubSpot Contact Data:
    - First Name: #{contact[:firstname] || "empty"}
    - Last Name: #{contact[:lastname] || "empty"}
    - Email: #{contact[:email] || "empty"}
    - Phone: #{contact[:phone] || "empty"}
    - Mobile Phone: #{contact[:mobilephone] || "empty"}
    - Company: #{contact[:company] || "empty"}
    - Job Title: #{contact[:jobtitle] || "empty"}
    - Address: #{contact[:address] || "empty"}
    - City: #{contact[:city] || "empty"}
    - State: #{contact[:state] || "empty"}
    - Zip: #{contact[:zip] || "empty"}
    - Country: #{contact[:country] || "empty"}
    - Website: #{contact[:website] || "empty"}
    """

    """
    You are analyzing a meeting transcript to extract contact information updates for a CRM.

    #{current_values}

    Based on the meeting transcript below, identify any NEW or UPDATED contact information mentioned.
    Only suggest updates where the person clearly states new information that differs from current values.

    Look for information like:
    - Phone numbers ("my number is...", "call me at...", "my cell is...")
    - Email addresses ("email me at...", "my email is...")
    - Job title changes ("I'm now the...", "my new role is...")
    - Company changes ("I moved to...", "I'm now at...")
    - Address changes ("we moved to...", "our new office is...")

    Meeting Transcript:
    #{meeting_prompt}

    Respond ONLY with a JSON array of suggested updates. Each update should have:
    - "field": the HubSpot field name (firstname, lastname, email, phone, mobilephone, company, jobtitle, address, city, state, zip, country, website)
    - "current_value": the current value in HubSpot (or null if empty)
    - "suggested_value": the new value from the transcript
    - "reason": brief explanation of why this update is suggested

    If no updates are found, respond with an empty array: []

    Example response format:
    [
      {"field": "phone", "current_value": null, "suggested_value": "888-555-0000", "reason": "Contact mentioned 'my phone number is 888-555-0000'"},
      {"field": "jobtitle", "current_value": "Sales Rep", "suggested_value": "Sales Manager", "reason": "Contact said 'I was recently promoted to Sales Manager'"}
    ]

    Respond with ONLY the JSON array, no other text.
    """
  end

  defp parse_hubspot_suggestions(response, contact) do
    # Clean up the response - remove markdown code blocks if present
    cleaned =
      response
      |> String.trim()
      |> String.replace(~r/^```json\s*/, "")
      |> String.replace(~r/^```\s*/, "")
      |> String.replace(~r/\s*```$/, "")
      |> String.trim()

    case Jason.decode(cleaned) do
      {:ok, suggestions} when is_list(suggestions) ->
        formatted =
          suggestions
          |> Enum.map(fn suggestion ->
            field = suggestion["field"]
            %{
              field: field,
              label: field_label(field),
              current_value: suggestion["current_value"] || Map.get(contact, String.to_existing_atom(field)),
              suggested_value: suggestion["suggested_value"],
              reason: suggestion["reason"],
              selected: true
            }
          end)
          |> Enum.filter(fn s -> s.suggested_value != nil and s.suggested_value != "" end)

        {:ok, formatted}

      {:ok, _} ->
        {:ok, []}

      {:error, _} ->
        # If JSON parsing fails, return empty suggestions
        {:ok, []}
    end
  end

  defp field_label(field) do
    %{
      "firstname" => "First Name",
      "lastname" => "Last Name",
      "email" => "Email",
      "phone" => "Phone",
      "mobilephone" => "Mobile Phone",
      "company" => "Company",
      "jobtitle" => "Job Title",
      "address" => "Address",
      "city" => "City",
      "state" => "State",
      "zip" => "Zip Code",
      "country" => "Country",
      "website" => "Website"
    }[field] || String.capitalize(field)
  end

  defp call_gemini(prompt_text) do
    api_key = Application.fetch_env!(:social_scribe, :gemini_api_key)
    url = "#{@gemini_api_base_url}/#{@gemini_model}:generateContent?key=#{api_key}"

    payload = %{
      contents: [
        %{
          parts: [%{text: prompt_text}]
        }
      ]
    }

    case Tesla.post(client(), url, payload) do
      {:ok, %Tesla.Env{status: 200, body: body}} ->
        # Safely extract the text content
        # The response structure is typically: body.candidates[0].content.parts[0].text

        text_path = [
          "candidates",
          Access.at(0),
          "content",
          "parts",
          Access.at(0),
          "text"
        ]

        case get_in(body, text_path) do
          nil -> {:error, {:parsing_error, "No text content found in Gemini response", body}}
          text_content -> {:ok, text_content}
        end

      {:ok, %Tesla.Env{status: status, body: error_body}} ->
        {:error, {:api_error, status, error_body}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, @gemini_api_base_url},
      Tesla.Middleware.JSON
    ])
  end
end
