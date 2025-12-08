# Domain: Payments & Ledger

## Overview & Purpose

The **Payments & Ledger** domain manages all financial transactions, ledger accounting, settlements, refunds, and stored-value systems in VoelgoedEvents. This domain is the financial spine of the platform, ensuring:

- **Financial Integrity**: Every money movement is recorded immutably in a double-entry ledger, which is the **platform's general ledger**, not per-organiser.
- **Reconciliation**: Platform, organisers, and auditors can trace every cent via immutable audit trails.
- **Multi-Tenant Isolation**: Each organisation's finances are completely isolated with dedicated ledger accounts.
- **Payment Provider Abstraction**: Support for multiple PSPs (PayStack, Yoco, Stripe, etc.) through a unified interface.
- **Cashless Events**: Attendees can load funds onto event cards, spend at vendors, and cash out unused balances.
- **Flexible Fee Models**: Support for client-pays, organiser-absorbs, or split-fee models, configurable per organisation with super-admin overrides.
- **Stored-Value Accounting**: Prepaid event cards represented as liabilities in the double-entry ledger.

This domain is committed to **zero-tolerance for financial inaccuracy**. All ledger entries are append-only, immutable, and must balance at all times.

---

## Scope & Non-Scope

### In Scope

- **Payment Processing**: Initiating, capturing, settling, and refunding payments with external PSPs.
- **Double-Entry Ledger**: Account hierarchies, journal entries, and balance integrity (platform's general ledger only).
- **Payout Settlements**: Calculating and scheduling payouts to organisers and venues.
- **Refunds & Reversals**: Handling full and partial refunds with ledger reversal.
- **Stored-Value / Cashless Systems**: Event card/wallet creation, top-up, spend, and cashout flows, with offline reconciliation.
- **Transaction Auditing**: Immutable audit trail for compliance and dispute resolution.
- **Fee Configuration**: Multi-mode fee models (flat, percentage, tiered) per organisation.
- **Chargeback Handling**: Explicit chargeback resource and reversal flows.
- **Donation System**: Optional donations for free/NPO events.
- **Super-Admin Policy Overrides**: Configuration per organisation for fees, payouts, stored value, and donations.

### Out of Scope (MVP)

- Tax compliance engines (VAT/VATSHT auto-calculation by jurisdiction) — deferred to Phase 6+.
- Full ERP-grade accounting (consolidated reporting across thousands of organisations) — simpler aggregation in MVP.
- Multi-currency transactions (MVP is ZAR-only, but ledger design allows future multi-currency).

---

## Personas & Use Cases

### 1. **Event Organiser / Finance Manager**

- View total revenue from ticket sales (net of platform fees).
- Understand fee breakdowns (platform fees, payment processor fees, taxes).
- Schedule and track payouts to their bank account.
- Reconcile ledger with external bank statements.
- Issue refunds and verify ledger reversal.
- Understand which fee model applies to their events (Client Pays, Organiser Absorbs, Split).

### 2. **Platform Finance & Accounting**

- Monitor platform fee accumulation across all events.
- Generate financial reports for stakeholders.
- Reconcile payment provider webhooks with ledger entries.
- Audit all ledger transactions for compliance.
- Debug discrepancies between expected and actual balances.
- Manage chargeback reserves and dispute resolution.

### 3. **Attendee (Cashless Card User)**

- Load money onto event card (online or at venue).
- View balance and transaction history.
- Spend money at event vendors.
- Receive receipt for each spend.
- Request cashout of remaining balance post-event (via bank transfer).

### 4. **Compliance & Audit**

- Query immutable ledger for proof of transaction.
- Verify double-entry integrity (debits = credits).
- Trace individual ticket sale from order → payment → ledger → payout.
- Generate reports for regulators (SARB, NCR, FAIS if applicable).

### 5. **Support / Disputes Team**

- Review transaction details when customer disputes a charge.
- Manually adjust ledger entries (with audit log) if warranted.
- Void or reverse a transaction post-fact.
- Manage chargebacks and refund exceptions.

### 6. **Super-Admin / Platform Operator**

- Configure fee models per organisation.
- Set NPO status and enable/disable donations.
- Override payout cadence and thresholds.
- Control which payment gateways are available.
- Enable/disable stored value for tenant.

---

## Conceptual Model

### Core Concepts

**Transaction**: A single checkout/payment attempt tied to an order. Represents the external payment processor's state (initiated, pending, succeeded, failed, refunded). All transactions belong to a single organisation.

**Order**: Groups tickets and line items into a single purchase. Tied to a transaction. Moves through states: pending payment → paid → fulfilled → cancelled/refunded.

**Ledger Account**: A named financial account (e.g., "Cash", "Ticket Revenue", "Payable to Organiser A"). Belongs to an organisation. Carries a running balance derived from journal entries. The platform maintains **one general ledger per organisation**, not per-organiser sub-ledgers.

**Journal Entry**: An immutable record of a financial movement. Each entry contains **multiple line items**, each being a debit or credit to a ledger account. Entries must balance (sum of debits = sum of credits). Represents the platform's general ledger perspective.

**Payout**: A settlement payment to an organiser. Aggregates net revenue (ticket sales minus fees minus refunds) from the organiser's payable account and moves funds to the organiser's bank account.

**Refund**: A cancellation or partial reversal of a ticket sale. Triggers reversal of original journal entries, potentially resulting in negative organiser payable balances (held for future payouts).

**Chargeback**: A reversal by the payment processor or cardholder. Explicitly modeled as a resource to track disputes and reserve calculations.

**Payment Method**: Stores minimal payment provider tokens (PCI-light). Encrypts sensitive data. Supports multiple providers per organisation.

**Stored-Value Card / Wallet**: A prepaid account tied to an event or organisation. Attendees load funds, spend at vendors, and request cashout. Represented in the ledger as a liability (funds held on behalf of cardholder).

### Relationships

```
Order
├── hasmany Tickets (ordered items)
├── hasone Transaction (payment)
├── hasmany JournalEntries (ledger records)
└── hasone LedgerAccount:OrganizerPayable (organiser's liability)

Transaction
├── belongsto Organization
├── belongsto Order
├── belongsto PaymentMethod (tokenized card/provider reference)
├── hasmany JournalEntries (all ledger lines for this payment)
├── hasmany Refunds (partial/full reversals)
├── hasmany Chargebacks (processor reversals)
└── timestamps: created_at, succeeded_at, failed_at

JournalEntry
├── belongsto Organization
├── hasmany JournalEntryLineItems (debit/credit pairs)
├── references Transaction, Refund, Payout, or Chargeback (polymorphic)
└── immutable: once posted, cannot be modified (only reversed)

LedgerAccount
├── belongsto Organization
├── account_type: asset, liability, equity, revenue, expense, fee
├── hasmany JournalEntryLineItems (all debits/credits to this account)
└── derives Balance: sum of credits - sum of debits (signed per account type)

Refund
├── belongsto Organization
├── belongsto Transaction or Ticket
├── hasmany JournalEntries (reversal entries, which may result in negative payable balance)
├── reason: customer_request, duplicate_charge, system_error, refund_policy_violation
└── status: pending, approved, processing, completed, failed

Chargeback
├── belongsto Organization
├── belongsto Transaction
├── hasmany JournalEntries (reversal entries)
├── chargeback_code, reason, processor_reference
├── reserve_amount (3% of transaction for 7 days)
└── status: pending_investigation, approved, reversed, lost

Payout
├── belongsto Organization
├── references LedgerAccount:OrganizerPayable
├── hasmany JournalEntries (settlement entries)
├── bank_transfer_reference (external bank transfer ID)
└── status: pending, processing, completed, failed

PaymentPolicy (new)
├── belongsto Organization
├── fee_mode: client_pays_all, organiser_absorbs, split_model
├── platform_fee_percent, flat_fee_cents, tiered_fees[]
├── gateway_fee_handling: refundable, non_refundable
├── payout_cadence: weekly, event_based, monthly, on_demand
├── min_payout_threshold_cents
├── chargeback_reserve_percent
├── donation_enabled, auto_cashout_enabled
└── status: active, archived

StoredValueCard / CashlessWallet
├── belongsto Organization
├── belongsto Event (optional)
├── belongsto User (optional, user may link later)
├── hasmany WalletTransactions
├── hasone LedgerAccount:StoredValuePayable (liability representing funds owed)
└── auto_cashout_rule, expiry_date, online_topup_enabled, offline_terminal_enabled
```

---

## Data Model & Resources

### 1. **Transaction** (Payment Processing)

**Module**: `Voelgoedevents.Ash.Resources.Payments.Transaction`  
**File**: `lib/voelgoedevents/ash/resources/payments/transaction.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Track a single payment attempt lifecycle (initiated → pending → succeeded → failed → refunded).

**Key Fields**:

- `id` (UUID, primary key)
- `organization_id` (UUID) — multi-tenancy
- `order_id` (UUID) — links to order
- `user_id` (UUID, nullable) — customer
- `provider` (atom: `:paystack`, `:yoco`, `:stripe`, etc.)
- `provider_transaction_id` (string) — external provider's reference
- `amount_cents` (integer) — total transaction amount in cents (ZAR)
- `currency` (string, default `"ZAR"`)
- `status` (atom: `:initiated`, `:pending`, `:succeeded`, `:failed`, `:refunded`)
- `payment_method_id` (UUID, nullable)
- `metadata` (JSONB) — provider-specific data, webhook payload
- `succeeded_at`, `failed_at` (datetime, nullable)
- `created_at`, `updated_at`

**State Machine** (Ash.StateMachine):

- `:initiated` → `:pending` (initiate with provider)
- `:pending` → `:succeeded` (webhook: payment confirmed)
- `:pending` → `:failed` (webhook: payment declined)
- `:succeeded` → `:refunded` (refund initiated)

**Invariants**:

- `provider_transaction_id` MUST be unique per provider (detects duplicate webhooks).
- `amount_cents` MUST be > 0.
- `currency` MUST match order/event defaults.
- Status transitions are unidirectional.

---

### 2. **Refund** (Cancellation & Reversal)

**Module**: `Voelgoedevents.Ash.Resources.Payments.Refund`  
**File**: `lib/voelgoedevents/ash/resources/payments/refund.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Record and process cancellations or partial refunds. Automatically reverse corresponding ledger entries.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `transaction_id` (UUID, nullable) — original transaction being refunded
- `order_id` (UUID, nullable)
- `ticket_ids` (array of UUIDs, nullable) — specific tickets being voided
- `amount_cents` (integer) — refund amount
- `reason` (atom: `:customer_request`, `:duplicate_charge`, `:system_error`, `:partial_delivery`, `:refund_policy_violation`)
- `status` (atom: `:pending`, `:approved`, `:processing`, `:completed`, `:failed`, `:rejected`)
- `initiated_by_user_id` (UUID)
- `approved_by_user_id` (UUID, nullable)
- `refund_fee_mode` (atom: `:non_refundable_fees`, `:refundable_fees`, `:organiser_absorbs_fee`) — determined by PaymentPolicy at time of refund
- `created_at`, `processed_at`, `completed_at`

**State Machine**:

- `:pending` → `:approved` (manager/organiser approves)
- `:approved` → `:processing` (system initiates reversal)
- `:processing` → `:completed` (ledger reversed, funds returned)
- `:approved` / `:processing` → `:failed` (reversal failed, retry or manual)
- `:pending` → `:rejected` (denied by manager)

**Ledger Logic**:

- **Non-Refundable Fees** (default): Platform fees are NOT reversed. Only ticket revenue and processor fees are reversed.
  ```
  Debit 4000-REVENUE-TICKET      (original ticket amount)
  Credit 1000-CASH               (refund to customer)
  (Platform fee stays as revenue)
  ```
- **Refundable Fees**: All amounts including platform fee are reversed (rare, requires explicit fee mode).
- **Organiser Absorbs Fee**: Organiser's payable account is reduced by the fee amount; customer gets full refund.

**Multi-Tenancy**:

- Every refund filtered by `organization_id`.

**Invariants**:

- Refund `amount_cents` cannot exceed original transaction.
- Refund cannot be initiated if transaction still pending.
- If payouts already processed: organiser payable can go negative (blocked for future payouts).

---

### 3. **LedgerAccount** (Chart of Accounts)

**Module**: `Voelgoedevents.Ash.Resources.Payments.LedgerAccount`  
**File**: `lib/voelgoedevents/ash/resources/payments/ledger_account.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Define named financial accounts for an organisation. Acts as the debit/credit target for all journal entries.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `account_code` (string, unique per org) — human-readable ID (e.g., "1000-CASH")
- `name` (string) — display name
- `account_type` (atom: `:asset`, `:liability`, `:equity`, `:revenue`, `:expense`, `:fee`)
- `parent_id` (UUID, nullable) — hierarchical chart of accounts
- `currency` (string, default `"ZAR"`)
- `status` (atom: `:active`, `:inactive`, `:archived`)
- `created_at`, `updated_at`

**Seeded System Accounts** (per organisation, auto-created):

| Account Code                    | Type      | Purpose                                                                  |
| ------------------------------- | --------- | ------------------------------------------------------------------------ |
| 1000-CASH                       | Asset     | Operating cash account                                                   |
| 1100-ACCOUNTS-RECEIVABLE        | Asset     | Customer refund liabilities                                              |
| 2000-PAYABLE-ORGANIZER-{ORG_ID} | Liability | Net amount owed to organiser (can go negative if refunds exceed revenue) |
| 2100-PAYABLE-PROCESSOR          | Liability | Fees owed to payment processor                                           |
| 2200-PAYABLE-TAX                | Liability | Sales tax payable                                                        |
| 2500-STORED-VALUE-PAYABLE       | Liability | Funds held for prepaid cards (aggregate across all wallets)              |
| 3000-EQUITY-RETAINED            | Equity    | Platform's equity                                                        |
| 4000-REVENUE-TICKET             | Revenue   | Ticket sales revenue                                                     |
| 4100-REVENUE-LATE-FEES          | Revenue   | Late booking premiums                                                    |
| 4200-REVENUE-VENDOR-SALES       | Revenue   | Cashless vendor spends at event                                          |
| 4300-REVENUE-FORFEITED-CARDS    | Revenue   | Expired card balances (attendee forfeiture)                              |
| 4400-DONATION-REVENUE           | Revenue   | Donations (free events / NPO)                                            |
| 5000-EXPENSE-PLATFORM-FEE       | Expense   | Fees retained by platform                                                |
| 5100-EXPENSE-PROCESSOR-FEE      | Expense   | Payment processor charges                                                |
| 5200-EXPENSE-REFUND-CHARGEBACK  | Expense   | Chargeback losses                                                        |
| 5300-RESERVE-ESCROW             | Liability | Chargeback reserve (3% x 7 days)                                         |

**Calculations**:

- `balance`: Derived from all `journal_entry_line_items`.
  - **For asset/expense accounts**: sum of debits − sum of credits.
  - **For liability/revenue accounts**: sum of credits − sum of debits.

**Invariants**:

- `account_code` is globally unique within an organisation.
- Account type is immutable once created.
- No account can be deleted if non-zero balance (archive instead).

---

### 4. **JournalEntry** (Immutable Transaction Records)

**Module**: `Voelgoedevents.Ash.Resources.Payments.JournalEntry`  
**File**: `lib/voelgoedevents/ash/resources/payments/journal_entry.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Immutable ledger record. Each entry contains balanced debit/credit pairs and references the originating business event.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `entry_date` (date) — when entry was posted
- `reference_type` (atom: `:order`, `:refund`, `:payout`, `:chargeback`, `:donation`, `:manual_adjustment`, `:reversal`)
- `reference_id` (UUID) — ID of the referenced resource
- `description` (string) — human-readable summary
- `currency` (string, default `"ZAR"`)
- `status` (atom: `:pending`, `:posted`, `:voided`)
- `created_at`, `posted_at` (datetime)

**Embedded Line Items** (JournalEntryLineItem):

- `ledger_account_id` (UUID)
- `debit_amount_cents` (integer, nullable) — NULL if credit
- `credit_amount_cents` (integer, nullable) — NULL if debit
- `description` (string) — e.g., "Ticket revenue"

**Validation** (Ash Validator: BalancedEntry):

- Every entry MUST have ≥ 2 line items.
- MUST balance: sum of debits = sum of credits.
- Cannot mix debit and credit on same line item.
- All accounts MUST exist and belong to same organisation.

**Immutability**:

- Once posted, entries CANNOT be edited or deleted.
- Corrections are made via **reversal entries** (new entries with opposite signs).
- Status: pending → posted → (optionally) voided.

---

### 5. **Payout** (Settlement to Organisers)

**Module**: `Voelgoedevents.Ash.Resources.Payments.Payout`  
**File**: `lib/voelgoedevents/ash/resources/payments/payout.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Schedule and execute payouts to organisers based on net revenue from their ledger account.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID) — organiser being paid
- `event_id` (UUID, nullable) — if event-based payout
- `payout_date` (date) — scheduled or actual payout date
- `amount_cents` (integer) — net amount (can be negative if refunds exceed revenue; blocks payout)
- `currency` (string, default `"ZAR"`)
- `status` (atom: `:pending`, `:approved`, `:processing`, `:completed`, `:failed`)
- `bank_account_id` (UUID, nullable) — organiser's bank account (encrypted)
- `bank_transfer_reference` (string, nullable) — external bank ref
- `created_at`, `completed_at`

**Calculation Logic**:

```
Net Payout = Balance of 2000-PAYABLE-ORGANIZER-{ORG_ID} account
If Net Payout < 0 (refunds > revenue):
  Block payout. Notify organiser.
  Hold for next settlement cycle.
If Net Payout >= min_threshold:
  Proceed.
Otherwise:
  Wait for next payout cycle.
```

**Ledger Entries** (when approved):

```
Debit  2000-PAYABLE-ORGANIZER-{ORG_ID}    (reduce liability)
Credit 1000-CASH                           (cash out)
```

**Payout Cadences** (set per organisation via PaymentPolicy):

- `weekly` (default): Every Monday
- `event_based`: T+3 days after event ends
- `monthly`: First business day of month (NPO default)
- `on_demand`: Trusted orgs can request immediate payout

**Minimum Payout Threshold**: ZAR 200 (configurable per organisation).

**Chargeback Reserve** (3% × 7 days):

- Held in 5300-RESERVE-ESCROW pending chargeback resolution.
- Released after 7 days if no chargeback.

**Invariants**:

- Cannot payout if amount < 0 (negative balance blocks payout).
- Cannot payout without verified bank account (KYC).
- Cannot payout less than min threshold.

---

### 6. **PaymentMethod** (Tokenized Provider References)

**Module**: `Voelgoedevents.Ash.Resources.Payments.PaymentMethod`  
**File**: `lib/voelgoedevents/ash/resources/payments/payment_method.ex`  
**Phase Introduced**: Phase 4

**Responsibility**: Store minimal, encrypted payment provider tokens.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `user_id` (UUID, nullable)
- `provider` (atom: `:paystack`, `:yoco`, `:stripe`)
- `provider_token` (encrypted string)
- `payment_type` (atom: `:card`, `:bank_transfer`, `:ewallet`)
- `card_last_four` (string, nullable, encrypted)
- `card_brand` (atom, nullable: `:visa`, `:mastercard`, `:amex`)
- `status` (atom: `:active`, `:expired`, `:revoked`)
- `created_at`, `updated_at`

**Encryption**:

- `provider_token`, `card_last_four` encrypted at rest using Cloak.
- Decryption only on read (not in indexes).

**Invariants**:

- MUST NOT store full card PAN (PCI-DSS).
- `provider_token` is unique per provider.

---

### 7. **CashlessWallet** (Prepaid Event Account)

**Module**: `Voelgoedevents.Ash.Resources.Payments.CashlessWallet`  
**File**: `lib/voelgoedevents/ash/resources/payments/cashless_wallet.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Manage prepaid event cards and digital wallets.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `event_id` (UUID, nullable) — event-scoped or org-wide
- `card_number` (string, unique) — physical card ID or token (encrypted)
- `card_type` (atom: `:physical_card`, `:digital_wallet`, `:wristband`)
- `user_id` (UUID, nullable) — link to user account (for later)
- `balance_cents` (integer, derived) — current available balance
- `reserved_cents` (integer, derived) — pending/held amounts
- `status` (atom: `:active`, `:paused`, `:expired`, `:lost_reported`, `:closed`)
- `currency` (string, default `"ZAR"`)
- `expires_at` (datetime, optional) — 1-2 years post-event
- `auto_cashout_enabled` (boolean) — auto-cashout after event
- `auto_cashout_threshold_cents` (integer) — minimum to trigger auto-cashout
- `online_topup_enabled` (boolean) — allow online app/web top-ups
- `offline_terminal_enabled` (boolean) — allow offline kiosk top-ups
- `created_at`, `last_used_at`

**Ledger Representation**:
Each wallet is represented as a liability account aggregate:

```
Account: 2500-STORED-VALUE-PAYABLE (shared across all wallets)
Type: Liability (funds held on behalf of cardholders)
Balance: sum of all wallet balances
```

**Relationships**:

- `has_many :wallet_transactions` — immutable log of top-ups, spends, cashouts
- `has_one :ledger_account` (2500 shared or per-wallet if high volume)

**Multi-Tenancy**:

- Each organisation's wallets isolated.
- Event-scoped wallets belong to an organisation.

**Invariants**:

- Balance CANNOT go negative (prepaid, not credit).
- Cannot spend more than balance.
- Offline terminals use cached balance; reconcile on reconnect.

---

### 8. **StoredValueCard** (Physical/Linked Representation)

**Module**: `Voelgoedevents.Ash.Resources.Payments.StoredValueCard`  
**File**: `lib/voelgoedevents/ash/resources/payments/stored_value_card.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Represent physical cards or digital identifiers. Can be anonymous or linked to user.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `wallet_id` (UUID) — references CashlessWallet
- `card_identifier` (string, unique) — physical card UID or digital token
- `linkable` (boolean) — can be linked to user account later
- `linked_user_id` (UUID, nullable) — user account if linked
- `is_anonymous` (boolean) — true if never linked
- `created_at`, `linked_at`

**Invariants**:

- Once linked to a user, cannot be unlinked.
- Anonymous cards CAN be linked by user claiming via QR or code.

---

### 9. **WalletTransaction** (Immutable Ledger of Top-Ups, Spends, Cashouts)

**Module**: `Voelgoedevents.Ash.Resources.Payments.WalletTransaction`  
**File**: `lib/voelgoedevents/ash/resources/payments/wallet_transaction.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Immutable log of each top-up, spend, or cashout. Each WalletTransaction is recorded via a JournalEntry.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `wallet_id` (UUID)
- `transaction_type` (atom: `:topup`, `:spend`, `:cashout`, `:refund`, `:expiry_void`)
- `amount_cents` (integer)
- `source` (string) — `online_app`, `online_web`, `atm_cash`, `vendor_terminal`, `kiosk`, `bank_transfer`, `cashout_request`
- `vendor_id` (UUID, nullable) — if spend at vendor
- `status` (atom: `:pending`, `:completed`, `:failed`, `:reversed`)
- `journal_entry_id` (UUID, nullable) — references corresponding JournalEntry
- `created_at`, `completed_at`

**Offline Behaviour**:

- Terminal keeps local pending queue of transactions.
- On reconnect, sync transactions back to platform.
- Server resolves conflicts (double-spends, late syncs).
- Server updates wallet balance.

**Invariants**:

- MUST be immutable once created.
- MUST reference corresponding JournalEntry.

---

### 10. **CashoutRequest** (Withdrawal of Stored Value)

**Module**: `Voelgoedevents.Ash.Resources.Payments.CashoutRequest`  
**File**: `lib/voelgoedevents/ash/resources/payments/cashout_request.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Track requests to withdraw prepaid stored-value balances.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `wallet_id` (UUID)
- `user_id` (UUID) — who requested
- `amount_cents` (integer)
- `bank_account` (encrypted JSONB) — destination
- `status` (atom: `:pending`, `:approved`, `:processing`, `:completed`, `:failed`, `:declined`)
- `bank_transfer_reference` (string, nullable)
- `created_at`, `completed_at`

**State Machine**:

- `:pending` → `:approved` (auto or manual review)
- `:approved` → `:processing` (initiate bank transfer)
- `:processing` → `:completed` (bank confirms)
- Any → `:failed` (retry on next cron)

**Validation**:

- Minimum cashout ZAR 50.
- User MUST have KYC / bank account on file.
- Cannot cashout more than balance.

**Auto-Cashout** (Post-Event):

- After event ends, if wallet balance ≥ auto_cashout_threshold (configurable, e.g., ZAR 10).
- Automatically approve and process CashoutRequest.
- Notify user of auto-cashout.

---

### 11. **Chargeback** (Processor Reversal & Dispute)

**Module**: `Voelgoedevents.Ash.Resources.Payments.Chargeback`  
**File**: `lib/voelgoedevents/ash/resources/payments/chargeback.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Track chargebacks from payment processors or cardholders. Model disputes and reversals.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `transaction_id` (UUID) — original transaction
- `chargeback_code` (string) — processor chargeback code (e.g., "1100" for Visa)
- `reason` (string) — e.g., "Unauthorized transaction", "Duplicate charge"
- `processor_reference` (string) — provider's chargeback ID
- `amount_cents` (integer)
- `status` (atom: `:pending_investigation`, `:approved`, `:reversed`, `:lost`)
- `reserve_amount_cents` (integer) — 3% of transaction, held in escrow
- `reserve_until` (datetime) — 7 days from chargeback date
- `evidence_deadline` (datetime) — deadline to provide evidence
- `created_at`, `resolved_at`

**State Machine**:

- `:pending_investigation` → `:approved` (organiser provides evidence, chargeback approved)
- `:pending_investigation` → `:reversed` (chargeback won, funds returned to cardholder)
- `:pending_investigation` → `:lost` (chargeback lost, organiser absorbs loss)

**Ledger Entries** (when chargeback approved):

```
Debit  2000-PAYABLE-ORGANIZER-{ORG_ID}    (reduce organiser's payable)
Debit  5200-EXPENSE-REFUND-CHARGEBACK     (loss to platform)
Credit 1000-CASH                           (funds reversed from account)
```

**Reserve Handling**:

- On chargeback creation: reserve 3% of transaction in 5300-RESERVE-ESCROW.
- If chargeback lost: reserve is transferred to 5200-EXPENSE-REFUND-CHARGEBACK.
- If chargeback won: reserve is released.
- Payouts blocked until reserve released (7 days).

**Invariants**:

- Chargebacks cannot be created for transactions already refunded.
- Only one active chargeback per transaction.

---

### 12. **PaymentPolicy** (Fee & Payout Configuration)

**Module**: `Voelgoedevents.Ash.Resources.Payments.PaymentPolicy`  
**File**: `lib/voelgoedevents/ash/resources/payments/payment_policy.ex`  
**Phase Introduced**: Phase 6

**Responsibility**: Configure fees, payout cadence, and stored-value behaviour per organisation. Super-admin can override.

**Key Fields**:

- `id` (UUID)
- `organization_id` (UUID)
- `fee_mode` (atom: `:client_pays_all`, `:organiser_absorbs`, `:split_model`)
  - **Client Pays All**: Customer pays 100% of platform + processor fees.
  - **Organiser Absorbs**: Organiser pays both platform and processor fees (rare, loss model).
  - **Split Model**: Customer pays processor fee; organiser pays platform fee.
- `platform_fee` (embedded):
  - `fee_type` (atom: `:flat`, `:percentage`, `:mixed`, `:tiered`)
  - `flat_amount_cents` (integer, nullable)
  - `percentage` (decimal, nullable) — e.g., 0.025 for 2.5%
  - `tiered_amounts` (array, nullable) — e.g., `[{min: 0, max: 5000, percent: 0.03}, ...]`
- `processor_fee_type` (atom: `:refundable`, `:non_refundable`) — on refund
- `payout_cadence` (atom: `:weekly`, `:event_based`, `:monthly`, `:on_demand`)
- `min_payout_threshold_cents` (integer, default 20000) — ZAR 200
- `chargeback_reserve_percent` (integer, default 3) — 3%
- `chargeback_reserve_days` (integer, default 7)
- `is_npo` (boolean) — Non-Profit Organisation
- `npo_platform_fee_percent` (integer, default 0) — ZAR 0 for NPO
- `donation_enabled` (boolean) — For free/NPO events
- `donation_optional_amounts_cents` (array) — e.g., `[500, 1000, 2000]` (ZAR 5, 10, 20)
- `stored_value_enabled` (boolean) — Enable cashless cards for this org
- `auto_cashout_enabled` (boolean) — Auto-cashout post-event
- `auto_cashout_threshold_cents` (integer, default 1000) — ZAR 10
- `allowed_payment_gateways` (array of atoms) — e.g., `[:paystack, :yoco]`
- `created_at`, `updated_at`

**Relationships**:

- `belongs_to :organization`
- Enforced via Ash.Policy during payment & refund workflows.

**Super-Admin Overrides**:

- Super-admin CAN set all fields for a tenant via admin UI.
- Defaults apply if not set: client_pays_all, weekly, ZAR 200 threshold, etc.

---

## Ledger & Accounting Rules

### Ledger Viewpoint

**Critical**: VoelgoedEvents maintains **the platform's general ledger**, NOT per-organiser sub-ledgers.

- **One general ledger per organisation** (not per organiser).
- Organisers are modeled as **creditors** via a Payable liability account: `2000-PAYABLE-ORGANIZER-{ORG_ID}`.
- All ticket sales, fees, refunds, chargebacks, donations are recorded in the platform's ledger.
- The organiser's "revenue" is the credit balance in their payable account.

### Accounting Examples (Corrected)

#### **Scenario 1: Ticket Sale (Client Pays All Fees)**

**Given**: Customer purchases 2 VIP tickets at ZAR 500 each (ZAR 1000 total).

- Platform fee: 2.5% = ZAR 25
- Processor fee: 1.5% + ZAR 0.30 = ZAR 15.30 (total ZAR 15 for simplicity)
- **Total charged to customer**: ZAR 1000 + ZAR 25 + ZAR 15 = ZAR 1040

**Journal Entry** (Platform's General Ledger):

```
Entry Date: 2025-01-15
Reference: Order ORD-123, Transaction TXN-456
Description: Ticket sale for 2 VIP seats - Coachella 2025

Line Items:
  1. Debit  1000-CASH                        1040 ZAR  (customer payment)
  2. Credit 2000-PAYABLE-ORGANIZER-ABC      1000 ZAR  (organiser's earnings)
  3. Credit 5000-EXPENSE-PLATFORM-FEE          25 ZAR  (platform retains fee)
  4. Credit 5100-EXPENSE-PROCESSOR-FEE         15 ZAR  (paid to processor later)

Total Debits:  1040 ZAR
Total Credits: 1040 ZAR ✓ Balanced
```

**Interpretation**:

- Cash increased by ZAR 1040.
- Organiser's payable (liability) increased by ZAR 1000 → organiser can payout ZAR 1000.
- Platform captured ZAR 40 in fees (25 + 15).

---

#### **Scenario 2: Full Refund (Non-Refundable Fees)**

**Given**: Customer refunds ZAR 1000 ticket sale (Scenario 1).  
Fee policy: **Platform fee is non-refundable**.

**Journal Entry** (Reversal):

```
Entry Date: 2025-01-16
Reference: Refund REF-789 (reverses Order ORD-123)
Description: Full refund of 2 VIP tickets

Line Items:
  1. Debit  2000-PAYABLE-ORGANIZER-ABC       1000 ZAR  (reverse organiser's earnings)
  2. Credit 5100-EXPENSE-PROCESSOR-FEE          15 ZAR  (refund processor fee)
  3. Credit 1000-CASH                        1015 ZAR  (return to customer - full ticket + processor fee only)

Total Debits:  1015 ZAR
Total Credits: 1015 ZAR ✓ Balanced

Result:
- Organiser payable reduced by ZAR 1000.
- If organiser balance was ZAR 1000, it is now ZAR 0.
- Platform fee (ZAR 25) remains captured as revenue.
- Processor fee (ZAR 15) is refunded.
```

**Alternative: Refundable Fees**

If fee policy is **refundable_fees**:

```
Line Items:
  1. Debit  2000-PAYABLE-ORGANIZER-ABC       1025 ZAR  (reverse all)
  2. Credit 5000-EXPENSE-PLATFORM-FEE           25 ZAR  (refund platform fee)
  3. Credit 5100-EXPENSE-PROCESSOR-FEE          15 ZAR  (refund processor fee)
  4. Credit 1000-CASH                        1040 ZAR  (return full amount)
```

---

#### **Scenario 3: Partial Refund**

**Given**: Customer paid ZAR 1000, now refunds ZAR 300 (1 of 2 tickets).

**Journal Entry**:

```
Line Items:
  1. Debit  2000-PAYABLE-ORGANIZER-ABC        300 ZAR  (reduce organiser's portion)
  2. Credit 5100-EXPENSE-PROCESSOR-FEE          5 ZAR  (proportional processor fee)
  3. Credit 1000-CASH                         305 ZAR  (return to customer)

Result:
- Organiser payable reduced by ZAR 300.
- Remaining ticket (ZAR 700) stays in organiser's account.
```

---

#### **Scenario 4: Payout to Organiser**

**Given**: Organiser ABC has accumulated ZAR 5000 in ticket sales over a week.

- Platform fee was ZAR 125 (2.5% of ZAR 5000).
- One refund of ZAR 300 was issued.
- **Organiser's payable balance**: ZAR 5000 − ZAR 300 = ZAR 4700.

**Payout Created**:

- Status: `:pending` → `:approved` (finance reviews) → `:processing` (bank transfer initiated) → `:completed`.

**Journal Entry** (when approved):

```
Entry Date: 2025-01-20
Reference: Payout PAYOUT-001
Description: Weekly settlement to Organiser ABC

Line Items:
  1. Debit  2000-PAYABLE-ORGANIZER-ABC       4700 ZAR  (settle liability)
  2. Credit 1000-CASH                        4700 ZAR  (cash out)

Result:
- Organiser's payable balance now ZAR 0.
- Cash account reduced by ZAR 4700 (transferred to organiser's bank).
- Bank transfer reference recorded for audit.
```

---

#### **Scenario 5: Stored-Value Top-Up (Event Card)**

**Given**: Attendee loads ZAR 500 onto event card using cash at venue ATM.

**Journal Entry**:

```
Entry Date: 2025-01-15
Reference: WalletTransaction WT-111
Description: Event card top-up - Card #CARD-ABC

Line Items:
  1. Debit  1000-CASH                         500 ZAR  (cash in from attendee)
  2. Credit 2500-STORED-VALUE-PAYABLE        500 ZAR  (liability: platform owes attendee)

Result:
- Platform holds ZAR 500 on behalf of attendee.
- Entry is a liability (platform owes the value).
```

---

#### **Scenario 6: Stored-Value Spend at Vendor**

**Given**: Attendee spends ZAR 100 at food vendor at event.

**Journal Entry**:

```
Entry Date: 2025-01-15
Reference: WalletTransaction WT-222
Description: Cashless spend - Vendor "Food Court", Card #CARD-ABC

Line Items:
  1. Debit  2500-STORED-VALUE-PAYABLE        100 ZAR  (reduce liability)
  2. Credit 4200-REVENUE-VENDOR-SALES        100 ZAR  (recognise vendor revenue)

Result:
- Attendee's balance reduced by ZAR 100.
- Platform recognises revenue from vendor activity.
```

---

#### **Scenario 7: Stored-Value Cashout (Post-Event)**

**Given**: Event ends. Attendee had ZAR 500 loaded, spent ZAR 100, has ZAR 400 remaining. Requests cashout.

**Journal Entry** (when approved & bank transfer confirmed):

```
Entry Date: 2025-01-30
Reference: CashoutRequest CASHOUT-001
Description: Stored value cashout - Card #CARD-ABC

Line Items:
  1. Debit  2500-STORED-VALUE-PAYABLE        400 ZAR  (clear liability)
  2. Credit 1000-CASH                        400 ZAR  (cash reserved)

(Bank transfer executed; reference recorded.)

Result:
- Liability fully cleared.
- Attendee receives ZAR 400 to their bank account.
```

---

#### **Scenario 8: Stored-Value Expiry (No Cashout After N Days)**

**Given**: Event ended 1 year ago. Attendee never cashed out. Remaining ZAR 400 expires (per T&Cs).

**Journal Entry**:

```
Entry Date: 2026-01-31
Reference: WalletExpiry EXPIRY-001
Description: Event card expiry - forfeited balance

Line Items:
  1. Debit  2500-STORED-VALUE-PAYABLE        400 ZAR  (clear liability)
  2. Credit 4300-REVENUE-FORFEITED-CARDS    400 ZAR  (recognise as revenue)

Result:
- Liability is cleared (no longer owe attendee).
- Platform recognises revenue (attendee forfeited funds).
```

---

#### **Scenario 9: Donation (Free Event)**

**Given**: Free event. Attendee optionally donates ZAR 50 via donation widget.

**Journal Entry**:

```
Entry Date: 2025-01-15
Reference: Donation DONATION-001
Description: Voluntary donation - Free event "Music Festival"

Line Items:
  1. Debit  1000-CASH                         50 ZAR  (donation received)
  2. Credit 4400-DONATION-REVENUE             50 ZAR  (recognise donation)
                      OR
  2. Credit 2500-STORED-VALUE-PAYABLE         50 ZAR  (if NPO: liability, not revenue)

Result (Non-NPO):
- Platform captures ZAR 50 as revenue.

Result (NPO):
- Funds held as liability (part of donations held for NPO purposes).
```

---

#### **Scenario 10: Chargeback (Dispute & Loss)**

**Given**: Customer disputes a ZAR 500 transaction. Chargeback code "1100" issued.  
Reserve: 3% × ZAR 500 = ZAR 15 held for 7 days.

**Journal Entry 1** (Chargeback created, under investigation):

```
Entry Date: 2025-01-25
Reference: Chargeback CBK-001
Description: Chargeback received - Card "1100" unauthorized claim

Line Items:
  1. Debit  5300-RESERVE-ESCROW               15 ZAR  (3% reserve held)
  2. Credit 1000-CASH                         15 ZAR  (held from organiser's expected payout)

Status: :pending_investigation
```

**Journal Entry 2** (Chargeback lost after 7 days):

```
Entry Date: 2025-02-01
Reference: Chargeback CBK-001 resolved
Description: Chargeback lost - funds reversed

Line Items:
  1. Debit  2000-PAYABLE-ORGANIZER-ABC       500 ZAR  (reduce organiser's payable)
  2. Debit  5200-EXPENSE-REFUND-CHARGEBACK    15 ZAR  (loss to platform)
  3. Credit 1000-CASH                        515 ZAR  (funds returned to customer)
  4. Credit 5300-RESERVE-ESCROW               15 ZAR  (release reserve)

Result:
- Organiser's account reduced by ZAR 500 (chargeback loss).
- Platform absorbs ZAR 15 as chargeback fee.
- Customer receives full refund.
```

---

### Fee Models & Ledger Treatment

| Fee Mode              | Customer Pays                | Organiser Pays               | Ledger                                                                                 |
| --------------------- | ---------------------------- | ---------------------------- | -------------------------------------------------------------------------------------- |
| **Client Pays All**   | Platform fee + Processor fee | Nothing                      | Debit Cash (full), Credit Organiser Payable, Credit Platform Fee, Credit Processor Fee |
| **Organiser Absorbs** | Nothing (rare)               | Platform fee + Processor fee | Debit Organiser Payable, Credit Cash (after fees taken)                                |
| **Split Model**       | Processor fee                | Platform fee                 | Debit Cash (ticket + processor), Credit Organiser Payable (net), Credit Platform Fee   |

---

### Multi-Tenancy & Organisation Isolation

**Rule**: Every ledger entry MUST include `organization_id`. Queries MUST filter by organisation.

**Ash Policy Enforcement**:

```elixir
defmodule VoelgoedEvents.Policies.JournalEntryPolicy do
  use Ash.Policy

  policies do
    # Read: users can only see their organisation's entries
    policy action_type(:read) do
      authorize_if expr(organization_id == actor.organization_id)
    end

    # Create: only finance roles can create
    policy action_type(:create) do
      authorize_if expr(actor.role in [:owner, :admin, :finance])
      authorize_if expr(changeset.organization_id == actor.organization_id)
    end

    default_policy :deny
  end
end
```

**Implication**: No cross-organisation queries without explicit admin bypass.

---

### Invariants

1. **Double-Entry Always**: Every financial movement is recorded as balanced debit/credit.
2. **No Orphaned Entries**: Every ledger entry must reference valid resource (order, refund, payout, chargeback, donation).
3. **Immutable Entries**: Once posted, entries cannot be edited. Corrections via reversal entries only.
4. **Account Codes Unique**: Per organisation, globally unique codes.
5. **All Amounts Integers**: No floating-point; cents/satoshis only.
6. **Status Progression**: Unidirectional (initiated → pending → succeeded → refunded).
7. **Payable Can Go Negative**: If refunds > revenue. Blocks future payouts.
8. **Reserve Holds Payouts**: Chargeback reserves block settlements for 7 days.

---

## Lifecycle Flows

### A. Payment Lifecycle: Authorization → Capture → Settlement

**Phase 1: Checkout Creation**

1. User selects seats/tickets, enters payment info.
2. System creates `Checkout` record (status: `:started`).
3. System calculates fees based on PaymentPolicy fee mode.

**Phase 2: Authorization**

1. System calls payment provider API with amount.
2. Provider returns authorization token.
3. `Transaction` created (status: `:initiated` → `:pending`).
4. User redirected to provider payment form.

**Phase 3: Capture / Webhook Confirmation**

1. Provider processes payment.
2. Provider sends webhook: `payment.succeeded` or `payment.failed`.
3. If succeeded:
   - `Transaction.status` → `:succeeded`
   - `Checkout` validates holds still active, creates tickets.
   - **Journal entries posted**: Debit Cash, Credit Organiser Payable, Credit Platform Fee, Credit Processor Fee.
   - Seats marked as sold.
   - Email sent, QR codes generated.

**Phase 4: Settlement (T+1 to T+3)**

1. Payment processor transfers funds to platform's clearing account.
2. Platform reconciles received funds.
3. Settlement confirmed in `Transaction`.

**Phase 5: Payout to Organiser (Daily/Weekly/Event-Based)**

1. Oban cron aggregates all paid orders.
2. Calculates net (revenue − fees − refunds − chargebacks).
3. `Payout` created (status: `:pending`).
4. Finance approves (or auto-approved under threshold).
5. Bank transfer initiated; reference recorded.
6. Payout marked `:completed` once bank confirms.

---

### B. Refund Lifecycle: Request → Approval → Reversal → Transfer

**Phase 1: Refund Requested**

1. Customer or organiser requests refund.
2. `Refund` record created (status: `:pending`).
3. Reason captured (customer cancellation, system error, etc.).

**Phase 2: Approval**

1. Finance or organiser reviews; approves or rejects.
2. If approved, `Refund.status` → `:approved`.

**Phase 3: Ledger Reversal**

1. System creates reversal `JournalEntry`:
   - Reverses organiser payable, processor fee.
   - Platform fee stays (non-refundable by default).
   - Entry ties to original `Transaction` and new `Refund`.
2. Status → `:processing`.

**Phase 4: Refund Transfer**

1. System initiates refund back to payment method.
2. Provider processes (T+1 to T+5 days).
3. Once confirmed, status → `:completed`.

---

### C. Payout Lifecycle: Aggregation → Approval → Settlement

**Phase 1: Daily/Weekly/Event-Based Aggregation**

1. Oban cron runs.
2. Queries all orders with status `:paid` and `:fulfilled` for period.
3. Subtracts refunds, chargebacks, fees.
4. Calculates net payout per organiser.

**Phase 2: Payout Creation**

1. `Payout` records created (status: `:pending`).
2. Linked to all aggregated orders.
3. Organiser notification sent.

**Phase 3: Approval**

1. Platform finance reviews.
2. Verifies organiser has verified bank account (KYC).
3. Approves (manual or auto under threshold).
4. Status → `:approved`.

**Phase 4: Bank Transfer Initiation**

1. Payment processor API called (EFT for South Africa).
2. Bank transfer initiated.
3. Status → `:processing`.

**Phase 5: Settlement Confirmation**

1. Bank confirms receipt.
2. Status → `:completed`.

---

### D. Chargeback Lifecycle: Initiation → Investigation → Resolution

**Phase 1: Chargeback Received**

1. Payment processor sends chargeback notification.
2. `Chargeback` record created (status: `:pending_investigation`).
3. Reserve created: 3% held in escrow for 7 days.
4. Organiser payable temporarily held.

**Phase 2: Investigation**

1. Organiser has evidence deadline (typically 7-10 days).
2. Organiser submits evidence if disputing.
3. Platform evaluates.

**Phase 3: Resolution**

- If **approved** (organiser wins): Reserve released, payouts resume.
- If **lost** (chargeback upheld): Reserve transferred to chargeback loss account. Organiser payable reduced by transaction amount. Payouts blocked until settled.

---

### E. Wallet Lifecycle: Top-Up → Spend → Cashout / Expiry

**Phase 1: Top-Up Initiated**

1. Attendee loads funds (online app, web, or at venue ATM).
2. Amount confirmed; payment processed.
3. `WalletTransaction` created (type: `:topup`, status: `:completed`).
4. Journal entry: Debit Cash, Credit Stored-Value-Payable.
5. Attendee sees updated balance.

**Phase 2: Spend at Vendor**

1. Attendee swipes/taps card at vendor terminal.
2. Terminal checks balance (cached or online).
3. If sufficient balance, deduct and return approval.
4. `WalletTransaction` created (type: `:spend`, vendor logged).
5. Journal entry: Debit Stored-Value-Payable, Credit Vendor-Revenue.

**Phase 3: Cashout Request (Post-Event)**

1. Attendee requests withdrawal of remaining balance.
2. `CashoutRequest` created (status: `:pending`).
3. Finance approves (or auto-approved under threshold).
4. Bank transfer initiated.
5. Status → `:completed`.
6. Journal entry: Debit Stored-Value-Payable, Credit Cash.

**Phase 4: Auto-Cashout (Alternative)**

1. After event ends, if balance ≥ auto_cashout_threshold (e.g., ZAR 10).
2. System automatically approves and processes cashout.
3. Attendee notified.

**Phase 5: Expiry (No Cashout After N Days)**

1. If not cashed out within expiry window (1-2 years).
2. Journal entry: Debit Stored-Value-Payable, Credit Forfeited-Card-Revenue.
3. Platform recognises revenue; liability cleared.

---

### F. Donation Lifecycle (Free Events / NPO)

**Phase 1: Donation Widget Display**

1. On free/NPO event page, donation widget shown.
2. Quick-select amounts or custom input.
3. Donation optional (not required for attendance).

**Phase 2: Donation Received**

1. Attendee enters amount (e.g., ZAR 50).
2. Processes payment.
3. `JournalEntry` created:
   - Non-NPO: Credit 4400-DONATION-REVENUE.
   - NPO: Credit 2500-STORED-VALUE-PAYABLE (held for NPO).

**Phase 3: Reporting**

1. Finance can view donations by event, organisation.
2. Donations separate from ticket revenue (for tax/accounting purposes).

---

## Integration Points

### Payment Provider Integration

**Abstraction Layer**: Behaviour module `Voelgoedevents.Payments.Providers`

**Implemented Providers** (Phase 4+):

- PayStack (South Africa focus)
- Yoco (South Africa focus)
- Stripe (future, global)

**Webhook Handling**:

- Each provider sends webhook on payment confirmation/failure.
- Webhook signature validated (HMAC).
- Idempotency key prevents double-processing.
- Transaction status updated; ledger entries posted atomically.

### Bank Settlement & Payout APIs

**For Organiser Payouts**:

- South Africa EFT (Electronic Funds Transfer): Via partner bank or payment processor.
- API Integration: PayStack, Yoco provide payout APIs.
- Reference tracking: Bank transfer reference stored for reconciliation.

**For Stored-Value Cashouts**:

- Batch daily cashouts for efficiency.
- Alternatively: immediate transfer per attendee (micro-settlement, higher fees).

### Reporting & Financial Compliance

**Finance Dashboards**:

- Real-time revenue, fees, payout status.
- Drill-down by event, organiser, date range.
- Export to CSV/PDF for external review.

**Reconciliation**:

- Daily/weekly reconciliation of ledger vs payment processor settlements.
- Chargeback tracking and reserve management.
- Negative balance notifications (payouts blocked).

**Audit Logging**:

- Every ledger entry linked to source (order, refund, etc.).
- Every manual adjustment logged with user + reason.
- Tamper-evident for compliance (hash chain future).

---

## Scalability & Performance Requirements

### Caching Strategy

**Hot Layer (ETS, per-node)**:

- Payment idempotency keys (webhook dedup).
- Transaction status lookups.
- TTL: 5-15 minutes.

**Warm Layer (Redis, cluster-wide)**:

- Ledger account balances (read-only materialized view).
- Chargeback reserves (under investigation).
- TTL: 30 minutes to 24 hours.

**Cold Layer (PostgreSQL, durable)**:

- All ledger entries (append-only audit trail).
- Transactions, refunds, chargebacks, payouts.
- Retention: permanent per organisation.

### Background Jobs (Oban)

**Payout Settlement**:

- Scheduled by cadence (daily, weekly, monthly, event-based).
- Aggregates organiser payables.
- Creates `Payout` records.

**Chargeback Processing**:

- 7-day reserve TTL expiry and release.
- Evidence deadline notifications.

**Stored-Value Auto-Cashout**:

- Post-event auto-cashout for low balances.
- Batch processing of cashout requests.

**Notification Dispatch**:

- Refund confirmations.
- Payout initiations.
- Chargeback notifications.

### Webhook Idempotency

**MUST** use Redis + ETS for webhook dedup:

- Key: `webhook:payment:{provider_transaction_id}`
- Value: `{status: completed, result: ...}`
- TTL: 24 hours (matches provider retry window).

---

## Policy & Security Requirements

### Multi-Tenancy Enforcement (MUST)

Every resource MUST enforce:

- `organization_id` in all queries.
- Ash.Policy for read/write authorization.
- No cross-organisation data leakage.

### Auditable Extension (Ash-Native)

All ledger resources (Transaction, JournalEntry, Refund, Payout, Chargeback) MUST use:

- `Auditable` extension for immutable change logs.
- `FilterByTenant` preparation for automatic org scoping.

### RBAC (Role-Based Access Control)

**Organiser Admins**:

- View their own ledger account balance.
- View their own payouts, refunds.
- Request refunds (subject to approval).
- Link bank account for payouts.

**Platform Finance**:

- View all organisations' ledgers (admin-only).
- Approve payouts, refunds, chargebacks.
- Override fee policies (super-admin).

**Platform Auditors**:

- Read-only access to all ledger entries.
- Cannot create or modify entries.

---

## MVP vs. Future Phases

### Phase 4-5: Basic Payments & Minimal Ledger

**In MVP**:

1. **Transactions**: PayStack integration, payment status tracking, webhook handling.
2. **Basic Ledger**: Double-entry entries for orders (debit cash, credit organiser payable, credit platform fee).
3. **Refunds**: Full refund only, simple reversal.
4. **Payouts**: Manual payout to organiser (not automated).
5. **No Stored-Value**: Deferred to Phase 6.
6. **No Chargebacks**: Deferred to Phase 6.
7. **No Donations**: Deferred to Phase 6.
8. **No PaymentPolicy**: Deferred to Phase 6 (assume client_pays_all, flat fee).

**Ledger Simplifications**:

- Single currency (ZAR).
- Single organisation (single-tenant MVP, but design for multi-tenant).
- Minimal chart of accounts (cash, revenue, fee, organiser payable).
- No multi-level approval workflows.

---

### Phase 6: Full Financial Ledger & Settlement Engine

**Additions**:

1. **Multi-Tenant Ledger**: Each organisation has isolated chart of accounts.
2. **Automated Payouts**: Daily/weekly scheduled payouts with approval workflow.
3. **Advanced Refunds**: Partial refunds, refund policies, fee handling (non-refundable vs refundable).
4. **Fee Configuration**: PaymentPolicy resource with client-pays, organiser-absorbs, split-model modes.
5. **Stored-Value System**: Full cashless card/wallet flows (top-up, spend, cashout, offline reconciliation).
6. **Chargebacks**: Explicit chargeback resource, reserve management, dispute workflows.
7. **Donations**: Donation widget, ledger accounting, NPO handling.
8. **Reconciliation**: Automated reconciliation of ledger vs. payment processor statements.
9. **Reporting**: Financial dashboards, export, audit trails.
10. **Super-Admin Overrides**: Configuration per organisation for fees, payouts, stored value, donations.

---

## Open Questions Closed by Final Decisions

| Question                                                   | Decision                                                                                                                                                                           |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Should platform or organiser absorb refund processor fees? | **Configurable per PaymentPolicy fee_mode**. Default: non-refundable (platform keeps). Can be set to refundable on per-org basis.                                                  |
| What is the payout schedule?                               | **Configurable per PaymentPolicy**: weekly (default), event-based (T+3), monthly (NPO default), on-demand (trusted orgs).                                                          |
| How long do prepaid balances last?                         | **Configurable per event**: typically 1-2 years post-event. Expired balances auto-void and recognised as revenue per T&Cs.                                                         |
| Does platform take commission on cashless spends?          | **No commission in MVP**. Phase 6: configurable via PaymentPolicy.                                                                                                                 |
| Should MVP support USD/EUR?                                | **No, ZAR-only for MVP**. Ledger design allows future multi-currency (one ledger per currency per org).                                                                            |
| How are organisers represented in ledger?                  | **As creditors via Payable liability account** (2000-PAYABLE-ORGANIZER-{ORG_ID}). Platform maintains single general ledger per organisation, not per-organiser sub-ledgers.        |
| Can refunds result in negative organiser balance?          | **Yes**. If refunds exceed revenue, organiser payable goes negative. Blocks future payouts until settled. Held for next cycle.                                                     |
| How are chargebacks modeled?                               | **Explicit Chargeback resource**. 3% reserve held 7 days. On loss: transferred to chargeback loss account. On win: reserve released.                                               |
| Are donations required for free events?                    | **Optional**. Donation widget optional; NOT required for attendance. Non-NPO: revenue. NPO: liability/held funds.                                                                  |
| Can super-admin override fee policies?                     | **Yes**. Super-admin can set all fields in PaymentPolicy per organisation: fee mode, fee amount, NPO status, payout cadence, donation enable/disable, stored-value enable/disable. |
| How are stored-value cards represented in ledger?          | **As liabilities** (2500-STORED-VALUE-PAYABLE). Aggregate account across all wallets per organisation.                                                                             |
| Can offline terminals cause double-spends?                 | **Yes, mitigated by reconciliation**. Offline terminals use cached balance; reconciliation detects conflicts on sync. Server is source of truth.                                   |
| What is the chargeback reserve calculation?                | **3% of transaction amount, held for 7 days** in 5300-RESERVE-ESCROW. Configurable per PaymentPolicy.                                                                              |

---

## New Resources to Register

The following resources MUST be added to `DOMAIN_MAP.md` and `ai_context_map.md`:

| Resource            | Module                                                    | File Path                                                         | Domain   | Phase | Notes                              |
| ------------------- | --------------------------------------------------------- | ----------------------------------------------------------------- | -------- | ----- | ---------------------------------- |
| `Transaction`       | `Voelgoedevents.Ash.Resources.Payments.Transaction`       | `lib/voelgoedevents/ash/resources/payments/transaction.ex`        | Payments | 4     | Payment attempt lifecycle          |
| `Refund`            | `Voelgoedevents.Ash.Resources.Payments.Refund`            | `lib/voelgoedevents/ash/resources/payments/refund.ex`             | Payments | 4     | Cancellation/reversal              |
| `PaymentMethod`     | `Voelgoedevents.Ash.Resources.Payments.PaymentMethod`     | `lib/voelgoedevents/ash/resources/payments/payment_method.ex`     | Payments | 4     | Tokenized provider reference       |
| `LedgerAccount`     | `Voelgoedevents.Ash.Resources.Payments.LedgerAccount`     | `lib/voelgoedevents/ash/resources/payments/ledger_account.ex`     | Payments | 6     | Chart of accounts                  |
| `JournalEntry`      | `Voelgoedevents.Ash.Resources.Payments.JournalEntry`      | `lib/voelgoedevents/ash/resources/payments/journal_entry.ex`      | Payments | 6     | Immutable ledger record            |
| `Payout`            | `Voelgoedevents.Ash.Resources.Payments.Payout`            | `lib/voelgoedevents/ash/resources/payments/payout.ex`             | Payments | 6     | Settlement to organiser            |
| `PaymentPolicy`     | `Voelgoedevents.Ash.Resources.Payments.PaymentPolicy`     | `lib/voelgoedevents/ash/resources/payments/payment_policy.ex`     | Payments | 6     | Fee & payout configuration         |
| `CashlessWallet`    | `Voelgoedevents.Ash.Resources.Payments.CashlessWallet`    | `lib/voelgoedevents/ash/resources/payments/cashless_wallet.ex`    | Payments | 6     | Prepaid event account              |
| `StoredValueCard`   | `Voelgoedevents.Ash.Resources.Payments.StoredValueCard`   | `lib/voelgoedevents/ash/resources/payments/stored_value_card.ex`  | Payments | 6     | Physical card identifier           |
| `WalletTransaction` | `Voelgoedevents.Ash.Resources.Payments.WalletTransaction` | `lib/voelgoedevents/ash/resources/payments/wallet_transaction.ex` | Payments | 6     | Immutable top-up/spend/cashout log |
| `CashoutRequest`    | `Voelgoedevents.Ash.Resources.Payments.CashoutRequest`    | `lib/voelgoedevents/ash/resources/payments/cashout_request.ex`    | Payments | 6     | Withdrawal request                 |
| `Chargeback`        | `Voelgoedevents.Ash.Resources.Payments.Chargeback`        | `lib/voelgoedevents/ash/resources/payments/chargeback.ex`         | Payments | 6     | Processor reversal & dispute       |

---

## Document Status

**Version**: 2.0 (Extended & Finalized)  
**Last Updated**: December 8, 2025  
**Status**: Canonical Specification for Phase 4 & Phase 6 Implementation  
**Next Review**: After Phase 4 completion (for Phase 6 detailed scoping)

---

## References

### Internal VoelgoedEvents Docs

- `MASTER_BLUEPRINT.md` — Section 6 (Performance Model), Section 7 (Workflows)
- `DOMAIN_MAP.md` — Section 5 (Payments & Ledger)
- `PROJECT_GUIDE.md` — Section 5.5 (Payments Domain)
- `complete_checkout.md` — Full workflow spec for payment processing
- `start_checkout.md` — Checkout session initiation workflow
- `VOELGOEDEVENTS_FINAL_ROADMAP.md` — Phase 4 (Orders, Payments), Phase 6 (Ledger & Settlement)
- `ash-native_metaprogramming.md` — Section 4.B (Double-Entry Validation)
- `11_ash-native_metaprogramming.md` — Auditable extension, FilterByTenant preparation
- `PRODUCT_VISION.md` — Financial integrity as core differentiator
- `02_multi_tenancy.md` — Multi-tenancy enforcement patterns
- `03_caching_and_realtime.md` — Hot/Warm/Cold caching layers
- `06_jobs_and_async.md` — Oban job patterns for background processing
- `09_scaling_and_resilience.md` — Performance targets and reliability

### External References

- **Stripe Ledger Architecture**: https://stripe.com/blog/ledger-stripe-system-for-tracking-and-validating-money-movement
- **Double-Entry Accounting for Engineers**: https://finlego.com/tpost/c2pjjza3k1-designing-a-real-time-ledger-system-with
- **Stored-Value Cards**: https://stripe.com/resources/more/what-is-a-stored-value-card-what-businesses-need-to-know
- **South African NPS Act**: https://www.resbank.co.za/en/home/what-we-do/payments-and-settlements
- **South African E-Money Regulation**: https://www.resbank.co.za/content/dam/sarb/what-we-do/financial-surveillance/general-public/PP2009_01.pdf

---
