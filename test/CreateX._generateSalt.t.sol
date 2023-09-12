// SPDX-License-Identifier: WTFPL
pragma solidity 0.8.21;

import {BaseTest} from "./BaseTest.sol";

contract CreateX_GenerateSalt_Internal_Test is BaseTest {
    /**
     * @dev Generates a 32-byte entropy value using the `keccak256` hashing algorithm.
     * @param seed The 32-byte seed value to generate the entropy value.
     * @param i The 32-byte increment value to further increase the randomness.
     * @return randomness The generated 32-byte entropy value.
     */
    function entropy(uint256 seed, uint256 i) internal pure returns (uint256 randomness) {
        randomness = uint256(keccak256(abi.encodePacked(seed, i)));
    }

    function test_ShouldBeAFunctionOfMultipleBlockPropertiesAndTheCaller() external {
        // It should be a function of multiple block properties and the caller.
        // The full set of dependencies is:
        //    - blockhash(block.number - 32),
        //    - block.coinbase,
        //    - block.number,
        //    - block.timestamp,
        //    - block.prevrandao,
        //    - block.chainid,
        //    - msg.sender.
        // We test their dependencies by determining the current salt, changing any of those
        // values, and verifying that the salt changes.
        uint256 snapshotId = vm.snapshot();
        bytes32 originalSalt = createXHarness.exposed_generateSalt();

        // Change block. Block number and hash are coupled, so we can't isolate this.
        vm.roll(block.number + 1);
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());

        // Change coinbase.
        vm.revertTo(snapshotId);
        assertEq(createXHarness.exposed_generateSalt(), originalSalt);

        vm.coinbase(makeAddr("new coinbase"));
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());

        // Change timestamp.
        vm.revertTo(snapshotId);
        assertEq(createXHarness.exposed_generateSalt(), originalSalt);

        vm.warp(block.timestamp + 1);
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());

        // Change prevrandao.
        vm.revertTo(snapshotId);
        assertEq(createXHarness.exposed_generateSalt(), originalSalt);

        vm.prevrandao("new prevrandao");
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());

        // Change chain ID.
        vm.revertTo(snapshotId);
        assertEq(createXHarness.exposed_generateSalt(), originalSalt);

        vm.chainId(111222333);
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());

        // Change sender.
        vm.revertTo(snapshotId);
        assertEq(createXHarness.exposed_generateSalt(), originalSalt);

        vm.prank(makeAddr("new sender"));
        assertNotEq(originalSalt, createXHarness.exposed_generateSalt());
    }

    function testFuzz_NeverReverts(uint256 seed) external {
        // It never reverts.
        // We derive all our salt properties from the seed and ensure that it never reverts.
        // First, we generate all the entropy.
        uint256 entropy1 = entropy(seed, 1);
        uint256 entropy2 = entropy(seed, 2);
        uint256 entropy3 = entropy(seed, 3);
        uint256 entropy4 = entropy(seed, 4);
        uint256 entropy5 = entropy(seed, 5);
        uint256 entropy6 = entropy(seed, 6);

        // Second, we set the block properties.
        vm.roll(bound(entropy1, block.number, 1e18));
        vm.coinbase(address(uint160(entropy2)));
        vm.warp(bound(entropy3, block.timestamp, 52e4 weeks));
        vm.prevrandao(bytes32(entropy4));
        vm.chainId(bound(entropy5, 0, type(uint64).max));
        vm.prank(address(uint160(entropy6)));

        // Third, we verify that it doesn't revert by calling it.
        createXHarness.exposed_generateSalt();
    }
}
