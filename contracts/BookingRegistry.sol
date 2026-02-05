// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title BookingRegistry
 * @notice Optional registry for tracking bookings by listing.
 */
contract BookingRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    mapping(address => address[]) private _bookingsByListing;

    event BookingRegistryInitialized(address indexed owner);
    event BookingRegistered(address indexed listing, address indexed booking);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_) external initializer {
        require(owner_ != address(0), "owner=0");
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        emit BookingRegistryInitialized(owner_);
    }

    function registerBooking(address listing, address booking) external onlyOwner {
        require(listing != address(0), "listing=0");
        require(booking != address(0), "booking=0");
        _bookingsByListing[listing].push(booking);
        emit BookingRegistered(listing, booking);
    }

    function bookingsForListing(address listing) external view returns (address[] memory) {
        return _bookingsByListing[listing];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
