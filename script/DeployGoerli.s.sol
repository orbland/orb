// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {DeployBase} from "./DeployBase.s.sol";

contract DeployGoerli is DeployBase {
    address[] private contributorWallets = [
        0xE48C655276C23F1534AE2a87A2bf8A8A6585Df70, // ercwl.eth
        0x9F49230672c52A2b958F253134BB17Ac84d30833, // jonas.eth
        0xf374CE39E4dB1697c8D0D77F91A9234b2Fd55F62 // odysseas
    ];
    uint256[] private contributorShares = [65, 20, 15];

    // our test issuer
    address private immutable issuerWallet = 0xC0A00c8c9EF6fe6F0a79B8a616183384dbaf8EC8;

    uint256 private immutable cooldown = 30 minutes;
    uint256 private immutable responseFlaggingPeriod = 30 minutes;
    uint256 private immutable auctionMinimumDuration = 30 minutes;
    uint256 private immutable bidAuctionExtension = 2 minutes;
    uint256 private immutable holderTaxNumerator = 1000;
    uint256 private immutable saleRoyaltiesNumerator = 1000;
    uint256 private immutable auctionStartingPrice = 0.1 ether;
    uint256 private immutable auctionMinimumBidStep = 0.1 ether;

    constructor()
        DeployBase(
            contributorWallets,
            contributorShares,
            issuerWallet,
            cooldown,
            responseFlaggingPeriod,
            auctionMinimumDuration,
            bidAuctionExtension,
            holderTaxNumerator,
            saleRoyaltiesNumerator,
            auctionStartingPrice,
            auctionMinimumBidStep
        )
    {}
}