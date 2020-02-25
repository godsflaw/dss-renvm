#!/usr/bin/env bash

# hardcode if we already deployed collateral adapter
export PIP="0xdeadbeef"
export JOIN="0x84897a8CBaD7661b17D5219DeA3dC18358377073"
export FLIP="0xdeadbeef"
export SPELL="0xdeadbeef"

export NETWORK="kovan"
export TOKEN_ID="zBTC-A"
export TOKEN_PRICE="1030371"
export TOKEN="0xc6069e8dea210c937a846db2cebc0f58ca111f26"
export REGISTRY="0xbA563a8510d86dE95F5a50007E180d6d4966ad12"
export DEBT_CEILING=25000000 # $25mm
export COLLATERALIZATION_RATIO=150 # 150%
export SF=1.05 # 5%
export LIQUIDATION_PENALTY=113 # 13%
export LOT_SIZE=1 # max zBTC in a single auction

# DO NOT EDIT BELOW THIS LINE
# -----------------------------------------------------------------------------

. ./env-${NETWORK}
. ./env-addresses-${NETWORK}

dapp update
rm -fr ./out
dapp build --extract

export DECIMALS=$(seth --to-dec $(seth call $TOKEN "decimals()"))

# our ilk's bytes32
export ILK="$(seth --to-bytes32 "$(seth --from-ascii "${TOKEN_ID}")")"

# our price oracle and the initial price
#export PIP=$(dapp create --verify DSValue)
#seth send $PIP 'poke(bytes32)' \
#  $(seth --to-uint256 "$(seth --to-wei ${TOKEN_PRICE} ETH)")
#
#ret=$(seth call $PIP 'read()')
#
#echo "price oracle deployed with 1 ${TOKEN_ID} worth ${ret}"

# deploy the gem adapter
#if [ "${DECIMALS}" = "18" ]; then
#  export JOIN=$(dapp create --verify GemJoin "$MCD_VAT" "$ILK" "$TOKEN")
#else
#  export UINT_DEC=$(seth --to-uint256 $DECIMALS)
#  export JOIN=$(dapp create --verify \
#    GemJoin3 "$MCD_VAT" "$ILK" "$TOKEN" "$UINT_DEC")
#fi
#seth send "$JOIN" 'rely(address)' "$MCD_PAUSE_PROXY"
#seth send "$JOIN" 'deny(address)' "$ETH_FROM"

# deploy a flipper (collateral auction contract) for this ilk
#export FLIP=$(dapp create --verify Flipper "$MCD_VAT" "$ILK")
#seth send "$FLIP" 'rely(address)' "$MCD_PAUSE_PROXY"
#seth send "$FLIP" 'deny(address)' "$ETH_FROM"

# set the collateral risk parameters

export LINE=$(seth --to-uint256 $(echo "${DEBT_CEILING}"*10^45 | bc))
export MAT=$(seth --to-uint256 $(echo "${COLLATERALIZATION_RATIO}"*10^25 | bc))
export CHOP=$(seth --to-uint256 $(echo "${LIQUIDATION_PENALTY}"*10^25 | bc))
export LUMP=$(seth --to-uint256 $(echo "${LOT_SIZE}"*10^18 | bc))
export DUTY=$(seth --to-uint256 \
  $(bc -l <<< "scale=27; e( l(${SF})/(60 * 60 * 24 * 365) )"|sed 's/\.//g') \
)

# deploy collateral addition spell
#export SPELL=$(dapp create --verify DssAddIlkSpell \
#  $ILK \
#  $MCD_PAUSE \
#  ["${MCD_VAT#0x}","${MCD_CAT#0x}","${MCD_JUG#0x}","${MCD_SPOT#0x}","${MCD_END#0x}","${JOIN#0x}","${PIP#0x}","${FLIP#0x}"] \
#  ["$LINE","$MAT","$DUTY","$CHOP","$LUMP"] \
#)
#
#seth send "${MCD_ADM}" 'vote(address[] memory)' ["${SPELL#0x}"]

export DIRECTZBTCPROXY=$(dapp create --verify DirectZBTCProxy \
  "$TOKEN" \
  "$MCD_DAI" \
  "$ILK" \
  "$CDP_MANAGER" \
  "$MCD_JOIN_DAI" \
  "$JOIN" \
  "$MCD_VAT" \
)
export ZBTCPROXY=$(dapp create --verify ZBTCProxy \
  "$REGISTRY" \
  "$MCD_DAI" \
  "$DIRECTZBTCPROXY" \
)

echo "DirectZBTCProxy: ${DIRECTZBTCPROXY}"
echo "ZBTCProxy: ${ZBTCPROXY}"
echo "Flipper: ${FLIP}"
echo "Spell: ${SPELL}"
echo "Join: ${JOIN}"
echo "Pip: ${PIP}"
