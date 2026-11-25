// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ClubVote {
    address public admin;
    mapping(address => bool) public isMember;
    uint256 public memberCount;
    uint256 public quorumPercent;

    event MemberAdded(address indexed member);

    error NotAdmin();
    error NotMember();
    error AlreadyMember();
    error ZeroAddress();
    error InvalidQuorum();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyMember() {
        if (!isMember[msg.sender]) revert NotMember();
        _;
    }

    constructor(address[] memory initialMembers, uint256 _quorumPercent) {
        if (_quorumPercent == 0 || _quorumPercent > 100) revert InvalidQuorum();

        admin = msg.sender;
        quorumPercent = _quorumPercent;

        _addMember(msg.sender);

        for (uint256 i = 0; i < initialMembers.length; i++) {
            if (!isMember[initialMembers[i]]) {
                _addMember(initialMembers[i]);
            }
        }
    }

    function addMember(address member) external onlyAdmin {
        if (isMember[member]) revert AlreadyMember();
        _addMember(member);
    }

    function _addMember(address member) internal {
        if (member == address(0)) revert ZeroAddress();
        isMember[member] = true;
        memberCount++;
        emit MemberAdded(member);
    }
}
