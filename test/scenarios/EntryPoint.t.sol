// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */

import "./ScenarioTestEnvironment.sol";
import {_packValidationData} from "../../src/utils/Helpers.sol";

contract TestAbstractAccount is AbstractAccount {
    using ECDSA for bytes32;

    constructor(IEntryPoint entryPointAddr, IIntentStandard assetBasedIntentStandardAddr, address _owner)
        AbstractAccount(entryPointAddr, assetBasedIntentStandardAddr, _owner)
    {}

    function _validateSignature(UserIntent calldata intent, bytes32 intentHash)
        internal
        virtual
        override
        returns (uint256 validationData)
    {
        bytes32 hash = intentHash.toEthSignedMessageHash();
        if (owner != hash.recover(intent.signature)) {
            return _packValidationData(true, uint48(intent.timestamp), uint48(block.timestamp + 10));
        }
        return _packValidationData(false, uint48(intent.timestamp), uint48(block.timestamp + 10));
    }
}

contract HandleIntentsTest is ScenarioTestEnvironment {
    function test_fail_noIntents() public {
        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](1);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution =
            IEntryPoint.IntentSolution({timestamp: 0, intents: new UserIntent[](0), solutionSegments: solutionSegments});

        vm.expectRevert("AA70 no intents");
        _entryPoint.handleIntents(solution);
    }

    function test_fail_mismatchedStandards() public {
        UserIntent memory intentWithDifferentStandard = UserIntent({
            // intent with a different standard id
            standard: _intentStandard.standardId() << 1,
            sender: address(_account),
            nonce: 123,
            timestamp: block.timestamp,
            verificationGasLimit: 1000000,
            intentData: "",
            signature: ""
        });

        UserIntent[] memory intents = new UserIntent[](2);
        intents[0] = _intent();
        intents[1] = intentWithDifferentStandard;

        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](2);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        solutionSegments[1] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution =
            IEntryPoint.IntentSolution({timestamp: 0, intents: intents, solutionSegments: solutionSegments});

        vm.expectRevert("AA71 mismatched intent standards");
        _entryPoint.handleIntents(solution);
    }

    function test_fail_invalidTimestamp() public {
        UserIntent[] memory intents = new UserIntent[](1);
        intents[0] = _intent();

        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](1);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution = IEntryPoint.IntentSolution({
            // TIMESTAMP_MAX_OVER of EntryPoint.sol is 6
            timestamp: block.timestamp + 7,
            intents: intents,
            solutionSegments: solutionSegments
        });

        vm.expectRevert("AA81 invalid timestamp");
        _entryPoint.handleIntents(solution);
    }
}

contract ValidateUserIntentTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_fail_unknownStandard() public {
        UserIntent memory intent = _intent();

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        EntryPoint newEntryPoint = new EntryPoint();

        // call handleIntents from a different entry point
        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA83 unknown standard"));
        newEntryPoint.handleIntents(solution);
    }

    function test_fail_validateWithStandard() public {
        UserIntent memory intent = _intent();
        AssetBasedIntentSegment memory segment = _segment("").releaseETH(constantCurve(10));
        // invalidate curve params
        segment.assetReleases[0].params = new int256[](0);
        intent = intent.addSegment(segment);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA62 reverted: invalid curve params")
        );
        _entryPoint.handleIntents(solution);
    }

    function test_fail_validateWithAccount() public {
        UserIntent memory intent = _intent();

        // do not sign intent

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector, 0, 0, "AA23 reverted: ECDSA: invalid signature length"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    function test_fail_invalidNonce() public {
        // use wrong nonce while creating intent
        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 123, 0);
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA25 invalid account nonce"));
        _entryPoint.handleIntents(solution);
    }
}

contract ValidateAccountValidationDataTest is ScenarioTestEnvironment {
    using ECDSA for bytes32;

    function test_fail_signatureError() public {
        UserIntent memory intent = _intent();
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        // sign with wrong private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(12345, digest);
        intent.signature = abi.encodePacked(r, s, v);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA24 signature error"));
        _entryPoint.handleIntents(solution);
    }

    function test_fail_expired() public {
        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 0, block.timestamp);
        intent = _signIntent(intent);

        vm.warp(block.timestamp + 1);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);
    }

    function test_fail_notDue() public {
        uint256 _testPrivateKey = uint256(keccak256("test_account_private_key"));
        address _testPublicAddress = _getPublicAddress(_testPrivateKey);

        TestAbstractAccount _testAccount = new TestAbstractAccount(_entryPoint, _intentStandard, _testPublicAddress);

        UserIntent memory intent =
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_testAccount), 0, 0);
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        bytes32 digest = intentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_testPrivateKey, digest);
        intent.signature = abi.encodePacked(r, s, v);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA22 expired or not due"));
        _entryPoint.handleIntents(solution);
    }
}

