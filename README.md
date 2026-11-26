# ClubVote: On-Chain Voting for Student Organizations

ClubVote is a Solidity smart contract that lets a student club run yes/no votes on-chain. An admin manages the member list, any member can create a time-limited proposal, each member votes once, and after the deadline any member can finalize the result, which is permanently recorded on the blockchain.

**Live on Sepolia (verified):** [0x41de0c68a5a103534fb1d2d1e0ad0b577e21b9a9](https://sepolia.etherscan.io/address/0x41de0c68a5a103534fb1d2d1e0ad0b577e21b9a9#code)

Boiler Blockchain Final Project, Technical Track, by Rahul Arunachalam (solo).

---

## The Problem

Most clubs vote with a show of hands or a Google Form. Those are easy to miscount, people can vote more than once, and nobody outside the organizers can check the result. ClubVote enforces the rules in code: only members can vote, each member votes exactly once, voting closes at a fixed time, and anyone can audit every vote and result on Etherscan.

---

## How It Works

1. **Deploy.** The admin deploys the contract with an initial member list and a quorum percentage (for example, 50%). The admin is automatically a member.
2. **Add members.** The admin can add new members at any time with `addMember`.
3. **Propose.** Any member calls `createProposal(description, duration)`. The deadline is `block.timestamp + duration`.
4. **Vote.** Each member calls `vote(id, true/false)` once before the deadline.
5. **Finalize.** After the deadline, any member calls `finalize(id)`. The proposal **passes** only if:
   - **Quorum is reached:** `totalVotes * 100 >= memberCountAtCreation * quorumPercent`
   - **Majority says yes:** `yesVotes > noVotes` (a tie fails)

   The result is stored on-chain, and a `ProposalFinalized` event is emitted.

### Architecture

```
┌──────────────┐  cast / forge  ┌───────────────────────────────┐
│ CLI script   │ ─────────────▶ │ ClubVote.sol (Sepolia / Anvil)│
│ clubvote.sh  │ ◀───────────── │                               │
└──────────────┘  reads/events  │ admin, isMember, memberCount  │
                                │ proposals[id] → Proposal      │
┌──────────────┐                │ hasVoted[id][address]         │
│ Etherscan    │ ◀───────────── │ events: MemberAdded,          │
│ (audit trail)│  public data   │   ProposalCreated, Voted,     │
└──────────────┘                │   ProposalFinalized           │
                                └───────────────────────────────┘
```

All state lives in a single contract. There's no backend server or database: the blockchain is the source of truth, and the CLI is a thin wrapper around Foundry's `cast`.

### Key Design Decision: Quorum Snapshot

Each proposal stores `memberCountAtCreation`. Quorum is measured against the member count **when the proposal was created**, not when it's finalized. Without this, an admin could add members partway through a vote to raise the quorum target and make a proposal fail. The test `test_QuorumUsesMemberCountAtCreation` checks this.

### Other Design Choices

- **Custom errors** (`NotMember()`, `AlreadyVoted()`, …) instead of revert strings: cheaper gas and precise test assertions.
- **Integer quorum math:** Solidity has no decimals, so the quorum check multiplies both sides instead of dividing.
- **Anyone (member) can finalize:** no single person controls when results are locked in.

---

## Project Structure

```
src/ClubVote.sol               The contract
test/ClubVote.t.sol            25 Foundry tests (8 main flow + 17 failure cases)
script/DeployClubVote.s.sol    Deployment script (reads MEMBERS, QUORUM_PERCENT)
script/clubvote.sh             CLI to create, vote, finalize, and inspect
.env.example                   Environment variable template
```

---

## Setup

**Requirements:** [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, cast, anvil) and Git.

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup

git clone https://github.com/rarunach03/clubvote.git
cd clubvote
forge install
forge build
```

---

## Running the Tests

```bash
forge test -vv
```

Expected: **25 passed, 0 failed.** Tests also run automatically on every push via GitHub Actions.

| Category | What's tested |
|---|---|
| Main flow | Setup, adding members, creating proposals, voting, passing, tie fails, no-quorum fails, quorum snapshot |
| Access control | Non-admin can't add members; non-members can't propose, vote, or finalize |
| Input validation | Quorum 0 or over 100, zero address, empty description, zero duration, already a member |
| Voting rules | Can't vote twice, can't vote at/after the deadline, can't vote on a missing proposal |
| Finalize rules | Can't finalize early, can't finalize twice, can't finalize a missing proposal |

---

## Demo: Local (Anvil)

No real network or test ETH needed. Uses Anvil's built-in public test accounts.

**Terminal 1:**
```bash
anvil
```

**Terminal 2:**
```bash
MEMBERS=0x70997970C51812dc3A010C7d01b50e0d17dc79C8,0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC \
QUORUM_PERCENT=50 \
forge script script/DeployClubVote.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

export CONTRACT=0x5FbDB2315678afecb367f032d93F642f64180aa3
ADMIN_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ALICE_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
BOB_KEY=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

script/clubvote.sh info
PRIVATE_KEY=$ALICE_KEY script/clubvote.sh create "Spend 200 dollars on pizza night" 3600
PRIVATE_KEY=$ADMIN_KEY script/clubvote.sh vote 0 yes
PRIVATE_KEY=$ALICE_KEY script/clubvote.sh vote 0 yes
PRIVATE_KEY=$BOB_KEY   script/clubvote.sh vote 0 no
PRIVATE_KEY=$BOB_KEY   script/clubvote.sh vote 0 yes    # fails: AlreadyVoted
script/clubvote.sh warp 3600
PRIVATE_KEY=$BOB_KEY   script/clubvote.sh finalize 0
script/clubvote.sh status 0                              # Passed: true
```

> These are Anvil's publicly known test keys. Never use them on a real network.

---

## Demo: Sepolia Testnet

### Configuration

Copy the template and fill in an Etherscan API key (free at etherscan.io):

```bash
cp .env.example .env
```

```
SEPOLIA_RPC_URL=https://ethereum-sepolia-rpc.publicnode.com
ETHERSCAN_API_KEY=your_key_here
```

Store deployer keys in Foundry's encrypted keystore, never in files or commands:

```bash
cast wallet import clubvote-deployer --interactive
```

Get Sepolia ETH from a faucet (I used the Google Cloud Web3 faucet).

### Deploy and Verify

```bash
source .env
QUORUM_PERCENT=50 forge script script/DeployClubVote.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --account clubvote-deployer \
  --sender <your-deployer-address> \
  --broadcast --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Run the Flow

```bash
export CONTRACT=0x41de0c68a5a103534fb1d2d1e0ad0b577e21b9a9
export RPC_URL=$SEPOLIA_RPC_URL

ACCOUNT=clubvote-deployer script/clubvote.sh add-member <member2-address>
ACCOUNT=clubvote-deployer script/clubvote.sh create "Spend 200 dollars on pizza night" 300
ACCOUNT=clubvote-deployer script/clubvote.sh vote 0 yes
ACCOUNT=clubvote-member2  script/clubvote.sh vote 0 yes
ACCOUNT=clubvote-member2  script/clubvote.sh finalize 0   # before deadline: VotingNotEnded
# wait for the deadline...
ACCOUNT=clubvote-member2  script/clubvote.sh finalize 0
script/clubvote.sh status 0
```

Every transaction and event is visible on the [Etherscan page](https://sepolia.etherscan.io/address/0x41de0c68a5a103534fb1d2d1e0ad0b577e21b9a9).

### CLI Reference

| Command | Who | Description |
|---|---|---|
| `info` | anyone | Admin, member count, quorum, proposal count |
| `is-member <addr>` | anyone | Check membership |
| `status <id>` | anyone | Proposal details and result |
| `add-member <addr>` | admin | Add a member |
| `create "<desc>" <seconds>` | member | Create a proposal |
| `vote <id> <yes\|no>` | member | Vote once |
| `finalize <id>` | member | Lock in the result after the deadline |
| `warp <seconds>` | Anvil only | Fast-forward chain time |

Set `ACCOUNT=<keystore-name>` (or `PRIVATE_KEY=` on Anvil) for write commands. `RPC_URL` defaults to `http://127.0.0.1:8545`.

---

## Security Risks and Trust Assumptions

### 1. Admin is trusted (centralization)
**Risk:** The admin alone controls membership. A malicious admin could add wallets they control. Members added after a proposal starts can still vote on it, so an admin could add sock-puppet wallets mid-vote to swing the result.
**Impact:** One person could control the outcome of any vote.
**Mitigation:** The quorum snapshot stops the admin from changing the *quorum target* mid-vote, and every `MemberAdded` event is public on Etherscan, so suspicious additions are visible. **Remaining limitation:** voter eligibility isn't snapshotted. A fix would record each member's join time and only allow votes from members who joined before the proposal was created.

### 2. Votes are public
**Risk:** Every vote is tied to a wallet address and visible on-chain.
**Impact:** Members may feel pressure to vote a certain way on sensitive topics.
**Mitigation:** Not mitigated in this version. A future version could use a **commit-reveal** scheme: members submit a hash of their vote, then reveal it after voting closes.

### 3. Timestamp manipulation
**Risk:** Deadlines use `block.timestamp`, which validators can shift by a few seconds.
**Impact:** Negligible for votes lasting minutes to days. A vote might close a few seconds early or late.
**Mitigation:** Accepted risk. Use durations of at least several minutes.

### 4. One wallet = one member (Sybil resistance)
**Risk:** The contract can't tell whether two wallets belong to the same person.
**Mitigation:** Relies on the admin verifying identities off-chain before adding members.

### 5. Key management
**Mitigation:** Deployer and member keys are stored in Foundry's encrypted keystore. `.env` is git-ignored and only holds the RPC URL and Etherscan API key. No private keys are committed.

---

## Limitations and Future Work

- No `removeMember` function
- Voter eligibility isn't snapshotted per proposal (see Security Risk 1)
- Proposals are yes/no only. No multiple choice.
- No web frontend. Interaction is via the CLI or Etherscan's Write Contract tab.
- No admin transfer function

---

## AI Contribution Statement

See [AI_CONTRIBUTION.md](AI_CONTRIBUTION.md).