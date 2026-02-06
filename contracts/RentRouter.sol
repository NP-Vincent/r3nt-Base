// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IPlatformRouterConfig {
    function bookingRegistry() external view returns (address);
}

interface IBookingRegistryAuth {
    function authorizedBookingContracts(address booking) external view returns (bool);
}

/**
 * @title RentRouter
 * @notice Ingress router for rent and agent payments into the vault.
 */
contract RentRouter is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public platform;
    address public liquidityVault;
    address public usdc;
    bool public enforceBookingRegistryAuthorization;

    error ZeroAddressNotAllowed();
    error UnauthorizedBookingCaller(address caller, address booking);
    error BookingNotAuthorized(address booking, address registry);

    event RentRouterInitialized(
        address indexed owner,
        address indexed platform,
        address indexed liquidityVault,
        address usdc,
        bool enforceBookingRegistryAuthorization
    );
    event LiquidityVaultUpdated(address indexed previousVault, address indexed newVault);
    event BookingRegistryAuthorizationUpdated(bool enabled);
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
        if (owner_ == address(0) || platform_ == address(0) || liquidityVault_ == address(0) || usdc_ == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        liquidityVault = liquidityVault_;
        usdc = usdc_;
        enforceBookingRegistryAuthorization = true;

        emit RentRouterInitialized(owner_, platform_, liquidityVault_, usdc_, true);
    }

    function setLiquidityVault(address newVault) external onlyOwner {
        if (newVault == address(0)) {
            revert ZeroAddressNotAllowed();
        }

        address previous = liquidityVault;
        liquidityVault = newVault;
        emit LiquidityVaultUpdated(previous, newVault);
    }

    function setBookingRegistryAuthorization(bool enabled) external onlyOwner {
        enforceBookingRegistryAuthorization = enabled;
        emit BookingRegistryAuthorizationUpdated(enabled);
    }

    function routePayment(
        address booking,
        address agent,
        bytes32 epochId,
        uint256 amount
    ) external {
        if (msg.sender != booking) {
            revert UnauthorizedBookingCaller(msg.sender, booking);
        }

        if (enforceBookingRegistryAuthorization) {
            address registry = IPlatformRouterConfig(platform).bookingRegistry();
            if (registry != address(0) && !IBookingRegistryAuth(registry).authorizedBookingContracts(booking)) {
                revert BookingNotAuthorized(booking, registry);
            }
        }

        require(amount > 0, "amount=0");
        IERC20Upgradeable(usdc).safeTransferFrom(msg.sender, liquidityVault, amount);
        emit PaymentRouted(msg.sender, booking, agent, epochId, amount);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[44] private __gap;
}
