// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title EpochManager
 * @notice Risk, time, and tranche coordination for the vault.
 */
contract EpochManager is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public platform;
    address public liquidityVault;

    uint64 public epochDuration;
    uint64 public capitalLockDuration;

    event EpochManagerInitialized(
        address indexed owner,
        address indexed platform,
        address indexed liquidityVault
    );
    event EpochConfigUpdated(uint64 epochDuration, uint64 capitalLockDuration);
    event LiquidityVaultUpdated(address indexed previousVault, address indexed newVault);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address liquidityVault_,
        uint64 epochDuration_,
        uint64 capitalLockDuration_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(liquidityVault_ != address(0), "vault=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        liquidityVault = liquidityVault_;
        epochDuration = epochDuration_;
        capitalLockDuration = capitalLockDuration_;

        emit EpochManagerInitialized(owner_, platform_, liquidityVault_);
    }

    function setEpochConfig(uint64 epochDuration_, uint64 capitalLockDuration_) external onlyOwner {
        epochDuration = epochDuration_;
        capitalLockDuration = capitalLockDuration_;
        emit EpochConfigUpdated(epochDuration_, capitalLockDuration_);
    }

    function setLiquidityVault(address newVault) external onlyOwner {
        address previous = liquidityVault;
        liquidityVault = newVault;
        emit LiquidityVaultUpdated(previous, newVault);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
