// SPDX-License-Identifier: AGPL-3.0-or-later

/// join-5-auth.sol -- Non-standard token adapters

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018-2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.7;

import "dss/lib.sol";

interface VatLike {
    function slip(bytes32, address, int256) external;
}

interface GemLike {
    function decimals() external view returns (uint8);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract RewardJoin is LibNote {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address usr) external auth note { wards[usr] = 1; emit Rely(usr); }
    function deny(address usr) external auth note { wards[usr] = 0; emit Deny(usr); }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- Lock ---
    uint private unlocked = 1;
    modifier lock() {require(unlocked == 1, 'DssPsmCme/Locked');unlocked = 0;_;unlocked = 1;}

    // --- Data ---
    VatLike public vat;
    bytes32 public ilk;
    GemLike public gem;
    uint256 public dec;
    uint256 public live;  // Access Flag
    address public bonusDelegator;
    GemLike public immutable bonusToken;

    // --- Event ---
    event Rely(address indexed user);
    event Deny(address indexed user);
    event File(bytes32 indexed what, address data);
    event Delegate(address indexed sender, address indexed delegator, uint256 bonus);

    // --- Init ---
    constructor(address vat_, bytes32 ilk_, address gem_, address bonusToken_) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
        gem = GemLike(gem_);
        dec = gem.decimals();
        bonusDelegator = address(0);
        bonusToken = GemLike(bonusToken_);
        require(dec <= 18, "RewardJoin/decimals-18-or-higher");
        live = 1;
        vat = VatLike(vat_);
        ilk = ilk_;
    }

    // --- Math ---
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "RewardJoin/overflow");
    }

    // --- Administration ---
    function cage() external note auth {
        live = 0;
    }

    function file(bytes32 what, address data) external auth {
        if (what == "bonus_delegator") bonusDelegator = data;
        else revert("RewardJoin/file-unrecognized-param");

        emit File(what, data);
    }

    // --- Primary Functions ---

    // --- Harvest ---
    function harvest() external note lock auth {
        if (bonusDelegator != address(0)) {
            uint256 _balance = bonusToken.balanceOf(address(this));
            if (_balance > 0) {
                require(bonusToken.transfer(bonusDelegator, _balance), "RewardJoin/failed-transfer-bonus-token");
                emit Delegate(msg.sender, bonusDelegator, _balance);
            }
        }
    }

    // --- Join Functions ---
    function join(address guy, uint256 wad) external note {
        require(live == 1, "RewardJoin/not-live");
        uint256 wad18 = mul(wad, 10 ** (18 - dec));
        require(int256(wad18) >= 0, "RewardJoin/overflow");
        vat.slip(ilk, guy, int256(wad18));
        require(gem.transferFrom(guy, address(this), wad), "RewardJoin/join-failed-transfer");
    }

    function exit(address guy, uint256 wad) external note {
        uint256 wad18 = mul(wad, 10 ** (18 - dec));
        require(int256(wad18) >= 0, "RewardJoin/overflow");
        vat.slip(ilk, msg.sender, -int256(wad18));
        require(gem.transfer(guy, wad), "RewardJoin/exit-failed-transfer");
    }
}