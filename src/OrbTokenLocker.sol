// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {OwnableUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import {ECDSA} from "../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import {OrbInvocationRegistry} from "./OrbInvocationRegistry.sol";
import {IKeeperDiscovery} from "./keeper-discovery/IKeeperDiscovery.sol";

/// @title   Orb Token Locker
/// @author  Jonas Lekevicius
/// @notice  The Orb is issued by a Creator: the user who swore an Orb Oath together with a date until which the Oath
///          will be honored. The Creator can list the Orb for sale at a fixed price, or run an auction for it. The user
///          acquiring the Orb is known as the Keeper. The Keeper always has an Orb sale price set and is paying
///          Harberger tax based on their set price and a tax rate set by the Creator. This tax is accounted for per
///          second, and the Keeper must have enough funds on this contract to cover their ownership; otherwise the Orb
///          is re-auctioned, delivering most of the auction proceeds to the previous Keeper. The Orb also has a
///          cooldown that allows the Keeper to invoke the Orb — ask the Creator a question and receive their response,
///          based on conditions set in the Orb Oath. Invocation and response hashes and timestamps are tracked in an
///          Orb Invocation Registry.
/// @dev     Does not support ERC-721 interface.
/// @custom:security-contact security@orb.land
contract OrbTokenLocker is OwnableUpgradeable, UUPSUpgradeable {
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  STRUCTS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    struct ERC721Token {
        address contractAddress;
        uint256 tokenId;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  EVENTS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Orb Parameter Events
    event TokenLocking(
        uint256 indexed orbId, address indexed tokenContract, uint256 indexed tokenId, uint256 lockedUntil
    );
    event TokenLockedUntilUpdate(uint256 indexed orbId, uint256 previousLockedUntil, uint256 indexed newLockedUntil);

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  ERRORS
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Orb Parameter Errors
    error LockedUntilNotDecreasable();
    error TokenStillLocked();

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  STORAGE
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // CONSTANTS

    /// Orb version. Value: 1.
    uint256 private constant _VERSION = 1;

    // STATE

    /// Address of the `OrbPond` that deployed this Orb. Pond manages permitted upgrades and provides Orb Invocation
    /// Registry address.
    address public registry;
    /// Orb Land signing authority. Used to verify Orb creation authorization.

    /// Locked ERC-721 token. Orb creator can lock an ERC-721 token in the Orb, guaranteeing timely responses.
    mapping(uint256 orbId => ERC721Token) public lockedToken;
    /// Honored Until: timestamp until which the Orb Oath is honored for the keeper.
    mapping(uint256 orbId => uint256 lockedUntil) public lockedUntil;

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  INITIALIZER AND INTERFACE SUPPORT
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initalize(address registry_, address signingAuthority_) public initializer {
        __Ownable_init(_msgSender());
        __UUPSUpgradeable_init();

        registry = registry_;
        signingAuthority = signingAuthority_;
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  FUNCTIONS: TOKEN LOCKING
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice  Allows re-swearing of the Orb Oath and set a new `honoredUntil` date. This function can only be called
    ///          by the Orb creator when the Orb is in their control. With `swearOath()`, `honoredUntil` date can be
    ///          decreased, unlike with the `extendHonoredUntil()` function.
    /// @dev     Emits `OathSwearing`.
    ///          V2 changes to allow re-swearing even during Keeper control, if Oath has expired, and moves
    ///          `responsePeriod` setting to `setInvocationParameters()`.
    /// @param   oathHash           Hash of the Oath taken to create the Orb.
    /// @param   newHonoredUntil    Date until which the Orb creator will honor the Oath for the Orb keeper.
    function lockToken(uint256 orbId, bytes32 oathHash, uint256 newHonoredUntil)
        external
        virtual
        onlyCreator
        onlyCreatorControlled
    {
        honoredUntil = newHonoredUntil;
        emit OathSwearing(oathHash, newHonoredUntil);
    }

    /// @notice  Allows the Orb creator to extend the `honoredUntil` date. This function can be called by the Orb
    ///          creator anytime and only allows extending the `honoredUntil` date.
    /// @dev     Emits `HonoredUntilUpdate`.
    /// @param   newHonoredUntil  Date until which the Orb creator will honor the Oath for the Orb keeper. Must be
    ///                           greater than the current `honoredUntil` date.
    function extendLockedUntil(uint256 orbId, uint256 newHonoredUntil) external virtual onlyCreator {
        if (newHonoredUntil < honoredUntil) {
            revert HonoredUntilNotDecreasable();
        }
        uint256 previousHonoredUntil = honoredUntil;
        honoredUntil = newHonoredUntil;
        emit HonoredUntilUpdate(previousHonoredUntil, newHonoredUntil);
    }

    function retrieveToken(uint256 orbId) external virtual onlyCreator(orbId) {
        ERC721Token memory token = lockedToken[orbId];
        lockedToken[orbId] = ERC721Token(address(0), 0);
        emit TokenLocking(orbId, token.contractAddress, token.tokenId, 0);
    }

    function claimToken(uint256 orbId) external virtual onlyKeeperSolvent(orbId) onlyKeeper(orbId) {
        ERC721Token memory token = lockedToken[orbId];
        lockedToken[orbId] = ERC721Token(address(0), 0);
        emit TokenLocking(orbId, token.contractAddress, token.tokenId, 0);
        IERC721(token.contractAddress).safeTransferFrom(address(this), to, token.tokenId);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //  FUNCTIONS: UPGRADING
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice  Returns the version of the Orb. Internal constant `_VERSION` will be increased with each upgrade.
    /// @return  orbVersion  Version of the Orb.
    function version() public pure virtual returns (uint256 orbVersion) {
        return _VERSION;
    }
}

// TODOs:
// - everything about token locking
// - indicate if discovery is initial or rediscovery
// - discovery running check
// - admin, upgrade functions
// - expose is creator controlled logic
// - establish is deadline missed logic
// - documentation
//   - first, for myself: to understand when all actions can be taken
//   - particularly token and settings related
