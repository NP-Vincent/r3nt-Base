// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Platform
 * @notice Global orchestrator for the r3nt protocol.
 */
contract Platform is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint16 public constant BPS_DENOMINATOR = 10_000;

    address public liquidityVault;
    address public epochManager;
    address public rentRouter;
    address public bookingRegistry;

    mapping(address => bool) public approvedAgents;

    uint16 public protocolFeeBps;
    uint16 public agentFeeCapBps;

    event PlatformInitialized(
        address indexed owner,
        address indexed liquidityVault,
        address indexed epochManager,
        address rentRouter
    );
    event LiquidityVaultUpdated(address indexed previousVault, address indexed newVault);
    event EpochManagerUpdated(address indexed previousManager, address indexed newManager);
    event RentRouterUpdated(address indexed previousRouter, address indexed newRouter);
    event BookingRegistryUpdated(address indexed previousRegistry, address indexed newRegistry);
    event AgentApprovalUpdated(address indexed agent, bool approved);
    event FeesUpdated(uint16 protocolFeeBps, uint16 agentFeeCapBps);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address liquidityVault_,
        address epochManager_,
        address rentRouter_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        liquidityVault = liquidityVault_;
        epochManager = epochManager_;
        rentRouter = rentRouter_;

        emit PlatformInitialized(owner_, liquidityVault_, epochManager_, rentRouter_);
    }

    function setLiquidityVault(address newVault) external onlyOwner {
        address previous = liquidityVault;
        liquidityVault = newVault;
        emit LiquidityVaultUpdated(previous, newVault);
    }

    function setEpochManager(address newManager) external onlyOwner {
        address previous = epochManager;
        epochManager = newManager;
        emit EpochManagerUpdated(previous, newManager);
    }

    function setRentRouter(address newRouter) external onlyOwner {
        address previous = rentRouter;
        rentRouter = newRouter;
        emit RentRouterUpdated(previous, newRouter);
    }

    function setBookingRegistry(address newRegistry) external onlyOwner {
        address previous = bookingRegistry;
        bookingRegistry = newRegistry;
        emit BookingRegistryUpdated(previous, newRegistry);
    }

    function setAgentApproval(address agent, bool approved) external onlyOwner {
        approvedAgents[agent] = approved;
        emit AgentApprovalUpdated(agent, approved);
    }

    function setFees(uint16 protocolFeeBps_, uint16 agentFeeCapBps_) external onlyOwner {
        require(protocolFeeBps_ <= BPS_DENOMINATOR, "protocol fee");
        require(agentFeeCapBps_ <= BPS_DENOMINATOR, "agent fee");
        protocolFeeBps = protocolFeeBps_;
        agentFeeCapBps = agentFeeCapBps_;
        emit FeesUpdated(protocolFeeBps_, agentFeeCapBps_);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
