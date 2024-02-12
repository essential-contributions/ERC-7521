// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {BaseAccount} from "../core/BaseAccount.sol";
import {IAggregator} from "../interfaces/IAggregator.sol";
import {IEntryPoint} from "../interfaces/IEntryPoint.sol";
import {IIntentDelegate} from "../interfaces/IIntentDelegate.sol";
import {UserIntent, UserIntentLib} from "../interfaces/UserIntent.sol";
import {Exec} from "../utils/Exec.sol";

/**
 * Minimal BLS-based account that uses an aggregated signature.
 * The account must maintain its own BLS public key, and expose its trusted signature aggregator.
 */
contract TestAggregationAccount is BaseAccount {
    using UserIntentLib for UserIntent;

    IEntryPoint private immutable _entryPoint;
    IAggregator private immutable _aggregator;

    constructor(IEntryPoint anEntryPoint, IAggregator anAggregator) {
        _entryPoint = anEntryPoint;
        _aggregator = anAggregator;
    }

    /// @inheritdoc BaseAccount
    function entryPoint() public view virtual override returns (IEntryPoint) {
        return _entryPoint;
    }

    /**
     * Validate user's intent (typically a signature)
     */
    function validateUserIntent(UserIntent calldata, bytes32) external view override returns (IAggregator) {
        _requireFromEntryPoint();
        return _aggregator;
    }

    /**
     * execute a transaction (called directly from owner, or by entryPoint)
     */
    function execute(address dest, uint256 value, bytes calldata func) external {
        _requireFromIntentStandardExecutingForSender();
        _call(dest, value, func);
    }

    /**
     * execute a sequence of transactions
     * @dev to reduce gas consumption for trivial case (no value), use a zero-length array to mean zero value
     */
    function executeBatch(address[] calldata dest, uint256[] calldata value, bytes[] calldata func) external {
        _requireFromIntentStandardExecutingForSender();
        require(
            dest.length == func.length && (value.length == 0 || value.length == func.length),
            "wrong batch array lengths"
        );
        if (value.length == 0) {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], 0, func[i]);
            }
        } else {
            for (uint256 i = 0; i < dest.length; i++) {
                _call(dest[i], value[i], func[i]);
            }
        }
    }

    function _call(address target, uint256 value, bytes memory data) internal {
        bool success = Exec.call(target, value, data, gasleft());
        if (!success) Exec.forwardRevert(Exec.REVERT_REASON_MAX_LEN);
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
