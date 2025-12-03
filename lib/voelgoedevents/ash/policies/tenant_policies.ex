defmodule Voelgoedevents.Ash.Policies.TenantPolicies do
  @moduledoc """
  Shared tenant-isolation helpers for Ash resources.

  Centralizes the Appendix B multi-tenancy rules so every resource:
  - Declares an `organization_id` attribute
  - Denies by default and only authorizes when the record organization matches `actor(:organization_id)`
  - Scopes all reads and mutations to the actor organization without trusting params

  See `docs/architecture/02_multi_tenancy.md` for the platform-wide guidance these helpers enforce.
  """

  alias Ash.Resource.Info

  @doc """
  Compile-time guard that raises if the resource omits the required `organization_id` attribute.
  """
  defmacro require_organization_attribute! do
    quote do
      Voelgoedevents.Ash.Policies.TenantPolicies.__ensure_organization_attribute!(__MODULE__)
    end
  end

  @doc """
  Forbid access when the actor has no organization context (Appendix B Rule: no orgless access).
  """
  defmacro forbid_without_actor_org do
    quote do
      forbid_if expr(is_nil(actor(:organization_id)))
    end
  end

  @doc """
  Authorize only when the record organization matches the actor organization and apply a strict filter
  so all reads/mutations are scoped server-side (Appendix B Rules: never trust params; no cross-org joins).
  """
  defmacro scope_to_actor_organization do
    quote do
      authorize_if filter(expr(organization_id == actor(:organization_id)))
    end
  end

  @doc """
  Default tenant policy set: enforce presence of `organization_id`, deny by default, forbid orgless actors,
  and scope everything to the actor organization.
  """
  defmacro enforce_tenant_policies do
    quote do
      Voelgoedevents.Ash.Policies.TenantPolicies.require_organization_attribute!()

      policy action_type([:read, :create, :update, :destroy, :action]) do
        Voelgoedevents.Ash.Policies.TenantPolicies.forbid_without_actor_org()
        Voelgoedevents.Ash.Policies.TenantPolicies.scope_to_actor_organization()
      end

      default_policy :deny
    end
  end

  @doc false
  def __ensure_organization_attribute!(resource) do
    unless Info.attribute(resource, :organization_id) do
      raise ArgumentError,
            "#{inspect(resource)} must define :organization_id per Appendix B tenant isolation rules"
    end
  end
end
