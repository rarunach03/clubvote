// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ClubVote {
    struct Proposal {
        string description;
        address proposer;
        uint256 deadline;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 memberCountAtCreation;
        bool finalized;
        bool passed;
    }

    address public admin;
    mapping(address => bool) public isMember;
    uint256 public memberCount;
    uint256 public quorumPercent;

    uint256 public proposalCount;
    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event MemberAdded(address indexed member);
    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 deadline);
    event Voted(uint256 indexed id, address indexed voter, bool support);
    event ProposalFinalized(uint256 indexed id, bool passed, uint256 yesVotes, uint256 noVotes);

    error NotAdmin();
    error NotMember();
    error AlreadyMember();
    error ZeroAddress();
    error InvalidQuorum();
    error EmptyDescription();
    error InvalidDuration();
    error ProposalNotFound();
    error VotingClosed();
    error AlreadyVoted();
    error VotingNotEnded();
    error AlreadyFinalized();

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

    function createProposal(string calldata description, uint256 duration) external onlyMember returns (uint256 id) {
        if (bytes(description).length == 0) revert EmptyDescription();
        if (duration == 0) revert InvalidDuration();

        id = proposalCount++;
        Proposal storage p = proposals[id];
        p.description = description;
        p.proposer = msg.sender;
        p.deadline = block.timestamp + duration;
        p.memberCountAtCreation = memberCount;

        emit ProposalCreated(id, msg.sender, description, p.deadline);
    }

    function vote(uint256 id, bool support) external onlyMember {
        if (id >= proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[id];
        if (block.timestamp >= p.deadline) revert VotingClosed();
        if (hasVoted[id][msg.sender]) revert AlreadyVoted();

        hasVoted[id][msg.sender] = true;
        if (support) {
            p.yesVotes++;
        } else {
            p.noVotes++;
        }

        emit Voted(id, msg.sender, support);
    }

    function finalize(uint256 id) external onlyMember {
        if (id >= proposalCount) revert ProposalNotFound();
        Proposal storage p = proposals[id];
        if (block.timestamp < p.deadline) revert VotingNotEnded();
        if (p.finalized) revert AlreadyFinalized();

        uint256 totalVotes = p.yesVotes + p.noVotes;
        bool quorumReached = totalVotes * 100 >= p.memberCountAtCreation * quorumPercent;

        p.finalized = true;
        p.passed = quorumReached && p.yesVotes > p.noVotes;

        emit ProposalFinalized(id, p.passed, p.yesVotes, p.noVotes);
    }

    function _addMember(address member) internal {
        if (member == address(0)) revert ZeroAddress();
        isMember[member] = true;
        memberCount++;
        emit MemberAdded(member);
    }
}
