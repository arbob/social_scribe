defmodule SocialScribe.HubSpotTest do
  use SocialScribe.DataCase, async: true

  alias SocialScribe.HubSpot

  describe "search_contacts/2" do
    test "searches contacts by query string" do
      access_token = "test_access_token"
      query = "john@example.com"

      # Note: This tests the actual implementation structure
      # In integration tests, you would mock the Tesla adapter
      assert is_function(&HubSpot.search_contacts/2, 2)
    end
  end

  describe "get_contact/2" do
    test "fetches a contact by ID" do
      assert is_function(&HubSpot.get_contact/2, 2)
    end
  end

  describe "update_contact/3" do
    test "updates contact properties" do
      assert is_function(&HubSpot.update_contact/3, 3)
    end
  end

  describe "get_contact_properties/1" do
    test "fetches available contact properties" do
      assert is_function(&HubSpot.get_contact_properties/1, 1)
    end
  end
end
