## 💰 PHASE 6: Full Financial Ledger & Settlement Engine

**Goal:** Double-entry accounting, settlement calculations, financial reporting  
**Duration:** 2.5 weeks  
**Deliverables:** LedgerAccount, JournalEntry, Settlement resources; accounting workflows; FunnelSnapshot storage  
**Dependencies:** Completes Phase 4

---

### Phase 6.1: LedgerAccount Resource

#### Sub-Phase 6.1.1: Create LedgerAccount Resource

**Task:** Define LedgerAccount resource for double-entry bookkeeping  
**Objective:** Enable chart of accounts for financial integrity  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/ledger_account.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_ledger_accounts.exs`  
**Note:**  
- Account types: `:asset`, `:liability`, `:equity`, `:revenue`, `:expense`
- System accounts (seeded): `cash`, `accounts_receivable`, `ticket_revenue`, `platform_fees`, `organizer_payable`
- Reference `/docs/domain/payments_ledger.md` for chart of accounts
- Attributes: `id`, `organization_id`, `account_code` (unique per org), `name`, `account_type`, `parent_id` (nullable), `balance` (Decimal), `currency`, `status`, timestamps

---

### Phase 6.2: JournalEntry Resource

#### Sub-Phase 6.2.1: Create JournalEntry Resource

**Task:** Define JournalEntry resource for immutable transaction records  
**Objective:** Enable audit-grade financial tracking  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/journal_entry.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_journal_entries.exs`  
**Note:**  
- Each entry has paired debit/credit records (sum to zero)
- Attributes: `id`, `organization_id`, `entry_date`, `description`, `reference_id` (transaction_id, order_id, etc.), `reference_type`, `total_amount`, `status` (`:pending`, `:posted`, `:voided`), timestamps
- Relationships: `has_many :line_items, JournalEntryLineItem`

---

#### Sub-Phase 6.2.2: Create JournalEntryLineItem Resource

**Task:** Define JournalEntryLineItem (individual debit/credit line)  
**Objective:** Support double-entry bookkeeping integrity  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/journal_entry_line_item.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_journal_entry_line_items.exs`  
**Note:**  
- Attributes: `id`, `journal_entry_id`, `ledger_account_id`, `debit_amount`, `credit_amount`, `description`
- Constraint: `debit_amount` and `credit_amount` mutually exclusive (only one can be non-zero)
- Validation: Sum of debits = Sum of credits per entry

---

#### Sub-Phase 6.2.3: Create FunnelSnapshot Resource with Storage Strategy

**Task:** Define FunnelSnapshot resource for aggregated analytics with explicit caching strategy  
**Objective:** Store conversion funnel data with predictable performance characteristics  
**Output:**  
- `lib/voelgoedevents/ash/resources/analytics/funnel_snapshot.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_funnel_snapshots.exs`  
**Note:**  
- **Storage Strategy** (v7.1 clarification):
  - **Postgres (Primary):** Authoritative, durable storage for all snapshots
  - **Redis (Secondary):** Write-through cache for recent snapshots only
  - **TTL:** Redis snapshots expire after 24 hours (EXPIRE 86400)
  - **Write Pattern:** Write to Postgres first (authoritative), then populate Redis asynchronously
  - **Read Pattern:** Check Redis first (hot snapshots), fallback to Postgres (cold/historical snapshots)
- Reference `/docs/workflows/funnel_builder.md` for snapshot generation logic
- Reference Appendix C Section "Snapshot Caching Pattern" for implementation details
- Attributes: `id`, `organization_id`, `event_id`, `campaign_id` (nullable), `snapshot_date`, `visitor_count`, `checkout_started_count`, `checkout_completed_count`, `revenue_total`, `metadata`, timestamps
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) with snapshot-specific TTL

---

### Phase 6.3: Accounting Workflows

#### Sub-Phase 6.3.1: Implement Record Sale Workflow

**Task:** Create workflow to generate journal entries on ticket sale  
**Objective:** Automatically record revenue and payables  
**Output:** `lib/voelgoedevents/workflows/finance/record_sale.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for accounting logic
- Triggered by `complete_checkout` workflow (Phase 4)
- Example entries:
  - Debit: `cash` (total amount)
  - Credit: `ticket_revenue` (ticket price * quantity)
  - Credit: `platform_fees` (platform fee)
  - Credit: `organizer_payable` (net to organizer)
- All entries are atomic (transaction boundary)

---

#### Sub-Phase 6.3.2: Implement Record Refund Workflow

**Task:** Create workflow to reverse journal entries on refund  
**Objective:** Maintain accounting integrity during refunds  
**Output:** `lib/voelgoedevents/workflows/finance/record_refund.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for refund accounting
- Triggered by refund action (Phase 4)
- Reverse original entries (debit/credit swap)
- Update ledger account balances

---

### Phase 6.4: Settlement Resource

#### Sub-Phase 6.4.1: Create Settlement Resource

**Task:** Define Settlement resource for organizer payouts  
**Objective:** Track scheduled and completed payouts to organizers  
**Output:**  
- `lib/voelgoedevents/ash/resources/finance/settlement.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_settlements.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `event_id` (nullable), `settlement_date`, `total_amount`, `currency`, `status` (`:pending`, `:processing`, `:completed`, `:failed`), `metadata`, timestamps
- Relationships: `has_many :journal_entries` (payout entries)

---

#### Sub-Phase 6.4.2: Implement Calculate Settlement Workflow

**Task:** Create workflow to calculate net organizer payout  
**Objective:** Aggregate sales, fees, refunds into settlement amount  
**Output:** `lib/voelgoedevents/workflows/finance/calculate_settlement.ex`  
**Note:**  
- Reference `/docs/domain/payments_ledger.md` for settlement logic
- Query `organizer_payable` ledger account balance
- Apply settlement schedule (weekly, event-based, etc.)
- Generate Settlement record

---