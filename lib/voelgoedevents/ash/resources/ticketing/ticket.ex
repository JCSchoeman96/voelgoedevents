defmodule Voelgoedevents.Ash.Resources.Ticketing.Ticket do
  @moduledoc "Ash resource: Ticket with state machine."

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.TicketingDomain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshStateMachine],
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("tickets")
    repo(Voelgoedevents.Repo)
  end

  states do
    state :active do
      initial? true
      description "Issued ticket that has not been scanned."
    end

    state :scanned do
      description "Ticket scanned for entry; re-entry may be allowed."
    end

    state :used do
      description "Ticket fully consumed for the event."
    end

    state :voided do
      description "Ticket invalidated (fraud/ops action)."
    end

    state :refunded do
      description "Ticket refunded after purchase."
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

    attribute :scanned_at, :utc_datetime do
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
      accept [:last_gate_id]

      argument :gate_id, :uuid do
        allow_nil? true
      end

      change &__MODULE__.apply_scan/2
    end

    update :mark_used do
      accept []

      change &__MODULE__.transition_status_to_used/2
    end

    update :void do
      accept []

      change &__MODULE__.transition_status_to_voided/2
    end

    update :refund do
      accept []

      change &__MODULE__.transition_status_to_refunded/2
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action_type([:read, :update]) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if always()
    end

    policy action(:create) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(arg(:organization_id) != actor(:organization_id))
      authorize_if always()
    end
  end

  def apply_scan(changeset, _context) do
    case Changeset.get_attribute(changeset, :status) do
      status when status in [:active, :scanned] ->
        gate_id =
          Changeset.get_argument(changeset, :gate_id) ||
            Changeset.get_attribute(changeset, :last_gate_id)

        changeset
        |> Changeset.change_attribute(:status, :scanned)
        |> Changeset.change_attribute(:scanned_at, DateTime.utc_now())
        |> maybe_set_gate(gate_id)
        |> increment_scan_count()

      status ->
        Changeset.add_error(
          changeset,
          :status,
          "status must be :active or :scanned to record a scan (current: #{status})"
        )
    end
  end

  def transition_status_to_used(changeset, _context) do
    transition_status(changeset, :used, [:active, :scanned])
  end

  def transition_status_to_voided(changeset, _context) do
    transition_status(changeset, :voided, [:active, :scanned])
  end

  def transition_status_to_refunded(changeset, _context) do
    transition_status(changeset, :refunded, [:active, :scanned, :voided])
  end

  defp transition_status(changeset, target, allowed) do
    current = Changeset.get_attribute(changeset, :status)

    if current in allowed do
      Changeset.change_attribute(changeset, :status, target)
    else
      Changeset.add_error(
        changeset,
        :status,
        "cannot transition from #{current} to #{target}"
      )
    end
  end

  defp maybe_set_gate(changeset, nil), do: changeset

  defp maybe_set_gate(changeset, gate_id) do
    Changeset.change_attribute(changeset, :last_gate_id, gate_id)
  end

  defp increment_scan_count(changeset) do
    current = Changeset.get_attribute(changeset, :scan_count) || 0
    Changeset.change_attribute(changeset, :scan_count, current + 1)
  end
end
