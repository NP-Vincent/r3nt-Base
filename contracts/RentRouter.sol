// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title RentRouter
 * @notice Ingress router for rent and agent payments into the vault.
 */
contract RentRouter is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public platform;
    address public liquidityVault;
    address public usdc;

    event RentRouterInitialized(
        address indexed owner,
        address indexed platform,
        address indexed liquidityVault,
        address usdc
    );
    event LiquidityVaultUpdated(address indexed previousVault, address indexed newVault);
    event PaymentRouted(
        address indexed payer,
        address indexed booking,
        address indexed agent,
        bytes32 epochId,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address liquidityVault_,
        address usdc_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(liquidityVault_ != address(0), "vault=0");
        require(usdc_ != address(0), "usdc=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        liquidityVault = liquidityVault_;
        usdc = usdc_;

        emit RentRouterInitialized(owner_, platform_, liquidityVault_, usdc_);
    }

    function setLiquidityVault(address newVault) external onlyOwner {
        address previous = liquidityVault;
        liquidityVault = newVault;
        emit LiquidityVaultUpdated(previous, newVault);
    }

    function routePayment(
        address booking,
        address agent,
        bytes32 epochId,
        uint256 amount
    ) external {
        require(amount > 0, "amount=0");
        IERC20Upgradeable(usdc).safeTransferFrom(msg.sender, liquidityVault, amount);
        emit PaymentRouted(msg.sender, booking, agent, epochId, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
