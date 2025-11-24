// Analytics events type definitions for the web app.

export type AnalyticsEventName =
  | "page_view"
  | "scroll_depth"
  | "add_to_cart"
  | "view_cart"
  | "start_checkout"
  | "checkout_success";

// TODO: Add strongly typed payloads per event.
