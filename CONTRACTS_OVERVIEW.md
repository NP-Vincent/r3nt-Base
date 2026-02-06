# Contracts Overview

This document explains how each contract in the `r3nt Base` protocol is intended to function and how they connect.

## System shape

At a high level, the system separates:
- **Platform-level orchestration** (`Platform`, `EpochManager`, `RentRouter`, `R3ntVault`, optional `BookingRegistry`)
- **Property-level state** (`Listing`, `Booking`, optional `Agent`)
- **Analytics surface** (`SqmAccounting`)

All contracts in this repo are **UUPS upgradeable** and include explicit storage gaps.

## Platform

`Platform` is the central registry/orchestrator contract.

Responsibilities:
- Stores pointers to the core modules (`liquidityVault`, `epochManager`, `rentRouter`, `bookingRegistry`)
- Tracks globally approved agents (`approvedAgents`)
- Stores global fee controls (`protocolFeeBps`, `agentFeeCapBps`)
- Allows owner-controlled updates to module addresses and fee configuration

In practice, this is the root config contract that other contracts can reference.

## R3ntVault

`R3ntVault` is an ERC-4626 vault over an ERC-20 asset (for example USDC).

Responsibilities:
- Accepts deposits/mints shares and handles withdrawals/redeems via ERC-4626 semantics
- Uses upgradeable OpenZeppelin `ERC4626Upgradeable`
- Adds a decimal offset (`_decimalsOffset() -> 6`) for share precision alignment

The vault is where routed rent/cashflow is ultimately custodied.

## RentRouter

`RentRouter` is the payment ingress.

Responsibilities:
- Holds references to `platform`, `liquidityVault`, and `usdc`
- `routePayment(...)` pulls USDC from the payer and transfers it directly to the vault
- Emits `PaymentRouted` to make booking/agent/epoch attribution indexable off-chain

It intentionally remains simple: routing + eventing.

## EpochManager

`EpochManager` tracks time/risk windows for the vault.

Responsibilities:
- Stores `epochDuration` and `capitalLockDuration`
- Lets owner update epoch configuration
- Keeps references to `platform` and `liquidityVault`

This contract defines the temporal structure that can be used for risk tranching/accounting.

## Listing

`Listing` is the canonical on-chain container for one property.

Responsibilities:
- Stores property identity fields (`landlord`, `totalSqm`, `metadataURI`)
- Optionally links a `masterAgent`
- Maintains a list of booking contract addresses associated with this property

It is the parent entity for related bookings.

## Booking

`Booking` represents a single rent obligation tied to a listing.

Responsibilities:
- Stores participants (`tenant`, optional `agent`) and references (`platform`, `listing`)
- Stores term (`startDate`, `endDate`) and economics (`rentAmount`, cadence, fee bps)
- Encodes declared area (`declaredSqm`) for sqm-based analytics/reporting

Each booking is an atomic lease/rental commitment record.

## Agent

`Agent` models an originator/operator role for listings/bookings.

Responsibilities:
- Stores mode (`FACILITATOR` or `MASTER_LEASE`)
- Stores operator address and configurable fee fields
- Anchors to specific `platform` and `listing`

Operationally, this allows distinct agency/master-lease behaviors while keeping listing/booking records explicit.

## BookingRegistry (optional)

`BookingRegistry` is an optional index helper.

Responsibilities:
- Maps listing => booking[]
- Owner can register booking addresses
- External consumers can query bookings per listing

This can complement listing-local booking arrays with a platform-managed index.

## SqmAccounting

`SqmAccounting` is a read-oriented accounting surface.

Responsibilities:
- Stores references to platform modules (`platform`, `epochManager`, `rentRouter`)
- Intended as analytics/reporting integration point, not entitlement/state transition engine

This follows the repo invariant: sqm explains performance, but does not itself define ownership claims.

## Typical flow

1. Deploy/initialize platform modules (`Platform`, `R3ntVault`, `EpochManager`, `RentRouter`), wire addresses.
2. Configure protocol/agent fee limits and approved agents in `Platform`.
3. Create a `Listing` for a property and attach bookings (`Booking`) over time.
4. Optionally attach an `Agent` (facilitator or master lease).
5. Tenant/payer approves USDC to `RentRouter`; router transfers funds to `R3ntVault` and emits attribution event.
6. Off-chain indexers and/or `SqmAccounting`-style read models compute performance views by sqm/epoch.
