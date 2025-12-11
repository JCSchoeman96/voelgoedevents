defmodule VoelgoedEvents.Ash.Embeds.SeoMetadata do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :meta_title, :string
    attribute :og_image_url, :string
  end
end
