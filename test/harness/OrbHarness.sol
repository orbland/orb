// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Orb} from "src/Orb.sol";

/* solhint-disable func-name-mixedcase */
contract OrbHarness is
    Orb(
        69, // tokenId
        7 days, // cooldown
        address(0xC0FFEE) // beneficiary
    )
{
    function workaround_tokenId() public view returns (uint256) {
        return tokenId;
    }

    function workaround_infinity() public pure returns (uint256) {
        return type(uint256).max;
    }

    function workaround_maxPrice() public pure returns (uint256) {
        return MAX_PRICE;
    }

    function workaround_baseUrl() public pure returns (string memory) {
        return BASE_URL;
    }

    function workaround_setLeadingBidder(address bidder) public {
        leadingBidder = bidder;
    }

    function workaround_setLeadingBid(uint256 bid) public {
        leadingBid = bid;
    }

    function workaround_setPrice(uint256 _price) public {
        price = _price;
    }

    function workaround_setLastSettlementTime(uint256 time) public {
        lastSettlementTime = time;
    }

    function workaround_setOrbHolder(address holder) public {
        _transferOrb(ownerOf(tokenId), holder);
    }

    function workaround_owedSinceLastSettlement() public view returns (uint256) {
        return _owedSinceLastSettlement();
    }

    function workaround_settle() public {
        _settle();
    }
}
