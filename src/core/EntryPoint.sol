// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

/* solhint-disable avoid-low-level-calls */
/* solhint-disable no-inline-assembly */
/* solhint-disable private-vars-leading-underscore */

import {IntentValidatorExecutor} from "./IntentValidatorExecutor.sol";
import {NonceManager} from "./NonceManager.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {BaseIntentStandard} from "../interfaces/BaseIntentStandard.sol";
import {IIntentStandard} from "../interfaces/IIntentStandard.sol";
import {IntentSolution, IntentSolutionLib} from "../interfaces/IntentSolution.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {getSegmentStandard} from "../standards/utils/SegmentData.sol";
import {Exec, RevertReason} from "../utils/Exec.sol";

contract EntryPoint is IEntryPoint, NonceManager, IntentValidatorExecutor {
    using IntentSolutionLib for IntentSolution;
    using UserIntentLib for UserIntent;
    using RevertReason for bytes;

    /**
     * Execute a batch of UserIntents with given solution.
     * @param solution the UserIntents solution.
     */
    function handleIntents(IntentSolution calldata solution) external {
        _handleIntents(solution, IAggregator(address(0)), bytes32(0));
    }

    /**
     * Execute a batch of UserIntents using multiple solutions.
     * @param solutions list of solutions to execute for intents.
     */
    function handleIntentsMulti(IntentSolution[] calldata solutions) external {
        // loop through solutions and solve
        uint256 solsLen = solutions.length;
        for (uint256 i = 0; i < solsLen; i++) {
            _handleIntents(solutions[i], IAggregator(address(0)), bytes32(0));
        }
    }

    /**
     * Execute a batch of UserIntents with an aggregated signature.
     * @param solutions list of solutions to execute for intents.
     * @param aggregator address of aggregator.
     * @param intentsToAggregate bit field signaling which intents are part of the aggregated signature.
     * @param signature aggregated signature.
     */
    function handleIntentsAggregated(
        IntentSolution[] calldata solutions,
        IAggregator aggregator,
        bytes32 intentsToAggregate,
        bytes calldata signature
    ) external {
        require(address(aggregator) != address(0), "AA96 invalid aggregator");

        // get number of intents
        uint256 solsLen = solutions.length;
        uint256 totalIntents = 0;
        unchecked {
            for (uint256 i = 0; i < solsLen; i++) {
                totalIntents += solutions[0].intents.length;
            }
        }
        uint256 aggregatedIntentTotal = 0;
        for (uint256 i = 0; i < totalIntents; i++) {
            if ((uint256(intentsToAggregate) & (1 << i)) > 0) aggregatedIntentTotal++;
        }

        // validate aggregated intent signature
        UserIntent[] memory aggregatedIntents = new UserIntent[](aggregatedIntentTotal);
        for (uint256 i = 0; i < solsLen; i++) {
            for (uint256 j = 0; j < solutions[0].intents.length; j++) {}
        }
        aggregator.validateSignatures(aggregatedIntents, signature);

        // loop through solutions and solve
        for (uint256 i = 0; i < solsLen; i++) {
            _handleIntents(solutions[i], aggregator, intentsToAggregate);
            intentsToAggregate = intentsToAggregate << solutions[i].intents.length;
        }
    }

    /**
     * Run validation for the given intent.
     * @dev This method is view only.
     * @param intent the user intent to validate.
     */
    function validateIntent(UserIntent calldata intent) external view {
        // make sure sender is a deployed contract
        if (intent.sender.code.length == 0) {
            revert FailedIntent(0, 0, "AA20 account not deployed");
        }

        // validate intent standards are recognized and formatted correctly
        for (uint256 i = 0; i < intent.intentData.length; i++) {
            bytes32 standardId = getSegmentStandard(intent.intentData[i]);
            if (isEmbeddedIntentStandard(standardId)) {
                // validate the intent segment itself
                _validateIntentSegment(intent.intentData[i]);
            } else {
                IIntentStandard standard = _registeredStandards[standardId];
                if (standard == IIntentStandard(address(0))) {
                    revert FailedIntent(0, i, "AA82 unknown standard");
                }

                // validate the intent segment itself
                try standard.validateIntentSegment(intent.intentData[i]) {}
                catch Error(string memory revertReason) {
                    revert FailedIntent(0, i, string.concat("AA62 reverted: ", revertReason));
                } catch {
                    revert FailedIntent(0, i, "AA62 reverted (or OOG)");
                }
            }
        }

        // validate signature
        bytes32 intentHash = _generateUserIntentHash(intent);
        _validateUserIntentWithAccount(intent, intentHash, 0, IAggregator(address(0)), bytes32(0));
    }

    /**
     * generate an intent Id - unique identifier for this intent.
     * the intent ID is a hash over the content of the intent (except the signature), the entrypoint and the chainid.
     */
    function getUserIntentHash(UserIntent calldata intent) external view returns (bytes32) {
        return _generateUserIntentHash(intent);
    }

    /**
     * returns true if the given standard is currently executing an intent segment for the msg.sender.
     */
    function verifyExecutingIntentSegmentForStandard(BaseIntentStandard intentStandard) external view returns (bool) {
        return _executionStateContext == msg.sender && _executionIntentStandard == address(intentStandard);
    }

    /**
     * Manually set the nonce of the sender.
     * @dev this method should only be allowed to be called by the currently executing intent standard contract
     */
    function _setNonce(uint256 key, uint256 nonce) internal override {
        require(msg.sender == _executionIntentStandard, "Invalid nonce access");
        nonceValues[_executionStateContext][key] = nonce;
    }
}
