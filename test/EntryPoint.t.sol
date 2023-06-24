// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/core/EntryPoint.sol";

contract EntryPointTest is Test {
    EntryPoint public entrypoint;

    function setUp() public {
        entrypoint = new EntryPoint();
        //entrypoint.setNumber(0);
    }

    function testIncrement() public {
        //entrypoint.increment();
        //assertEq(entrypoint.number(), 1);
    }

    function testSetNumber(uint256 x) public {
        //entrypoint.setNumber(x);
        //assertEq(entrypoint.number(), x);
    }
}
