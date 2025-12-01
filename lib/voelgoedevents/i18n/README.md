# Internationalization Service Layer

**Purpose (Phase 20):** Central module for translation lookups and localization logic.
**Boundary:** Implements the hierarchical lookup: (Tenant Override -> Gettext -> Fallback).
**Ash Interaction:** Reads custom `TranslationKey` resources from the CMS/Events domain.
