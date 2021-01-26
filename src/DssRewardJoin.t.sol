pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./DssRewardJoin.sol";

contract DssRewardJoinTest is DSTest {
    DssRewardJoin join;

    function setUp() public {
        join = new DssRewardJoin();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
