// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @title StandardERC4626
/// @notice Reference ERC-4626 vault implementation following OpenZeppelin's standard behavior.
/// @dev Uses an ERC-4626-compliant vault with a virtual share/asset offset to mitigate
///      inflation attacks per the ERC-4626 guidelines.
contract StandardERC4626 is ERC20, ERC4626 {
    uint8 private constant _DECIMALS_OFFSET = 6;

    /// @param asset_ The underlying asset token to be accepted by the vault.
    /// @param name_ The name of the vault share token.
    /// @param symbol_ The symbol of the vault share token.
    constructor(IERC20 asset_, string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC4626(asset_)
    {}

    /// @notice Offset used to increase share precision and reduce rounding risk on small deposits.
    /// @dev See ERC-4626 guidelines on virtual shares/assets to mitigate inflation attacks.
    function _decimalsOffset() internal pure override returns (uint8) {
        return _DECIMALS_OFFSET;
    }
}
