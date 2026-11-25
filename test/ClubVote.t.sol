// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ClubVote} from "../src/ClubVote.sol";

contract ClubVoteTest is Test {
    ClubVote clubVote;

    address admin = makeAddr("admin");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address dave = makeAddr("dave");

    uint256 constant QUORUM = 50;
    uint256 constant DURATION = 1 days;

    function setUp() public {
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        vm.prank(admin);
        clubVote = new ClubVote(members, QUORUM);
    }

    function _getProposal(uint256 id) internal view returns (ClubVote.Proposal memory p) {
        (p.description, p.proposer, p.deadline, p.yesVotes, p.noVotes, p.memberCountAtCreation, p.finalized, p.passed) =
            clubVote.proposals(id);
    }

    function _createProposal() internal returns (uint256) {
        vm.prank(alice);
        return clubVote.createProposal("Spend $200 on pizza night", DURATION);
    }

    // ---------- Main flow ----------

    function test_ConstructorSetsUpClub() public view {
        assertEq(clubVote.admin(), admin);
        assertEq(clubVote.quorumPercent(), QUORUM);
        assertEq(clubVote.memberCount(), 4);
        assertTrue(clubVote.isMember(admin));
        assertTrue(clubVote.isMember(alice));
        assertTrue(clubVote.isMember(bob));
        assertTrue(clubVote.isMember(carol));
        assertFalse(clubVote.isMember(dave));
    }

    function test_AdminCanAddMember() public {
        vm.prank(admin);
        clubVote.addMember(dave);

        assertTrue(clubVote.isMember(dave));
        assertEq(clubVote.memberCount(), 5);
    }

    function test_MemberCanCreateProposal() public {
        uint256 id = _createProposal();

        ClubVote.Proposal memory p = _getProposal(id);
        assertEq(id, 0);
        assertEq(clubVote.proposalCount(), 1);
        assertEq(p.description, "Spend $200 on pizza night");
        assertEq(p.proposer, alice);
        assertEq(p.deadline, block.timestamp + DURATION);
        assertEq(p.memberCountAtCreation, 4);
        assertFalse(p.finalized);
    }

    function test_MembersCanVote() public {
        uint256 id = _createProposal();

        vm.prank(alice);
        clubVote.vote(id, true);
        vm.prank(bob);
        clubVote.vote(id, false);

        ClubVote.Proposal memory p = _getProposal(id);
        assertEq(p.yesVotes, 1);
        assertEq(p.noVotes, 1);
        assertTrue(clubVote.hasVoted(id, alice));
        assertTrue(clubVote.hasVoted(id, bob));
        assertFalse(clubVote.hasVoted(id, carol));
    }

    function test_ProposalPasses() public {
        uint256 id = _createProposal();

        vm.prank(alice);
        clubVote.vote(id, true);
        vm.prank(bob);
        clubVote.vote(id, true);
        vm.prank(carol);
        clubVote.vote(id, false);

        vm.warp(block.timestamp + DURATION);

        vm.expectEmit(true, false, false, true);
        emit ClubVote.ProposalFinalized(id, true, 2, 1);

        vm.prank(bob);
        clubVote.finalize(id);

        ClubVote.Proposal memory p = _getProposal(id);
        assertTrue(p.finalized);
        assertTrue(p.passed);
    }

    function test_ProposalFailsOnTie() public {
        uint256 id = _createProposal();

        vm.prank(alice);
        clubVote.vote(id, true);
        vm.prank(bob);
        clubVote.vote(id, false);

        vm.warp(block.timestamp + DURATION);
        vm.prank(alice);
        clubVote.finalize(id);

        ClubVote.Proposal memory p = _getProposal(id);
        assertTrue(p.finalized);
        assertFalse(p.passed);
    }

    function test_ProposalFailsWithoutQuorum() public {
        uint256 id = _createProposal();

        vm.prank(alice);
        clubVote.vote(id, true);

        vm.warp(block.timestamp + DURATION);
        vm.prank(alice);
        clubVote.finalize(id);

        ClubVote.Proposal memory p = _getProposal(id);
        assertTrue(p.finalized);
        assertFalse(p.passed);
    }

    function test_QuorumUsesMemberCountAtCreation() public {
        uint256 id = _createProposal();

        vm.prank(alice);
        clubVote.vote(id, true);
        vm.prank(bob);
        clubVote.vote(id, true);

        vm.startPrank(admin);
        clubVote.addMember(dave);
        clubVote.addMember(makeAddr("erin"));
        clubVote.addMember(makeAddr("frank"));
        vm.stopPrank();

        vm.warp(block.timestamp + DURATION);
        vm.prank(alice);
        clubVote.finalize(id);

        assertTrue(_getProposal(id).passed);
    }
}
