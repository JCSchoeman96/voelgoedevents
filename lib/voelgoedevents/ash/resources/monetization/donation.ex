defmodule Voelgoedevents.Ash.Resources.Monetization.Donation do
  @moduledoc "Tracks voluntary donations collected during checkout (Phase 21)."
  use Voelgoedevents.Ash.Resources.Base, domain: Voelgoedevents.Ash.Domains.MonetizationDomain

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  postgres do
    table "donations"
    repo Voelgoedevents.Repo
  end
end
