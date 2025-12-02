# Search Service Layer

**Purpose:** Provides a fast, decoupled interface for full-text search and complex querying (e.g., finding events, user lookup).
**Implementation:** This layer abstracts the underlying search technology (e.g., ElasticSearch, PostGIS indexes) to prevent core application logic from becoming tightly coupled to the specific search tool.
