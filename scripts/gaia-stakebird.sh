#!/bin/bash

GAIA_REPO="$HOME/src/github.com/cosmos/gaia"
GAIA_BRANCH=master

STAKEBIRD_REPO="$HOME/src/github.com/rocket-protocol/stakebird"
STAKEBIRD_BRANCH=master

CHAIN_DATA="$(pwd)/data"

# ARGS: 
# $1 -> local || remote, defaults to remote

# Ensure user understands what will be deleted
if [[ -d $CHAIN_DATA ]] && [[ ! "$2" == "skip" ]]; then
  read -p "$0 will delete \$(pwd)/data folder. Do you wish to continue? (y/n): " -n 1 -r
  echo 
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
  fi
fi

rm -rf $CHAIN_DATA &> /dev/null
killall gaiad &> /dev/null
killall staked &> /dev/null

set -e


if [[ -d $GAIA_REPO ]]; then
  cd $GAIA_REPO

  # remote build syncs with remote then builds
  if [[ "$1" == "local" ]]; then
    echo "Using local version of github.com/cosmos/gaia"
    make install &> /dev/null
  else
    echo "Building github.com/cosmos/gaia@$GAIA_BRANCH..."
    if [[ ! -n $(git status -s) ]]; then
      # sync with remote $GAIA_BRANCH
      git fetch --all &> /dev/null

      # ensure the gaia repository successfully pulls the latest $GAIA_BRANCH
      if [[ -n $(git checkout $GAIA_BRANCH -q) ]] || [[ -n $(git pull origin $GAIA_BRANCH -q) ]]; then
        echo "failed to sync remote branch $GAIA_BRANCH"
        echo "in $GAIA_REPO, please rename the remote repository github.com/cosmos/gaia to 'origin'"
        exit 1
      fi

      # install
      make install &> /dev/null

      # ensure that built binary has the same version as the repo
      if [[ ! "$(gaiad version --long 2>&1 | grep "commit:" | sed 's/commit: //g')" == "$(git rev-parse HEAD)" ]]; then
        echo "built version of gaiad commit doesn't match"
        exit 1
      fi 
    else
      echo "uncommited changes in $GAIA_REPO, please commit or stash before building"
      exit 1
    fi
    
  fi 
else 
  echo "$GAIA_REPO doesn't exist, and you may not have have the gaia repo locally,"
  echo "if you want to download gaia to your \$GOPATH try running the following command:"
  echo "mkdir -p $(dirname $GAIA_REPO) && git clone git@github.com:cosmos/gaia $GAIA_REPO"
fi

if [[ -d $STAKEBIRD_REPO ]]; then
  cd $STAKEBIRD_REPO

  # remote build syncs with remote then builds
  if [[ "$1" == "local" ]]; then
    echo "Using local version of github.com/rocket-protocol/stakebird"
    make install &> /dev/null
  else
    echo "Building github.com/rocket-protocol/stakebird@$STAKEBIRD_BRANCH..."
    if [[ ! -n $(git status -s) ]]; then
      # sync with remote $GAIA_BRANCH
      git fetch --all &> /dev/null

      # ensure the gaia repository successfully pulls the latest $GAIA_BRANCH
      if [[ -n $(git checkout $STAKEBIRD_BRANCH -q) ]] || [[ -n $(git pull origin $STAKEBIRD_BRANCH -q) ]]; then
        echo "failed to sync remote branch $STAKEBIRD_BRANCH"
        echo "in $STAKEBIRD_REPO, please rename the remote repository github.com/rocket-protocol/stakebird to 'origin'"
        exit 1
      fi

      # install
      make install &> /dev/null

      # ensure that built binary has the same version as the repo
      if [[ ! "$(staked version --long 2>&1 | grep "commit:" | sed 's/commit: //g')" == "$(git rev-parse HEAD)" ]]; then
        echo "built version of staked commit doesn't match"
        exit 1
      fi 
    else
      echo "uncommited changes in $STAKEBIRD_REPO, please commit or stash before building"
      exit 1
    fi
    
  fi 
else 
  echo "$STAKEBIRD_REPO doesn't exist, and you may not have have the stakebird repo locally,"
  echo "if you want to download stakebird to your \$GOPATH try running the following command:"
  echo "mkdir -p $(dirname $STAKEBIRD_REPO) && git clone git@github.com:rocket-protocol/stakebird $STAKEBIRD_REPO"