contract ExecuteSolutionTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_failIntentExecution_withReason() public {
        UserIntent memory intent = _intent();
        intent = intent.addSegment(_segment("").requireETH(constantCurve(7 ether), false));
        intent = _signIntent(intent);

        IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

        vm.expectRevert(
            abi.encodeWithSelector(
                IEntryPoint.FailedIntent.selector,
                0,
                0,
                "AA61 execution failed: insufficient balance (required: 7000000000000000000, current: 0)"
            )
        );
        _entryPoint.handleIntents(solution);
    }

    // function test_failIntentExecution_withoutReason() public {
    //     UserIntent memory intent = _intent();
    //     intent = _signIntent(intent);

    //     IEntryPoint.IntentSolution memory solution = _solution(intent, _noSteps(), _noSteps(), _noSteps());

    //     vm.expectRevert(
    //         abi.encodeWithSelector(IEntryPoint.FailedIntent.selector, 0, 0, "AA61 execution failed (or OOG))")
    //     );
    //     _entryPoint.handleIntents(solution);
    // }

    // function test_fail_solutionExecution() public {
    //     _testERC20.mint(address(_account), 100 ether);
    //     vm.deal(address(_account), 100 ether);
    //     vm.warp(1000);

    //     UserIntent memory intent = _intent();
    //     intent = intent.addSegment(_segment("").releaseERC20(address(_testERC20), constantCurve(10 ether)));
    //     intent = intent.addSegment(_segment("").requireETH(linearCurve((3 ether) / 3000, 7 ether, 3000, true), true));
    //     intent = _signIntent(intent);

    //     // 1000 ether is too much to swap
    //     bytes[] memory steps =
    //         _solverSwapAllERC20ForETHAndForward(1000 ether, address(_publicAddressSolver), 9 ether, address(_account));
    //     IEntryPoint.IntentSolution memory solution = _solution(intent, steps, _noSteps(), _noSteps());

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEntryPoint.FailedSolution.selector,
    //             1,
    //             "AA72 execution failed: ERC20: transfer amount exceeds balance"
    //         )
    //     );
    //     _entryPoint.handleIntents(solution);
    // }
}

contract HandleMultiSolutionIntentsTest is ScenarioTestEnvironment {
// TODO
}

contract SimulateHandleIntents is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_fail_noIntents() public {
        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](1);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution =
            IEntryPoint.IntentSolution({timestamp: 0, intents: new UserIntent[](0), solutionSegments: solutionSegments});

        vm.expectRevert("AA70 no intents");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_mismatchedStandards() public {
        UserIntent memory intentWithDifferentStandard = UserIntent({
            // intent with a different standard id
            standard: _intentStandard.standardId() << 1,
            sender: address(_account),
            nonce: 123,
            timestamp: block.timestamp,
            verificationGasLimit: 1000000,
            intentData: "",
            signature: ""
        });

        UserIntent[] memory intents = new UserIntent[](2);
        intents[0] = _intent();
        intents[1] = intentWithDifferentStandard;

        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](2);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        solutionSegments[1] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution =
            IEntryPoint.IntentSolution({timestamp: 0, intents: intents, solutionSegments: solutionSegments});

        vm.expectRevert("AA71 mismatched intent standards");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }

    function test_fail_invalidTimestamp() public {
        UserIntent[] memory intents = new UserIntent[](1);
        intents[0] = _intent();

        IEntryPoint.SolutionSegment[] memory solutionSegments = new IEntryPoint.SolutionSegment[](1);
        solutionSegments[0] = IEntryPoint.SolutionSegment({callDataSteps: _noSteps()});
        IEntryPoint.IntentSolution memory solution = IEntryPoint.IntentSolution({
            // TIMESTAMP_MAX_OVER of EntryPoint.sol is 6
            timestamp: block.timestamp + 7,
            intents: intents,
            solutionSegments: solutionSegments
        });

        vm.expectRevert("AA81 invalid timestamp");
        _entryPoint.simulateHandleIntents(solution, block.timestamp, address(0), "");
    }
}

contract EntryPointTest is ScenarioTestEnvironment {
    using AssetBasedIntentBuilder for UserIntent;
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;
    using AssetBasedIntentSegmentBuilder for AssetBasedIntentSegment;

    function test_getUserIntentHash() public {
        UserIntent memory intent = _intent();
        bytes32 expectedHash = 0x3c6abf8f6b22adc8900ad3cfcfbc508d73c824ef733fb862ea26a28382544fe0;
        bytes32 intentHash = _entryPoint.getUserIntentHash(intent);
        assertEq(intentHash, expectedHash);
    }

    function test_registerIntentStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
        newEntryPoint.registerIntentStandard(newIntentStandard);
        bytes32 registeredStandardId =
            keccak256(abi.encodePacked(newIntentStandard, address(newEntryPoint), block.chainid));
        IIntentStandard registeredStandard = newEntryPoint.getIntentStandardContract(registeredStandardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(newIntentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failRegisterIntentStandard_invalidStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
        vm.expectRevert("AA80 invalid standard");
        _entryPoint.registerIntentStandard(newIntentStandard);
    }

    function test_failRegisterIntentStandard_alreadyRegistered() public {
        vm.expectRevert("AA82 already registered");
        _entryPoint.registerIntentStandard(_intentStandard);
    }

    function test_getIntentStandardContract() public {
        bytes32 standardId = _intentStandard.standardId();
        IIntentStandard registeredStandard = _entryPoint.getIntentStandardContract(standardId);
        bytes32 expectedHash = keccak256(abi.encode(IIntentStandard(_intentStandard)));
        bytes32 registeredHash = keccak256(abi.encode(registeredStandard));
        assertEq(registeredHash, expectedHash);
    }

    function test_failGetIntentStandardContract_unknownStandard() public {
        bytes32 standardId = _intentStandard.standardId();
        vm.expectRevert("AA83 unknown standard");
        _entryPoint.getIntentStandardContract(standardId << 1);
    }

    function test_getIntentStandardId() public {
        bytes32 standardId = _entryPoint.getIntentStandardId(_intentStandard);
        bytes32 expectedStandardId = _intentStandard.standardId();
        assertEq(standardId, expectedStandardId);
    }

    function test_failGetIntentStandardId_unknownStandard() public {
        EntryPoint newEntryPoint = new EntryPoint();
        AssetBasedIntentStandard newIntentStandard = new AssetBasedIntentStandard(newEntryPoint);
        vm.expectRevert("AA83 unknown standard");
        newEntryPoint.getIntentStandardId(newIntentStandard);
    }
}
