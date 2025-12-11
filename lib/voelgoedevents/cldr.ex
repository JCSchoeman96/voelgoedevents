defmodule Voelgoedevents.Cldr do
  use Cldr,
    locales: ["en", "af"],
    default_locale: "en",
    providers: [Cldr.Number, Money]

  # Removed Cldr.Unit, Cldr.List, Cldr.Calendar because the deps are not installed.
end
