defmodule Voelgoedevents.Ash.Resources.Ticketing.Ticket do
  @moduledoc "Ash resource: Ticket with state machine."

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.TicketingDomain,
    extensions: [AshStateMachine]

  postgres do
    table("tickets")
    repo(Voelgoedevents.Repo)
  end

  state_machine do
    state_attribute :status

    initial_states [:active]
    default_initial_state :active

    # State Descriptions (moved to comments as DSL doesn't support them):
    # :active   -> "Issued ticket that has not been scanned."
    # :scanned  -> "Ticket scanned for entry; re-entry may be allowed."
    # :used     -> "Ticket fully consumed for the event."
    # :voided   -> "Ticket invalidated (fraud/ops action)."
    # :refunded -> "Ticket refunded after purchase."

    transitions do
      transition(:scan, from: [:active, :scanned], to: :scanned)
      transition(:mark_used, from: [:active, :scanned], to: :used)
      transition(:void, from: [:active, :scanned], to: :voided)
      transition(:refund, from: [:active, :scanned, :voided], to: :refunded)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
      description "Tenant that owns the ticket."
    end

    attribute :event_id, :uuid do
      allow_nil? false
      description "Event this ticket grants access to."
    end

    attribute :seat_id, :uuid do
      allow_nil? false
      description "Seat linked to this ticket (GA seats use a synthetic seat record)."
    end

    attribute :checkout_id, :uuid do
      allow_nil? false
      description "Checkout session that created the ticket."
    end

    attribute :user_id, :uuid do
      allow_nil? true
      description "Purchasing user, if known."
    end

    attribute :ticket_code, :string do
      allow_nil? false
      description "Unique code encoded into the QR/barcode."
    end

    attribute :status, :atom do
      allow_nil? false
      constraints one_of: [:active, :scanned, :used, :voided, :refunded]
      default :active
      description "Ticket lifecycle state."
    end

    attribute :scanned_at, :utc_datetime_usec do
      description "Timestamp of the latest scan."
    end

    attribute :last_gate_id, :uuid do
      description "Most recent gate that scanned this ticket."
    end

    attribute :scan_count, :integer do
      allow_nil? false
      default 0
      description "Total number of scans recorded for this ticket."
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :event, Voelgoedevents.Ash.Resources.Events.Event do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :seat, Voelgoedevents.Ash.Resources.Seating.Seat do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :ticket_code_per_org, [:ticket_code, :organization_id]
  end

  validations do
    validate present([
               :organization_id,
               :event_id,
               :seat_id,
               :checkout_id,
               :ticket_code,
               :status
             ])

    validate compare(:scan_count, greater_than_or_equal_to: 0)
  end

  actions do
    defaults [:read]

    create :create do
      primary? true

      accept [
        :organization_id,
        :event_id,
        :seat_id,
        :checkout_id,
        :user_id,
        :ticket_code,
        :status,
        :scan_count,
        :scanned_at,
        :last_gate_id
      ]
    end

    update :scan do
      require_atomic? false
      accept [:last_gate_id]

      argument :gate_id, :uuid do
        allow_nil? true
      end

      change transition_state(:scanned)
      change &__MODULE__.apply_scan/2
    end

    update :mark_used do
      require_atomic? false
      accept []

      change transition_state(:used)
      change &__MODULE__.transition_status_to_used/2
    end

    update :void do
      require_atomic? false
      accept []
      change transition_state(:voided)
      change &__MODULE__.transition_status_to_voided/2
    end

    update :refund do
      require_atomic? false
      accept []
      change transition_state(:refunded)
      change &__MODULE__.transition_status_to_refunded/2
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    # Read: Allow all authenticated org members (customers can view their tickets)
    policy action_type(:read) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Create: Only staff, admin, owner can create tickets
    policy action_type(:create) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(arg(:organization_id) != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin, :staff])
    end

    # Update/Destroy: Only staff, admin, owner
    policy action_type([:update, :destroy]) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin, :staff])
    end
  end

  def apply_scan(changeset, _context) do
    # Logic simplified as state_machine handles transition validation
    gate_id =
      Changeset.get_argument(changeset, :gate_id) ||
        Changeset.get_attribute(changeset, :last_gate_id)

    changeset
    |> Changeset.change_attribute(:scanned_at, DateTime.utc_now())
    |> maybe_set_gate(gate_id)
    |> increment_scan_count()
  end

  def transition_status_to_used(changeset, _context), do: changeset
  def transition_status_to_voided(changeset, _context), do: changeset
  def transition_status_to_refunded(changeset, _context), do: changeset

  defp maybe_set_gate(changeset, nil), do: changeset

  defp maybe_set_gate(changeset, gate_id) do
    Changeset.change_attribute(changeset, :last_gate_id, gate_id)
  end

  defp increment_scan_count(changeset) do
    current = Changeset.get_attribute(changeset, :scan_count) || 0
    Changeset.change_attribute(changeset, :scan_count, current + 1)
  end
end