fi

chainid0=ibc0
chainid1=ibc1

echo "Generating configurations..."
mkdir -p $CHAIN_DATA && cd $CHAIN_DATA
echo -e "\n" | gaiad testnet -o $chainid0 --v 1 --chain-id $chainid0 --node-dir-prefix n --keyring-backend test &> /dev/null
echo -e "\n" | staked testnet -o $chainid1 --v 1 --chain-id $chainid1 --node-dir-prefix n --keyring-backend test &> /dev/null

cfgpth="n0/gaiad/config/config.toml"
if [ "$(uname)" = "Linux" ]; then
  # TODO: Just index *some* specified tags, not all
  sed -i 's/index_all_keys = false/index_all_keys = true/g' $chainid0/$cfgpth
  
  # Set proper defaults and change ports
  sed -i 's/"leveldb"/"goleveldb"/g' $chainid0/$cfgpth
  
  # Make blocks run faster than normal
  sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid0/$cfgpth
  sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid0/$cfgpth
else
  # TODO: Just index *some* specified tags, not all
  sed -i '' 's/index_all_keys = false/index_all_keys = true/g' $chainid0/$cfgpth

  # Set proper defaults and change ports
  sed -i '' 's/"leveldb"/"goleveldb"/g' $chainid0/$cfgpth

  # Make blocks run faster than normal
  sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid0/$cfgpth
  sed -i '' 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid0/$cfgpth
fi

cfgpth="n0/staked/config/config.toml"
if [ "$(uname)" = "Linux" ]; then
  # TODO: Just index *some* specified tags, not all
  sed -i 's/index_all_keys = false/index_all_keys = true/g' $chainid1/$cfgpth
  
  # Set proper defaults and change ports
  sed -i 's/"leveldb"/"goleveldb"/g' $chainid1/$cfgpth
  sed -i 's#"tcp://0.0.0.0:26656"#"tcp://0.0.0.0:26556"#g' $chainid1/$cfgpth
  sed -i 's#"tcp://0.0.0.0:26657"#"tcp://0.0.0.0:26557"#g' $chainid1/$cfgpth
  sed -i 's#"localhost:6060"#"localhost:6061"#g' $chainid1/$cfgpth
  sed -i 's#"tcp://127.0.0.1:26658"#"tcp://127.0.0.1:26558"#g' $chainid1/$cfgpth
  
  # Make blocks run faster than normal
  sed -i 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid1/$cfgpth
  sed -i 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid1/$cfgpth
else
  # TODO: Just index *some* specified tags, not all
  sed -i '' 's/index_all_keys = false/index_all_keys = true/g' $chainid1/$cfgpth

  # Set proper defaults and change ports
  sed -i '' 's/"leveldb"/"goleveldb"/g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://0.0.0.0:26656"#"tcp://0.0.0.0:26556"#g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://0.0.0.0:26657"#"tcp://0.0.0.0:26557"#g' $chainid1/$cfgpth
  sed -i '' 's#"localhost:6060"#"localhost:6061"#g' $chainid1/$cfgpth
  sed -i '' 's#"tcp://127.0.0.1:26658"#"tcp://127.0.0.1:26558"#g' $chainid1/$cfgpth

  # Make blocks run faster than normal
  sed -i '' 's/timeout_commit = "5s"/timeout_commit = "1s"/g' $chainid1/$cfgpth
  sed -i '' 's/timeout_propose = "3s"/timeout_propose = "1s"/g' $chainid1/$cfgpth
fi

gclpth="n0/gaiacli/"
gaiacli config --home $chainid0/$gclpth chain-id $chainid0 &> /dev/null
gaiacli config --home $chainid0/$gclpth output json &> /dev/null
gaiacli config --home $chainid0/$gclpth node http://localhost:26657 &> /dev/null

gclpth="n0/stakecli/"
stakecli config --home $chainid1/$gclpth chain-id $chainid1 &> /dev/null
stakecli config --home $chainid1/$gclpth output json &> /dev/null
stakecli config --home $chainid1/$gclpth node http://localhost:26557 &> /dev/null

echo "Starting chain instances..."
gaiad --home $CHAIN_DATA/$chainid0/n0/gaiad start --pruning=nothing > $chainid0.log 2>&1 &
staked --home $CHAIN_DATA/$chainid1/n0/staked start --pruning=nothing > $chainid1.log 2>&1 & 