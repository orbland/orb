// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {EnglishAuctionAllocation} from "../allocation/EnglishAuctionAllocation.sol";

/// @title   English Auction Allocation Test Upgrade
/// @dev     Test Upgrade adds a new storage variable `number`, settable with `setNumber`
contract EnglishAuctionAllocationTestUpgrade is EnglishAuctionAllocation {
    /// Orbs version.
    uint256 private constant _VERSION = 100;

    /// Testing new storage variable in upgrade. It's a number!
    uint256 public number;

    /// @notice  Re-initializes the contract after upgrade, sets initial number value
    /// @param   number_    New number value
    function initializeTestUpgrade(uint256 number_) public reinitializer(100) {
        number = number_;
    }

    /// @notice  Allows anyone to record a number!
    /// @param   newNumber  New number value!
    function setNumber(uint256 newNumber) external {
        number = newNumber;
    }

    /// @notice  Returns the version of the Orb. Internal constant `_VERSION` will be increased with each upgrade.
    /// @return  versionNumber  Version of the Orb.
    function version() public view virtual override returns (uint256 versionNumber) {
        return _VERSION;
    }
}
