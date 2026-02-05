# r3nt Base Contracts

## Contract Structure

- Platform
  - LiquidityVault (R3ntVault, ERC-4626)
  - EpochManager
  - RentRouter
  - Approved Agents
  - BookingRegistry (optional)

- Listing (Property)
  - Booking (1..many)
  - Agent (optional master lease)

- SqmAccounting (read-only)

## Relationship Graph

Platform
 ├─ EpochManager ── R3ntVault (ERC-4626)
 ├─ RentRouter ───▶ R3ntVault
 ├─ Agent
 └─ BookingRegistry (optional)

Listing (Property)
 ├─ Booking A (LTR)
 ├─ Booking B (LTR)
 └─ Agent (Master Lease)
      ├─ Booking C (STR)
      ├─ Booking D (STR)
      └─ Booking E (STR)

SqmAccounting (read-only)

## Invariant

- Listings organise properties
- Bookings create obligations
- Agents originate and operate
- Vault prices and aggregates cash flows
- EpochManager structures risk
- sqm explains performance, not entitlement
