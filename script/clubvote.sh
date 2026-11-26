#!/usr/bin/env bash
set -euo pipefail

RPC_URL="${RPC_URL:-http://127.0.0.1:8545}"
: "${CONTRACT:?Set CONTRACT to the deployed ClubVote address}"

signer() {
  if [[ -n "${ACCOUNT:-}" ]]; then
    echo "--account $ACCOUNT"
  elif [[ -n "${PRIVATE_KEY:-}" ]]; then
    echo "--private-key $PRIVATE_KEY"
  else
    echo "Set ACCOUNT (Foundry keystore name) or PRIVATE_KEY to send transactions" >&2
    exit 1
  fi
}

send() {
  cast send "$CONTRACT" "$@" --rpc-url "$RPC_URL" $(signer) > /dev/null
  echo "Transaction confirmed."
}

usage() {
  cat <<EOF
Usage: script/clubvote.sh <command> [args]

Read commands:
  info                         Admin, member count, quorum, proposal count
  is-member <address>          Check if an address is a member
  status <id>                  Show a proposal's details and result

Write commands (need ACCOUNT or PRIVATE_KEY):
  add-member <address>         Admin only
  create "<description>" <sec> Create a proposal lasting <sec> seconds
  vote <id> <yes|no>           Vote once on a proposal
  finalize <id>                Lock in the result after the deadline

Local Anvil only:
  warp <sec>                   Fast-forward chain time
EOF
}

cmd="${1:-}"
shift || true

case "$cmd" in
  info)
    echo "Contract:  $CONTRACT"
    echo "Admin:     $(cast call "$CONTRACT" "admin()(address)" --rpc-url "$RPC_URL")"
    echo "Members:   $(cast call "$CONTRACT" "memberCount()(uint256)" --rpc-url "$RPC_URL")"
    echo "Quorum %:  $(cast call "$CONTRACT" "quorumPercent()(uint256)" --rpc-url "$RPC_URL")"
    echo "Proposals: $(cast call "$CONTRACT" "proposalCount()(uint256)" --rpc-url "$RPC_URL")"
    ;;
  is-member)
    cast call "$CONTRACT" "isMember(address)(bool)" "$1" --rpc-url "$RPC_URL"
    ;;
  status)
    result=$(cast call "$CONTRACT" \
      "proposals(uint256)(string,address,uint256,uint256,uint256,uint256,bool,bool)" \
      "$1" --rpc-url "$RPC_URL")
    mapfile -t f <<< "$result" 2>/dev/null || IFS=$'\n' read -r -d '' -a f <<< "$result" || true
    echo "Proposal #$1"
    echo "  Description: ${f[0]}"
    echo "  Proposer:    ${f[1]}"
    echo "  Deadline:    ${f[2]}"
    echo "  Yes votes:   ${f[3]}"
    echo "  No votes:    ${f[4]}"
    echo "  Members at creation: ${f[5]}"
    echo "  Finalized:   ${f[6]}"
    echo "  Passed:      ${f[7]}"
    ;;
  add-member)
    send "addMember(address)" "$1"
    ;;
  create)
    send "createProposal(string,uint256)" "$1" "$2"
    echo "Proposal ID: $(( $(cast call "$CONTRACT" "proposalCount()(uint256)" --rpc-url "$RPC_URL") - 1 ))"
    ;;
  vote)
    case "$2" in
      yes) support=true ;;
      no) support=false ;;
      *) echo "Vote must be 'yes' or 'no'" >&2; exit 1 ;;
    esac
    send "vote(uint256,bool)" "$1" "$support"
    ;;
  finalize)
    send "finalize(uint256)" "$1"
    ;;
  warp)
    cast rpc evm_increaseTime "$1" --rpc-url "$RPC_URL" > /dev/null
    cast rpc evm_mine --rpc-url "$RPC_URL" > /dev/null
    echo "Advanced time by $1 seconds."
    ;;
  *)
    usage
    ;;
esac