// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title Listing
 * @notice Canonical property container for a single property.
 */
contract Listing is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    address public platform;
    address public landlord;
    address public masterAgent;

    uint32 public totalSqm;
    string public metadataURI;

    address[] private _bookings;

    event ListingInitialized(address indexed platform, address indexed landlord, uint32 totalSqm);
    event MasterAgentUpdated(address indexed previousAgent, address indexed newAgent);
    event BookingRegistered(address indexed booking);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address platform_,
        address landlord_,
        uint32 totalSqm_,
        string calldata metadataURI_
    ) external initializer {
        require(owner_ != address(0), "owner=0");
        require(platform_ != address(0), "platform=0");
        require(landlord_ != address(0), "landlord=0");

        __Ownable_init(owner_);
        __UUPSUpgradeable_init();

        platform = platform_;
        landlord = landlord_;
        totalSqm = totalSqm_;
        metadataURI = metadataURI_;

        emit ListingInitialized(platform_, landlord_, totalSqm_);
    }

    function setMasterAgent(address newAgent) external onlyOwner {
        address previous = masterAgent;
        masterAgent = newAgent;
        emit MasterAgentUpdated(previous, newAgent);
    }

    function registerBooking(address booking) external onlyOwner {
        require(booking != address(0), "booking=0");
        _bookings.push(booking);
        emit BookingRegistered(booking);
    }

    function bookings() external view returns (address[] memory) {
        return _bookings;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[45] private __gap;
}
