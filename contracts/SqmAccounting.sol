// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title SqmAccounting
 * @notice Read-only accounting surface for sqm analytics.
 */
contract SqmAccounting is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public platform;
    address public epochManager;
    address public rentRouter;

    event SqmAccountingInitialized(
        address indexed owner,
        address indexed platform,
        address indexed epochManager,
        address rentRouter
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address epochManager_,
        address rentRouter_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(epochManager_ != address(0), "epoch=0");
        require(rentRouter_ != address(0), "router=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        epochManager = epochManager_;
        rentRouter = rentRouter_;

        emit SqmAccountingInitialized(owner_, platform_, epochManager_, rentRouter_);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
