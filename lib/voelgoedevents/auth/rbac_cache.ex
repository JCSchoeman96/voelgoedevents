defmodule Voelgoedevents.Auth.RbacCache do
  @moduledoc """
  Compatibility wrapper around `Voelgoedevents.Caching.MembershipCache`.
  """

  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  alias Voelgoedevents.Caching.MembershipCache

  @spec fetch_role(binary(), binary(), keyword()) :: {:ok, atom() | nil} | {:error, term()}
  def fetch_role(user_id, organization_id, opts \\ []) do
    MembershipCache.fetch_role(user_id, organization_id, opts)
  end

  @spec refresh(Membership.t(), keyword()) :: :ok | {:error, term()}
  def refresh(%Membership{} = membership, opts \\ []) do
    MembershipCache.refresh(membership, opts)
  end

  @spec delete(binary(), binary()) :: :ok
  def delete(user_id, organization_id) do
    MembershipCache.invalidate(user_id, organization_id)
  end
end
