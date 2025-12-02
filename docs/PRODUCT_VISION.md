# VoelgoedEvents Product Vision

## Purpose
This document summarizes the target market, key differentiators, and how the product vision aligns with the platform direction defined in [MASTER_BLUEPRINT Section 1](MASTER_BLUEPRINT.md#1-vision--product-overview).

## Target Market
- **Event organisers and promoters** who need reliable sales, settlement, and scanning for small to large events in South Africa and beyond.
- **Venues and gate operations teams** that require predictable, offline-capable entry control across multiple gates and devices.
- **Agencies and white-label partners** seeking tenant-isolated, brandable experiences without sacrificing operational rigor.
- **Finance and compliance stakeholders** who demand immutable records, reconciliation-friendly ledgers, and auditability.

## Differentiators
- **Offline-first scanning** – Scanner PWA + Capacitor shell keeps validating tickets when networks degrade, with conflict-aware sync to protect against duplicate entries.
- **Multi-tenancy by design** – Organization-scoped resources, caches, and events prevent cross-tenant leakage while enabling white-label and agency partnerships.
- **Financial integrity** – Immutable ledger entries, idempotent payment workflows, and reconciliation-friendly reporting ensure settlements remain correct even under flash-sale load.

## Alignment with MASTER_BLUEPRINT Section 1
- Mirrors the mission to be a **high-reliability event platform** with offline-first scanning and multi-tenant readiness.
- Reinforces the core product pillars (Ticketing & Checkout, Scanning & Access Control, Operations & Dashboards, Marketing & Attribution, Multi-Tenant Platform).
- Emphasizes the architectural commitments to **Ash-powered domain logic**, **real-time readiness**, and **financial correctness** that underpin the roadmap.
