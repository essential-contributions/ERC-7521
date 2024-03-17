// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IAccount} from "../../interfaces/IAccount.sol";

/**
 * a BLS account should expose its own public key.
 */
interface IBLSAccount is IAccount {
    /**
     * @return public key from a BLS keypair that is used to verify the BLS signature, both separately and aggregated.
     */
    function getBlsPublicKey() external view returns (uint256[4] memory);
}
