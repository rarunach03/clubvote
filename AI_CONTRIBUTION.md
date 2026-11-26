# AI Contribution Statement

I used Claude (Anthropic) as a coding assistant throughout this project. This statement describes what the AI did, what I did, and how I checked the work.

## What the AI did
- Generated the Solidity code for `ClubVote.sol` step by step (membership, proposals, voting, finalize), based on the design in my proposal
- Wrote the Foundry test suite (`test/ClubVote.t.sol`): 8 main-flow tests and 17 failure-case tests
- Wrote the deployment script (`DeployClubVote.s.sol`) and the CLI script (`clubvote.sh`)
- Explained Foundry concepts as I went (cheatcodes like `vm.prank`, `vm.warp`, `vm.expectRevert`; custom errors; keystores; contract verification)
- Helped debug setup and tooling issues (PATH setup, unsaved files, test placement errors, `.env` formatting, a timed-out Etherscan verification)
- Drafted the README and this statement, which I reviewed and edited

## What I did
- Designed the project and wrote the proposal: the problem, the core workflow, the pass/fail rule, and the security risks (block timestamp manipulation, public votes, commit-reveal as an extension)
- Chose the percentage-based quorum and accepted the quorum snapshot design (`memberCountAtCreation`)
- Asked for the contract to be split into clear steps and committed each one separately, so the Git history shows how the project was built
- Removed the inline comments from the contract to keep the final code clean
- Set up the Foundry project and GitHub repo, and saved, built, tested, and committed each step myself
- Ran all tests locally and confirmed GitHub Actions CI passed on every commit
- Ran the full demo on a local Anvil chain, including the `AlreadyVoted` failure case
- Created two wallets with Foundry's encrypted keystore (a deployer and a second member), got Sepolia ETH from the Google Cloud faucet, and funded the second member's wallet myself
- Deployed and verified the contract on Sepolia (re-ran verification after Etherscan's queue timed out)
- Ran the full voting flow on Sepolia with two real wallets: added a member, created a proposal, voted from both accounts, confirmed `VotingNotEnded` blocked early finalization, then finalized after the deadline

## How I verified the AI's work
- Every contract change was compiled with `forge build` before committing
- All 25 tests pass locally (`forge test`) and in GitHub Actions
- I ran the end-to-end workflow on both Anvil and Sepolia and checked the on-chain results with `status` and on Etherscan
- I reviewed the linter warnings (`block-timestamp`, `require-revert-in-loop`, `missing-events-access-control`) and confirmed they're expected behavior, not bugs
- Writing up the security section surfaced a real limitation (members added mid-vote can still vote on that proposal), which I documented in the README instead of hiding it

## What I learned
Before this project I knew what a smart contract was, but not how one is actually built, tested, and shipped. I learned how modifiers like `onlyAdmin` and `onlyMember` enforce access control, and why quorum is checked with multiplication (`totalVotes * 100 >= members * quorumPercent`), since Solidity has no decimals. The biggest difference was between a local chain and a real one: on Anvil I could skip time with `warp` and use public test keys, but on Sepolia I had to protect my keys with an encrypted keystore, get test ETH from a faucet, wait for real blocks, and watch the contract enforce the deadline on its own. I also learned that tests are what let me trust AI-generated code. Each of the 25 tests checks one specific rule, so when they all pass, I know the contract does what my proposal said it should.
