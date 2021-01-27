pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-value/value.sol";
import "ds-token/token.sol";
import {Vat}              from "dss/vat.sol";
import {Spotter}          from "dss/spot.sol";
import {Dai}              from "dss/dai.sol";

import "./mock/Delegator.mock.sol";

import "./testhelper/TestToken.sol";
import "./testhelper/MkrTokenAuthority.sol";

import "./RewardJoin.sol";

contract RewardJoinTest is DSTest {

    RewardJoin join;
    DelegatorMock excessDelegator;

    address me;

    Vat vat;
    Spotter spotGem;
    DSValue pipGem;
    TestToken univ;
    Dai dai;

    DSToken bonusToken;
    DelegatorMock bonusDelegator;

    bytes32 constant ilkUni = "univ";
    uint256 UNIV_WAD;
    uint256 UNIV_TO_18;

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function setUp() public {

        me = address(this);

        vat = new Vat();

        spotGem = new Spotter(address(vat));
        vat.rely(address(spotGem));

        univ = new TestToken("UNIV2XXX", 6);
        TokenAuthority univAuthority = new TokenAuthority();
        univ.setAuthority(DSAuthority(address(univAuthority)));
        UNIV_WAD = 10 ** univ.decimals();
        UNIV_TO_18 = 10 ** (18 - univ.decimals());
        univ.mint(1000 * UNIV_WAD);
        vat.init(ilkUni);

        dai = new Dai(0);

        bonusToken = new TestToken("UNI", 8);
        TokenAuthority bonusAuthority = new TokenAuthority();
        bonusToken.setAuthority(DSAuthority(address(bonusAuthority)));
        bonusToken.mint(3000000);

        bonusDelegator = new DelegatorMock(address(dai), address(univ), address(bonusToken));

        join = new RewardJoin(address(vat), ilkUni, address(univ), address(bonusToken));
        join.rely(me);
        vat.rely(address(join));

        pipGem = new DSValue();
        pipGem.poke(bytes32(uint256(1 ether))); // Spot = $1

        spotGem.file(ilkUni, bytes32("pip"), address(pipGem));
        spotGem.file(ilkUni, bytes32("mat"), ray(1 ether));
        spotGem.poke(ilkUni);

        vat.file(ilkUni, "line", rad(1000 ether));
        vat.file("Line",       rad(1000 ether));

    }

    function test_harvest_with_bonus() public {
        bonusToken.transfer(address(join), 3000000);
        assertEq(bonusToken.balanceOf(address(join)) , 3000000);

        join.file("bonus_delegator", address(bonusDelegator));

        join.harvest();

        assertTrue(bonusDelegator.hasMoneyBeenSent());
        assertEq(bonusToken.balanceOf(address(bonusDelegator)) , 3000000);
        assertEq(univ.balanceOf(address(bonusDelegator)) , 0);
    }

    function test_harvest_with_no_bonus() public {
        univ.approve(address(join));//token

        join.file("bonus_delegator", address(bonusDelegator));

        join.join(me, 100 * UNIV_WAD);
        join.exit(me, 100 * UNIV_WAD);
        join.harvest();

        assertTrue(!bonusDelegator.hasMoneyBeenSent());
        assertEq(bonusToken.balanceOf(address(bonusDelegator)) , 0);
    }
}
