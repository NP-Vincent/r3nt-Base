// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Agent
 * @notice Originator/operator for listings and bookings.
 */
contract Agent is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    enum Mode {
        NONE,
        FACILITATOR,
        MASTER_LEASE
    }

    address public platform;
    address public listing;
    address public operator;

    Mode public mode;
    uint16 public commissionBps;
    uint16 public facilitationFeeBps;

    event AgentInitialized(address indexed platform, address indexed listing, address indexed operator, Mode mode);
    event OperatorUpdated(address indexed previousOperator, address indexed newOperator);
    event FeesUpdated(uint16 commissionBps, uint16 facilitationFeeBps);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address listing_,
        address operator_,
        Mode mode_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(listing_ != address(0), "listing=0");
        require(operator_ != address(0), "operator=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        listing = listing_;
        operator = operator_;
        mode = mode_;

        emit AgentInitialized(platform_, listing_, operator_, mode_);
    }

    function setOperator(address newOperator) external onlyOwner {
        require(newOperator != address(0), "operator=0");
        address previous = operator;
        operator = newOperator;
        emit OperatorUpdated(previous, newOperator);
    }

    function setFees(uint16 commissionBps_, uint16 facilitationFeeBps_) external onlyOwner {
        commissionBps = commissionBps_;
        facilitationFeeBps = facilitationFeeBps_;
        emit FeesUpdated(commissionBps_, facilitationFeeBps_);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
