// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IListingCapacity {
    function totalSqm() external view returns (uint32);
}

/**
 * @title BookingRegistry
 * @notice Authoritative reservation registry by listing and booking window.
 */
contract BookingRegistry is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    struct Reservation {
        uint64 startDate;
        uint64 endDate;
        uint32 declaredSqm;
        address booking;
        bool active;
    }

    // Deprecated index retained for upgrade-safe layout compatibility.
    mapping(address => address[]) private _bookingsByListing;

    address public bookingFactory;
    mapping(address => bool) public authorizedBookingContracts;
    mapping(address => mapping(bytes32 => address)) private _reservationOwnerByListingAndInterval;
    mapping(address => mapping(bytes32 => uint32)) private _reservedSqmByListingAndInterval;
    mapping(address => Reservation[]) private _reservationsByListing;

    event BookingRegistryInitialized(address indexed owner);
    event BookingFactoryUpdated(address indexed previousFactory, address indexed newFactory);
    event BookingAuthorizationUpdated(address indexed booking, bool authorized);
    event ReservationReserved(
        address indexed listing,
        uint64 startDate,
        uint64 endDate,
        uint32 declaredSqm,
        address indexed booking,
        bytes32 intervalKey
    );
    event ReservationReleased(
        address indexed listing,
        uint64 startDate,
        uint64 endDate,
        address indexed booking,
        bytes32 intervalKey
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyAuthorizedMutator() {
        require(msg.sender == bookingFactory || authorizedBookingContracts[msg.sender], "not authorized");
        _;
    }

    function initialize(address owner_) external initializer {
        require(owner_ != address(0), "owner=0");
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
        emit BookingRegistryInitialized(owner_);
    }

    function setBookingFactory(address newFactory) external onlyOwner {
        address previousFactory = bookingFactory;
        bookingFactory = newFactory;
        emit BookingFactoryUpdated(previousFactory, newFactory);
    }

    function setBookingAuthorization(address booking, bool authorized) external onlyOwner {
        require(booking != address(0), "booking=0");
        authorizedBookingContracts[booking] = authorized;
        emit BookingAuthorizationUpdated(booking, authorized);
    }

    function reserve(
        address listing,
        uint64 startDate,
        uint64 endDate,
        uint32 declaredSqm,
        address booking
    ) external onlyAuthorizedMutator {
        require(listing != address(0), "listing=0");
        require(booking != address(0), "booking=0");
        require(startDate < endDate, "dates");
        require(declaredSqm > 0, "sqm=0");
        if (msg.sender != bookingFactory) {
            require(msg.sender == booking, "caller!=booking");
        }

        bytes32 intervalKey = _intervalKey(startDate, endDate);
        require(_reservationOwnerByListingAndInterval[listing][intervalKey] == address(0), "interval occupied");

        uint32 listingCapacity = IListingCapacity(listing).totalSqm();
        require(listingCapacity > 0, "capacity=0");

        uint256 overlappingSqm = _overlappingReservedSqm(listing, startDate, endDate);
        require(overlappingSqm + declaredSqm <= listingCapacity, "capacity breach");

        _reservationOwnerByListingAndInterval[listing][intervalKey] = booking;
        _reservedSqmByListingAndInterval[listing][intervalKey] = declaredSqm;
        _reservationsByListing[listing].push(
            Reservation({
                startDate: startDate,
                endDate: endDate,
                declaredSqm: declaredSqm,
                booking: booking,
                active: true
            })
        );

        emit ReservationReserved(listing, startDate, endDate, declaredSqm, booking, intervalKey);
    }

    function release(address listing, uint64 startDate, uint64 endDate, address booking) external onlyAuthorizedMutator {
        require(listing != address(0), "listing=0");
        require(booking != address(0), "booking=0");
        require(startDate < endDate, "dates");
        if (msg.sender != bookingFactory) {
            require(msg.sender == booking, "caller!=booking");
        }

        bytes32 intervalKey = _intervalKey(startDate, endDate);
        require(_reservationOwnerByListingAndInterval[listing][intervalKey] == booking, "reservation owner");

        _reservationOwnerByListingAndInterval[listing][intervalKey] = address(0);
        _reservedSqmByListingAndInterval[listing][intervalKey] = 0;
        _deactivateReservation(listing, startDate, endDate, booking);

        emit ReservationReleased(listing, startDate, endDate, booking, intervalKey);
    }

    function reservationOwner(address listing, uint64 startDate, uint64 endDate) external view returns (address) {
        return _reservationOwnerByListingAndInterval[listing][_intervalKey(startDate, endDate)];
    }

    function reservationSqm(address listing, uint64 startDate, uint64 endDate) external view returns (uint32) {
        return _reservedSqmByListingAndInterval[listing][_intervalKey(startDate, endDate)];
    }

    function bookingsForListing(address listing) external view returns (address[] memory) {
        return _bookingsByListing[listing];
    }

    function _overlappingReservedSqm(
        address listing,
        uint64 startDate,
        uint64 endDate
    ) internal view returns (uint256 overlappingSqm) {
        Reservation[] storage reservations = _reservationsByListing[listing];
        uint256 length = reservations.length;
        for (uint256 i; i < length; ++i) {
            Reservation storage current = reservations[i];
            if (!current.active) {
                continue;
            }
            if (_overlaps(startDate, endDate, current.startDate, current.endDate)) {
                overlappingSqm += current.declaredSqm;
            }
        }
    }

    function _deactivateReservation(address listing, uint64 startDate, uint64 endDate, address booking) internal {
        Reservation[] storage reservations = _reservationsByListing[listing];
        uint256 length = reservations.length;
        for (uint256 i = length; i > 0; --i) {
            Reservation storage current = reservations[i - 1];
            if (
                current.active &&
                current.startDate == startDate &&
                current.endDate == endDate &&
                current.booking == booking
            ) {
                current.active = false;
                return;
            }
        }
        revert("reservation missing");
    }

    function _intervalKey(uint64 startDate, uint64 endDate) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(startDate, endDate));
    }

    function _overlaps(
        uint64 startA,
        uint64 endA,
        uint64 startB,
        uint64 endB
    ) internal pure returns (bool) {
        return startA < endB && startB < endA;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    uint256[40] private __gap;
}
