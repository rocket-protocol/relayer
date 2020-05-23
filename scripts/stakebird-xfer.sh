#!/bin/bash

./scripts/gaia-stakebird.sh local skip
sleep 5

make install

rm -rf ~/.relayer/
rly cfg init
rly cfg add-dir configs/stakebird-demo/

rly keys restore ibc0 testkey "$(jq -r '.secret' data/ibc0/n0/gaiacli/key_seed.json)"
rly keys restore ibc1 testkey "$(jq -r '.secret' data/ibc1/n0/stakecli/key_seed.json)"

rly lite init ibc0 -f
rly lite init ibc1 -f

rly tx link demo
rly q bal ibc0
rly q bal ibc1

rly tx xfer ibc0 ibc1 100000stake true $(rly keys show ibc1 testkey)
rly q bal ibc0
rly q bal ibc1
