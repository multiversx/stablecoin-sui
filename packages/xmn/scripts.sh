# Copyright 2025 Circle Internet Group, Inc. All rights reserved.
# 
# SPDX-License-Identifier: Apache-2.0
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/bin/env bash

# Load the full JSON into a variable
JSON_FILE="mainnet_publish.json"

# 1) Your package ID is the one published
PACKAGE_ID=$(jq -r '
  .objectChanges[]
  | select(.type == "published")
  | .packageId
' "$JSON_FILE")

# 2) The Treasury object is the created object whose type contains "::treasury::Treasury<"
TREASURY_ID=$(jq -r '
  .objectChanges[]
  | select(.type == "created" and (.objectType | test("::treasury::Treasury<")))
  | .objectId
' "$JSON_FILE")

# 3) The DenyList object
DENY_LIST_ID=0x0000000000000000000000000000000000000000000000000000000000000403

# (Optional) the CoinMetadata object
METADATA_ID=$(jq -r '
  .objectChanges[]
  | select(.type == "created" and (.objectType | test("::CoinMetadata<")))
  | .objectId
' "$JSON_FILE")

AMOUNT=10000000000000000

XMN_TYPE="$PACKAGE_ID::xmn::XMN"

echo "PACKAGE_ID   = $PACKAGE_ID"
echo "TREASURY_ID  = $TREASURY_ID"
echo "DENY_LIST_ID = $DENY_LIST_ID"
echo "METADATA_ID  = $METADATA_ID"

function configure_controller() {
  sui client ptb \
    --move-call "$PACKAGE_ID::treasury::configure_new_controller" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$(sui client active-address)" @"$(sui client active-address)" \
    --summary
}

function configure_minter() {
  PTB_OUT=$(sui client ptb \
    --move-call "$PACKAGE_ID::treasury::configure_minter" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$DENY_LIST_ID" $AMOUNT \
    --json \
  )
  # echo $PTB_OUT

  # extract the mint_cap field from the MinterConfigured event
  MINT_CAP_ID=$(echo "$PTB_OUT" \
    | jq -r '
        .events[]
        | select(.type
            | test("::treasury::MinterConfigured<"))
        | .parsedJson.mint_cap
    '
  )

  if [[ -z "$MINT_CAP_ID" || "$MINT_CAP_ID" == "null" ]]; then
    echo "Failed to find MinterConfigured event!"
    exit 1
  fi

  echo "New MintCap ID = $MINT_CAP_ID"

}

function mint() {
  MINT_CAP_ID=0xb3638821876f77fcc966ed3f0fdc8e5087ac011eff9891934856cc2ff6ac645c
  MINT_TO=0x46b773eb9432b446875cb34e8d71f67e8cd49372f06d7730417206cb2492329b
  sui client ptb \
    --move-call "$PACKAGE_ID::treasury::mint" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$MINT_CAP_ID" @"$DENY_LIST_ID" $AMOUNT @"$MINT_TO" \
    --summary
}

function remove_controller() {
  sui client ptb \
    --move-call "$PACKAGE_ID::treasury::remove_controller" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$(sui client active-address)" \
    --summary
}

function remove_minter() {
  sui client ptb \
    --move-call "$PACKAGE_ID::treasury::remove_minter" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
    --summary
}

function update_metadata() {
  sui client ptb \
    --move-call "$PACKAGE_ID::treasury::update_metadata" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$METADATA_ID" \
      "\"XXD1\"" "\"XXD1\"" "\"My coin description\"" "\"my_second_url\"" \
    --summary
}

function transfer_ownership() {
  NEW_OWNER=0x2bc16adcc0e1c7cab348a1cda8797c4dbb510421f99c7cc03928a74f29afe68b
  sui client ptb \
    --move-call "$PACKAGE_ID::entry::transfer_ownership" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
      @"$NEW_OWNER" \
    --summary
}

function accept_ownership() {
  sui client ptb \
    --move-call "$PACKAGE_ID::entry::accept_ownership" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
    --summary
}

function accept_ownership_dry() {
  NEW_ADMIN=0x2bc16adcc0e1c7cab348a1cda8797c4dbb510421f99c7cc03928a74f29afe68b
  sui client ptb \
    --sender @"$NEW_ADMIN" \
    --move-call "$PACKAGE_ID::entry::accept_ownership" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
    --serialize-unsigned-transaction
}

function configure_controller_dry() {
  NEW_ADMIN=0x2bc16adcc0e1c7cab348a1cda8797c4dbb510421f99c7cc03928a74f29afe68b
  CONTROLLER=0xe715c2d07951664dce9d46da2d392f22db31696dbb0a2d34deaceffde08d753e
  sui client ptb \
    --sender @"$NEW_ADMIN" \
    --move-call "$PACKAGE_ID::treasury::configure_new_controller" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" @"$CONTROLLER" @"$CONTROLLER" \
    --serialize-unsigned-transaction
}

function transfer_admin_rights() {
  NEW_ADMIN=0x2bc16adcc0e1c7cab348a1cda8797c4dbb510421f99c7cc03928a74f29afe68b
  sui client ptb \
    --move-call "$PACKAGE_ID::entry::update_master_minter" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
      @"$NEW_ADMIN" \
    --move-call "$PACKAGE_ID::entry::update_blocklister" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
      @"$NEW_ADMIN" \
    --move-call "$PACKAGE_ID::entry::update_pauser" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
      @"$NEW_ADMIN" \
    --move-call "$PACKAGE_ID::entry::update_metadata_updater" \
      "<$PACKAGE_ID::xmn::XMN>" \
      @"$TREASURY_ID" \
      @"$NEW_ADMIN" \
    --summary
}

# This script takes in a function name as the first argument, 
# and runs it in the context of the script.
if [ -z $1 ]; then
  echo "Usage: bash run.sh <function>";
  exit 1;
elif declare -f "$1" > /dev/null; then
  "$@";
else
  echo "Function '$1' does not exist";
  exit 1;
fi

