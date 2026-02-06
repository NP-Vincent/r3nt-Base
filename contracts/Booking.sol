// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IPlatformConfig {
    function rentRouter() external view returns (address);
}

interface IRentRouter {
    function routePayment(
        address booking,
        address agent,
        bytes32 epochId,
        uint256 amount
    ) external;
}

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

    enum Status {
        ACTIVE,
        COMPLETED,
        DEFAULTED,
        CANCELLED
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

    Status public status;
    uint256 public totalRent;
    uint256 public paidRent;
    uint256 public installmentSize;

    uint64 public cadenceSeconds;
    uint64 public cadenceWindowStart;
    uint64 public cadenceWindowEnd;
    uint64 public gracePeriodSeconds;
    uint64 public defaultEligibleAt;
    uint32 public installmentCount;
    uint32 public installmentPaidCount;

    uint16 public agentFeeBps;
    uint16 public facilitationFeeBps;

    event BookingInitialized(
        address indexed platform,
        address indexed listing,
        address indexed tenant,
        uint64 startDate,
        uint64 endDate
    );
    event RentPaid(
        address indexed payer,
        bytes32 indexed epochId,
        uint256 amount,
        uint256 paidRent,
        uint256 remainingRent
    );
    event StatusTransition(Status indexed previousStatus, Status indexed newStatus, uint64 at);
    event CadenceCheckpointUpdated(
        uint64 indexed windowStart,
        uint64 indexed windowEnd,
        uint64 defaultEligibleAt,
        uint32 installmentPaidCount
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

        status = Status.ACTIVE;
        totalRent = rentAmount_;
        paidRent = 0;

        cadenceSeconds = _cadenceSeconds(cadence_);
        gracePeriodSeconds = _graceSeconds(cadence_);
        installmentCount = _computeInstallmentCount(startDate_, endDate_, cadenceSeconds);
        installmentSize = installmentCount == 0 ? totalRent : (totalRent + installmentCount - 1) / installmentCount;

        cadenceWindowStart = startDate_;
        cadenceWindowEnd = _initialWindowEnd(startDate_, endDate_, cadenceSeconds);
        defaultEligibleAt = _addGrace(cadenceWindowEnd, gracePeriodSeconds);

        emit BookingInitialized(platform_, listing_, tenant_, startDate_, endDate_);
        emit StatusTransition(Status.ACTIVE, Status.ACTIVE, uint64(block.timestamp));
        emit CadenceCheckpointUpdated(
            cadenceWindowStart,
            cadenceWindowEnd,
            defaultEligibleAt,
            installmentPaidCount
        );
    }

    function payRent(uint256 amount, bytes32 epochId) external {
        require(status == Status.ACTIVE, "status");
        require(msg.sender == tenant || msg.sender == agent, "payer");
        require(amount > 0, "amount=0");

        uint256 remaining = totalRent - paidRent;
        require(amount <= remaining, "overpay");
        _enforceCadenceWindow();

        paidRent += amount;
        if (cadenceSeconds > 0 && installmentPaidCount < installmentCount) {
            installmentPaidCount += 1;
            _advanceCadenceWindow();
        }

        IRentRouter(_rentRouter()).routePayment(address(this), agent, epochId, amount);

        emit RentPaid(msg.sender, epochId, amount, paidRent, totalRent - paidRent);

        if (paidRent == totalRent) {
            _complete();
        }
    }

    function markDefault() external {
        require(status == Status.ACTIVE, "status");
        require(paidRent < totalRent, "settled");
        require(block.timestamp > defaultEligibleAt, "grace");

        _setStatus(Status.DEFAULTED);
    }

    function complete() external {
        require(status == Status.ACTIVE, "status");
        require(paidRent == totalRent, "unsettled");

        _complete();
    }

    function cancel() external onlyOwner {
        require(status == Status.ACTIVE, "status");
        require(paidRent == 0, "paid");
        _setStatus(Status.CANCELLED);
    }

    function _complete() internal {
        _setStatus(Status.COMPLETED);
    }

    function _setStatus(Status newStatus) internal {
        Status previous = status;
        status = newStatus;
        emit StatusTransition(previous, newStatus, uint64(block.timestamp));
    }

    function _rentRouter() internal view returns (address) {
        return IPlatformConfig(platform).rentRouter();
    }

    function _enforceCadenceWindow() internal view {
        if (cadenceSeconds == 0) {
            require(block.timestamp >= startDate && block.timestamp <= endDate, "window");
            return;
        }

        require(block.timestamp >= cadenceWindowStart, "too-early");
        require(block.timestamp <= defaultEligibleAt, "late");
    }

    function _advanceCadenceWindow() internal {
        if (cadenceSeconds == 0) {
            return;
        }

        uint64 nextStart = cadenceWindowEnd;
        uint64 nextEnd = nextStart + cadenceSeconds;
        if (nextEnd > endDate) {
            nextEnd = endDate;
        }

        cadenceWindowStart = nextStart;
        cadenceWindowEnd = nextEnd;
        defaultEligibleAt = _addGrace(nextEnd, gracePeriodSeconds);

        emit CadenceCheckpointUpdated(cadenceWindowStart, cadenceWindowEnd, defaultEligibleAt, installmentPaidCount);
    }

    function _cadenceSeconds(PaymentCadence cadence_) internal pure returns (uint64) {
        if (cadence_ == PaymentCadence.DAILY) return 1 days;
        if (cadence_ == PaymentCadence.WEEKLY) return 7 days;
        if (cadence_ == PaymentCadence.MONTHLY) return 30 days;
        return 0;
    }

    function _graceSeconds(PaymentCadence cadence_) internal pure returns (uint64) {
        if (cadence_ == PaymentCadence.DAILY) return 1 days;
        if (cadence_ == PaymentCadence.WEEKLY) return 2 days;
        if (cadence_ == PaymentCadence.MONTHLY) return 5 days;
        return 0;
    }

    function _computeInstallmentCount(
        uint64 startDate_,
        uint64 endDate_,
        uint64 cadenceSeconds_
    ) internal pure returns (uint32) {
        if (cadenceSeconds_ == 0) {
            return 1;
        }

        uint256 duration = endDate_ - startDate_;
        uint256 count = (duration + cadenceSeconds_ - 1) / cadenceSeconds_;
        if (count == 0) {
            count = 1;
        }
        return uint32(count);
    }

    function _initialWindowEnd(
        uint64 startDate_,
        uint64 endDate_,
        uint64 cadenceSeconds_
    ) internal pure returns (uint64) {
        if (cadenceSeconds_ == 0) {
            return endDate_;
        }

        uint64 firstWindowEnd = startDate_ + cadenceSeconds_;
        return firstWindowEnd > endDate_ ? endDate_ : firstWindowEnd;
    }

    function _addGrace(uint64 cadenceWindowEnd_, uint64 graceSeconds_) internal pure returns (uint64) {
        return cadenceWindowEnd_ + graceSeconds_;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[39] private __gap;
}
