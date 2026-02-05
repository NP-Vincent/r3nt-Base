// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Booking
 * @notice Atomic rent obligation tied to a listing.
 */
contract Booking is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    enum PaymentCadence {
        NONE,
        DAILY,
        WEEKLY,
        MONTHLY
    }

    address public platform;
    address public listing;
    address public tenant;
    address public agent;

    uint64 public startDate;
    uint64 public endDate;
    uint32 public declaredSqm;

    uint256 public rentAmount;
    PaymentCadence public cadence;

    uint16 public agentFeeBps;
    uint16 public facilitationFeeBps;

    event BookingInitialized(
        address indexed platform,
        address indexed listing,
        address indexed tenant,
        uint64 startDate,
        uint64 endDate
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address listing_,
        address tenant_,
        address agent_,
        uint64 startDate_,
        uint64 endDate_,
        uint32 declaredSqm_,
        uint256 rentAmount_,
        PaymentCadence cadence_,
        uint16 agentFeeBps_,
        uint16 facilitationFeeBps_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(listing_ != address(0), "listing=0");
        require(tenant_ != address(0), "tenant=0");
        require(startDate_ < endDate_, "dates");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        listing = listing_;
        tenant = tenant_;
        agent = agent_;
        startDate = startDate_;
        endDate = endDate_;
        declaredSqm = declaredSqm_;
        rentAmount = rentAmount_;
        cadence = cadence_;
        agentFeeBps = agentFeeBps_;
        facilitationFeeBps = facilitationFeeBps_;

        emit BookingInitialized(platform_, listing_, tenant_, startDate_, endDate_);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
