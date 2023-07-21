// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import "../utils/AssetBasedIntentBuilder.sol";
import "../../src/core/EntryPoint.sol";
import "../../src/wallet/AbstractAccount.sol";
import "../../src/standards/assetbased/AssetBasedIntentStandard.sol";
import "../../src/test/TestERC20.sol";
import "../../src/test/TestERC721.sol";
import "../../src/test/TestERC1155.sol";
import "../../src/test/TestUniswap.sol";
import "../../src/test/TestWrappedNativeToken.sol";

abstract contract ScenarioTestEnvironment is Test {
    using UserIntentLib for UserIntent;
    using ECDSA for bytes32;

    EntryPoint internal _entryPoint;
    AssetBasedIntentStandard internal _intentStandard;
    AbstractAccount internal _account;

    TestERC20 internal _testERC20;
    TestERC721 internal _testERC721;
    TestERC1155 internal _testERC1155;
    TestUniswap internal _testUniswap;
    TestWrappedNativeToken internal _testWrappedNativeToken;

    uint256 internal constant _privateKey = 0x0ea23cd08ccb92dd31e14f9b238b4367f8e96715780d0f6295a43141d14f8df9;
    address internal _publicAddress = _getPublicAddress(_privateKey);

    uint256 internal constant _privateKeySolver = 0x295a43141d14f8df90ea23cd08ccb92dd31e14f9b238b4367f8e96715780d0f6;
    address internal _publicAddressSolver = _getPublicAddress(_privateKeySolver);

    /**
     * Sets up the testing environment with mock tokens and AMMs.
     */
    function setUp() public virtual {
        //deploy contracts
        _entryPoint = new EntryPoint();
        _intentStandard = new AssetBasedIntentStandard(_entryPoint);
        _account = new AbstractAccount(_entryPoint, _publicAddress);

        _testERC20 = new TestERC20();
        _testERC721 = new TestERC721();
        _testERC1155 = new TestERC1155();
        _testWrappedNativeToken = new TestWrappedNativeToken();
        _testUniswap = new TestUniswap(_testWrappedNativeToken);

        //fund exchange
        _testERC20.mint(address(_testUniswap), 1000 ether);
        _mintWrappedNativeToken(address(_testUniswap), 1000 ether);
    }

    /**
     * Private helper function to quickly mint wrapped native tokens.
     */
    function _mintWrappedNativeToken(address to, uint256 amount) internal {
        vm.deal(address(this), amount);
        _testWrappedNativeToken.deposit{value: amount}();
        _testWrappedNativeToken.transfer(to, amount);
    }

    /**
     * Private helper function to build call data for the account buying an ERC721 NFT.
     */
    function _accountBuyERC721(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC721.buyNFT.selector, address(_account));
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC721, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account buying an ERC1155 NFT.
     */
    function _accountBuyERC1155(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC1155.buyNFT.selector, address(_account));
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC1155, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account claiming an ERC20 airdrop.
     */
    function _accountClaimAirdropERC20(uint256 amount) internal view returns (bytes memory) {
        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), amount);
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC20, 0, mintCall);
    }

    /**
     * Private helper function to build solver solution steps for swapping tokens.
     */
    function _solverSwapERC20ForETH(uint256 amountERC20, uint256 amountETH, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (IEntryPoint.SolutionStep[] memory)
    {
        address tokenHolder = address(_intentStandard);
        bytes memory callFromEntryPoint;
        bytes memory callFromTokenHolder;
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](5);

        //set token approvals for "uniswap"
        callFromEntryPoint = abi.encodeWithSelector(
            AssetHolderProxy.setApprovalForAll.selector,
            AssetType.ERC20,
            address(_testERC20),
            uint256(0),
            address(_testUniswap),
            true
        );
        steps[0] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: callFromEntryPoint});

        //swap ERC20 for wrapped native token
        ExactInputSingleParams memory swapParams = ExactInputSingleParams({
            tokenIn: address(_testERC20),
            tokenOut: address(_testWrappedNativeToken),
            fee: uint24(0),
            recipient: tokenHolder,
            deadline: uint256(0),
            amountIn: amountERC20,
            amountOutMinimum: amountETH,
            sqrtPriceLimitX96: uint160(0)
        });
        callFromEntryPoint = abi.encodeWithSelector(TestUniswap.exactInputSingle.selector, swapParams);
        callFromTokenHolder =
            abi.encodeWithSelector(AssetHolderProxy.execute.selector, address(_testUniswap), 0, callFromEntryPoint);
        steps[1] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: callFromTokenHolder});

        //unwrap to native tokens for forwarding
        callFromEntryPoint = abi.encodeWithSelector(TestWrappedNativeToken.withdraw.selector, forwardAmount);
        callFromTokenHolder = abi.encodeWithSelector(
            AssetHolderProxy.execute.selector, address(_testWrappedNativeToken), 0, callFromEntryPoint
        );
        steps[2] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: callFromTokenHolder});

        //forward the native tokens
        callFromEntryPoint = abi.encodeWithSelector(
            AssetHolderProxy.transfer.selector, AssetType.ETH, address(0), uint256(0), forwardTo, forwardAmount
        );
        steps[3] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: callFromEntryPoint});

        //sweep remaining tokens to solvers address
        callFromEntryPoint = abi.encodeWithSelector(
            AssetHolderProxy.transferAll.selector,
            AssetType.ERC20,
            address(_testWrappedNativeToken),
            uint256(0),
            _publicAddressSolver
        );
        steps[4] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: callFromEntryPoint});

        return steps;
    }

    /**
     * Private helper function to build an asset based intent struct.
     */
    function _createIntent(bytes memory callData1, bytes memory callData2) internal view returns (UserIntent memory) {
        return AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 0, callData1, callData2);
    }

    /**
     * Private helper function to build an intent solution struct.
     */
    function _createSolution(
        UserIntent memory userIntent,
        IEntryPoint.SolutionStep[] memory steps1,
        IEntryPoint.SolutionStep[] memory steps2
    ) internal pure returns (IEntryPoint.IntentSolution memory) {
        UserIntent[] memory userIntents = new UserIntent[](1);
        userIntents[0] = userIntent;
        return IEntryPoint.IntentSolution({userIntents: userIntents, steps1: steps1, steps2: steps2});
    }

    /**
     * Private helper function to add account owner signature to an intent.
     */
    function _signIntent(UserIntent memory userIntent) internal pure returns (UserIntent memory) {
        bytes32 userIntentHash = userIntent.hash();
        bytes32 digest = userIntentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        userIntent.signature = abi.encodePacked(r, s, v);
        return userIntent;
    }

    /**
     * Private helper function to get the public address of a private key.
     */
    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }
}
