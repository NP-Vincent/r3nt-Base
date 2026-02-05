// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/**
 * @title R3ntVault
 * @notice UUPS-upgradeable ERC-4626 liquidity vault for the r3nt protocol.
 */
contract R3ntVault is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC4626Upgradeable {
    uint8 private constant DECIMALS_OFFSET = 6;

    event VaultInitialized(address indexed owner, address indexed asset, string name, string symbol);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        IERC20Upgradeable asset_,
        string calldata name_,
        string calldata symbol_
    ) external initializer {
        require(owner_ != address(0), "owner=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        __ERC20_init(name_, symbol_);
        __ERC4626_init(asset_);

        emit VaultInitialized(owner_, address(asset_), name_, symbol_);
    }

    function _decimalsOffset() internal pure override returns (uint8) {
        return DECIMALS_OFFSET;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[44] private __gap;
}
