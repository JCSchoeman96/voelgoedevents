defmodule Voelgoedevents.Ash.AccountsTest do
  @moduledoc "Basic tests for accounts domain."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.Organization
  alias Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings

  describe "placeholder" do
    test "true is true" do
      assert true
    end
  end

  describe "organization settings" do
    test "are created with typed attributes and updated via organization" do
      actor = %{role: :super_admin}

      {:ok, organization} =
        Ash.create(Organization, :create, %{
          name: "Acme Corp",
          slug: "acme-corp",
          settings: %{
            currency: :USD,
            timezone: "Africa/Johannesburg",
            primary_color: "#ff9900",
            logo_url: "https://example.com/logo.png"
          }
        }, actor: actor)

      loaded = Ash.load!(organization, :settings, actor: actor)

      assert loaded.settings.currency == :USD
      assert loaded.settings.timezone == "Africa/Johannesburg"
      assert loaded.settings.primary_color == "#ff9900"
      assert loaded.settings.logo_url == "https://example.com/logo.png"

      {:ok, updated} =
        Ash.update(organization, :update, %{settings: %{currency: :EUR, timezone: "UTC"}}, actor: actor)

      updated_loaded = Ash.load!(updated, :settings, actor: actor)

      assert updated_loaded.settings.currency == :EUR
      assert updated_loaded.settings.timezone == "UTC"
    end

    test "enforces one-to-one settings per organization" do
      actor = %{role: :super_admin}

      organization =
        Ash.create!(Organization, :create, %{name: "Solo Org", slug: "solo-org"}, actor: actor)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(OrganizationSettings, :create, %{organization_id: organization.id},
                 actor: %{organization_id: organization.id}
               )

      assert Enum.any?(errors, &(&1.field == :organization_id))
    end
  end
end
