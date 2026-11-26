// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ClubVote} from "../src/ClubVote.sol";

contract DeployClubVote is Script {
    function run() external returns (ClubVote clubVote) {
        address[] memory members = vm.envOr("MEMBERS", ",", new address[](0));
        uint256 quorum = vm.envOr("QUORUM_PERCENT", uint256(50));

        vm.startBroadcast();
        clubVote = new ClubVote(members, quorum);
        vm.stopBroadcast();

        console.log("ClubVote deployed at:", address(clubVote));
        console.log("Admin:", clubVote.admin());
        console.log("Members:", clubVote.memberCount());
        console.log("Quorum %:", clubVote.quorumPercent());
    }
}
