// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {EricOrbHarness} from "./harness/EricOrbHarness.sol";
import {EricOrb} from "contracts/EricOrb.sol";

contract EricOrbTest is Test{

    EricOrbHarness orb;

    address user;

    function setUp() public {
        orb = new EricOrbHarness();
        user = address(0xBEEF);
    }

    function prankAndBid(address bidder, uint256 bidAmount) internal {
        uint256 finalAmount = orb.fundsRequiredToBid(bidAmount);
        vm.deal(bidder, finalAmount);
        vm.prank(bidder);
        orb.bid{value: finalAmount}(bidAmount);
    }

    // Test that the initial state is correct
    function test_initialState() public {
        assertEq(address(orb), orb.ownerOf(orb.workaround_orbId()));
        assertFalse(orb.auctionRunning());
        assertEq(orb.owner(), address(this));

        // This will be callable after audit mitigations
        // assertEq(orb.price(), 0);
        assertEq(orb.lastTriggerTime(), 0);
        assertEq(orb.triggersCount(), 0);

        assertEq(orb.flaggedResponsesCount(), 0);

        assertEq(orb.startTime(), 0);
        assertEq(orb.endTime(), 0);
        assertEq(orb.winningBidder(), address(0));
        assertEq(orb.winningBid(), 0);

        // This will be callable after audit mitigations
        // assertEq(orb.lastSettlementTime(), 0);
        // assertEq(orb.userReceiveTime(), 0);
    }

    function test_constants() public {
        assertEq(orb.COOLDOWN(), 7 days);
        assertEq(orb.RESPONSE_FLAGGING_PERIOD(), 7 days);
        assertEq(orb.MAX_CLEARTEXT_LENGTH(), 280);

        assertEq(orb.FEE_DENOMINATOR(), 10000);
        assertEq(orb.HOLDER_TAX_NUMERATOR(), 1000);
        assertEq(orb.HOLDER_TAX_PERIOD(), 365 days);
        assertEq(orb.SALE_ROYALTIES_NUMERATOR(), 1000);

        assertEq(orb.STARTING_PRICE(), 0.1 ether);
        assertEq(orb.MINIMUM_BID_STEP(), 0.01 ether);
        assertEq(orb.MINIMUM_AUCTION_DURATION(), 1 days);
        assertEq(orb.BID_AUCTION_EXTENSION(), 30 minutes);

        assertEq(orb.workaround_orbId(), 69);
        assertEq(orb.workaround_infinity(), type(uint256).max);
        assertEq(orb.workaround_maxPrice(), 2 ** 128 );
        assertEq(orb.workaround_baseUrl(), "https://static.orb.land/eric/");
    }

    function test_transfers() public {
        address newOwner = address(0xBEEF);
        uint256 id = orb.workaround_orbId();
        vm.expectRevert(EricOrb.TransferringNotSupported.selector);
        orb.transferFrom(address(this), newOwner, id);
        vm.expectRevert(EricOrb.TransferringNotSupported.selector);
        orb.safeTransferFrom(address(this), newOwner, id);
        vm.expectRevert(EricOrb.TransferringNotSupported.selector);
        orb.safeTransferFrom(address(this), newOwner, id, bytes(""));
    }

    function test_minimumBid() public {
        uint256 bidAmount = 0.6 ether;
        orb.startAuction();
        assertEq(orb.minimumBid(), orb.STARTING_PRICE());
        prankAndBid(user, bidAmount);
        assertEq(orb.minimumBid(), bidAmount + orb.MINIMUM_BID_STEP());
    }

    function test_fundsRequiredToBid(uint256 amount) public {
        amount = bound(amount, 0, type(uint224).max);
        assertEq(orb.fundsRequiredToBid(amount), amount + (amount * 1_000 / 10_000));
    }


    function test_startAuctionOnlyOrbIssuer() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("Ownable: caller is not the owner");
        orb.startAuction();
        orb.startAuction();
        assertEq(orb.startTime(), block.timestamp);
    }

    event AuctionStarted(uint256 startTime, uint256 endTime);

    function test_startAuctionCorrectly() public {
        assertEq(orb.startTime(), 0);
        orb.workaround_setWinningBid(10);
        orb.workaround_setWinningBidder(address(0xBEEF));
        vm.expectEmit(true, true, false, false);
        emit AuctionStarted(block.timestamp, block.timestamp + orb.MINIMUM_AUCTION_DURATION());
        orb.startAuction();
        assertEq(orb.startTime(), block.timestamp);
        assertEq(orb.endTime(), block.timestamp + orb.MINIMUM_AUCTION_DURATION());
        assertEq(orb.winningBid(), 0);
        assertEq(orb.winningBidder(), address(0));
    }

    function test_startAuctionOnlyContractHeld() public {
        orb.workaround_setOrbHolder(address(0xBEEF));
        vm.expectRevert(EricOrb.ContractDoesNotHoldOrb.selector);
        orb.startAuction();
        orb.workaround_setOrbHolder(address(orb));
        vm.expectEmit(true, true, false, false);
        emit AuctionStarted(block.timestamp, block.timestamp + orb.MINIMUM_AUCTION_DURATION());
        orb.startAuction();
    }

    function test_startAuctionNotDuringAuction() public {
        vm.expectEmit(true, true, false, false);
        emit AuctionStarted(block.timestamp, block.timestamp + orb.MINIMUM_AUCTION_DURATION());
        orb.startAuction();
        vm.expectRevert(EricOrb.AuctionRunning.selector);
        orb.startAuction();
    }

    function test_bidOnlyDuringAuction() public {
        uint256 bidAmount = 0.6 ether;
        vm.expectRevert(EricOrb.AuctionNotRunning.selector);
        orb.bid{value: 1 ether}(bidAmount);
        orb.startAuction();
        assertEq(orb.winningBid(), 0 ether);
        orb.bid{value: 1 ether}(bidAmount);
        assertEq(orb.winningBid(), bidAmount);
    }

}
