// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* solhint-disable func-name-mixedcase */
/* solhint-disable const-name-snakecase */

import "forge-std/Test.sol";
import "../AssetBasedIntentBuilder.sol";
import "../../src/core/EntryPoint.sol";
import "../../src/wallet/AbstractAccount.sol";
import "../../src/standards/assetbased/AssetBasedIntentStandard.sol";
import "../../src/test/TestERC20.sol";
import "../../src/test/TestERC721.sol";
import "../../src/test/TestERC1155.sol";
import "../../src/test/TestUniswap.sol";
import "../../src/test/TestWrappedNativeToken.sol";
import "../../src/test/SolverUtils.sol";

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
    SolverUtils internal _solverUtils;

    uint256 internal constant _privateKey = uint256(keccak256("account_private_key"));
    address internal _publicAddress = _getPublicAddress(_privateKey);

    uint256 internal constant _privateKeySolver = uint256(keccak256("solver_private_key"));
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
        _solverUtils = new SolverUtils();

        //fund exchange
        _testERC20.mint(address(_testUniswap), 1000 ether);
        _mintWrappedNativeToken(address(_testUniswap), 1000 ether);
    }

    /**
     * Private helper function to quickly mint wrapped native tokens.
     * @param to The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function _mintWrappedNativeToken(address to, uint256 amount) internal {
        vm.deal(address(this), amount);
        _testWrappedNativeToken.deposit{value: amount}();
        _testWrappedNativeToken.transfer(to, amount);
    }

    /**
     * Private helper function to build call data for the account buying an ERC721 NFT.
     * @param price The price of the ERC721 NFT to buy.
     * @return The encoded call data for the buy action.
     */
    function _accountBuyERC721(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC721.buyNFT.selector, address(_account));
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC721, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account buying an ERC1155 NFT.
     * @param price The price of the ERC1155 NFT to buy.
     * @return The encoded call data for the buy action.
     */
    function _accountBuyERC1155(uint256 price) internal view returns (bytes memory) {
        bytes memory buyCall = abi.encodeWithSelector(TestERC1155.buyNFT.selector, address(_account));
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC1155, price, buyCall);
    }

    /**
     * Private helper function to build call data for the account buying an ERC1155 NFT and then transferring an ERC721.
     * @param price The price of the ERC1155 NFT to buy.
     * @param transferAssetId The ID of the ERC721 token to transfer after buying the ERC1155.
     * @param transferTo The address to transfer the ERC721 token to.
     * @return The encoded call data for the buy and transfer actions.
     */
    function _accountBuyERC1155AndTransferERC721(uint256 price, uint256 transferAssetId, address transferTo)
        internal
        view
        returns (bytes memory)
    {
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory datas = new bytes[](2);

        targets[0] = address(_testERC1155);
        datas[0] = abi.encodeWithSelector(TestERC1155.buyNFT.selector, address(_account));
        values[0] = price;

        targets[1] = address(_testERC721);
        datas[1] = abi.encodeWithSelector(
            IERC721.transferFrom.selector, address(_account), address(transferTo), transferAssetId
        );

        return abi.encodeWithSelector(AbstractAccount.executeMulti.selector, targets, values, datas);
    }

    /**
     * Private helper function to build call data for the account claiming an ERC20 airdrop.
     * @param amount The amount of ERC20 tokens to claim in the airdrop.
     * @return The encoded call data for the claim airdrop action.
     */
    function _accountClaimAirdropERC20(uint256 amount) internal view returns (bytes memory) {
        bytes memory mintCall = abi.encodeWithSelector(TestERC20.mint.selector, address(_account), amount);
        return abi.encodeWithSelector(AbstractAccount.execute.selector, _testERC20, 0, mintCall);
    }

    /**
     * Private helper function to build solver solution steps approving token transfer for swaps.
     * @return The array of solution steps for token approvals.
     */
    function _solverApproveERC20() internal view returns (IEntryPoint.SolutionStep[] memory) {
        address tokenHolder = address(_intentStandard);
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](1);

        //set token approvals for "uniswap"
        bytes memory approvalCall = abi.encodeWithSelector(
            AssetHolderProxy.setApprovalForAll.selector,
            AssetType.ERC20,
            address(_testERC20),
            uint256(0),
            address(_testUniswap),
            true
        );
        steps[0] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: approvalCall});

        return steps;
    }

    /**
     * Private helper function to build solver solution steps for swapping tokens.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param to The address to receive the swapped ETH.
     * @return The array of solution steps for swapping tokens.
     */
    function _solverSwapAllERC20ForETH(uint256 minETH, address to)
        internal
        view
        returns (IEntryPoint.SolutionStep[] memory)
    {
        address tokenHolder = address(_intentStandard);
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](2);

        //set token approvals for "uniswap"
        steps[0] = _solverApproveERC20()[0];

        //swap to eth and forward part of it using the solver util library
        bytes memory swapCall = abi.encodeWithSelector(
            SolverUtils.swapAllERC20ForETH.selector, _testUniswap, _testERC20, _testWrappedNativeToken, minETH, to
        );
        bytes memory delegateSwapAndForwardCall =
            abi.encodeWithSelector(AssetHolderProxy.delegate.selector, address(_solverUtils), swapCall);
        steps[1] =
            IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: delegateSwapAndForwardCall});

        return steps;
    }

    /**
     * Private helper function to build solver solution steps for swapping tokens and forwarding some ETH.
     * @param minETH The minimum amount of ETH to be received after the swap.
     * @param to The address to receive the swapped ETH.
     * @param forwardAmount The amount of ETH to forward to another address.
     * @param forwardTo The address to forward the ETH to.
     * @return The array of solution steps for swapping tokens and forwarding ETH.
     */
    function _solverSwapAllERC20ForETHAndForward(uint256 minETH, address to, uint256 forwardAmount, address forwardTo)
        internal
        view
        returns (IEntryPoint.SolutionStep[] memory)
    {
        address tokenHolder = address(_intentStandard);
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](2);

        //set token approvals for "uniswap"
        steps[0] = _solverApproveERC20()[0];

        //swap to eth and forward part of it using the solver util library
        bytes memory swapAndForwardCall = abi.encodeWithSelector(
            SolverUtils.swapAllERC20ForETHAndForward.selector,
            _testUniswap,
            _testERC20,
            _testWrappedNativeToken,
            minETH,
            to,
            forwardAmount,
            forwardTo
        );
        bytes memory delegateSwapAndForwardCall =
            abi.encodeWithSelector(AssetHolderProxy.delegate.selector, address(_solverUtils), swapAndForwardCall);
        steps[1] =
            IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: delegateSwapAndForwardCall});

        return steps;
    }

    /**
     * Private helper function to build solver solution steps for buying and forwarding an ERC721 token.
     * @param price The price of the ERC721 token to buy.
     * @param forwardTo The address to forward the purchased ERC721 token to.
     * @return The array of solution steps for buying and forwarding an ERC721 token.
     */
    function _solverBuyERC721AndForward(uint256 price, address forwardTo)
        internal
        view
        returns (IEntryPoint.SolutionStep[] memory)
    {
        address tokenHolder = address(_intentStandard);
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](1);

        //buy the ERC721 token and forward
        bytes memory buyAndForwardCall =
            abi.encodeWithSelector(SolverUtils.buyERC721.selector, _testERC721, price, forwardTo);
        bytes memory delegateBuyAndForwardCall =
            abi.encodeWithSelector(AssetHolderProxy.delegate.selector, address(_solverUtils), buyAndForwardCall);
        steps[0] =
            IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: delegateBuyAndForwardCall});

        return steps;
    }

    /**
     * Private helper function to build solver solution steps for selling an ERC721 token and forwarding ETH.
     * @param tokenId The ID of the ERC721 token to sell.
     * @param forwardTo The address to forward the received ETH to.
     * @return The array of solution steps for selling an ERC721 token and forwarding ETH.
     */
    function _solverSellERC721AndForward(uint256 tokenId, address forwardTo)
        internal
        view
        returns (IEntryPoint.SolutionStep[] memory)
    {
        address tokenHolder = address(_intentStandard);
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](2);

        //sell the ERC721 token
        bytes memory sellCall = abi.encodeWithSelector(TestERC721.sellNFT.selector, address(_intentStandard), tokenId);
        bytes memory executeSellCall =
            abi.encodeWithSelector(AssetHolderProxy.execute.selector, address(_testERC721), 0, sellCall);
        steps[0] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: executeSellCall});

        //move all remaining ETH
        bytes memory transferAllCall = abi.encodeWithSelector(
            AssetHolderProxy.transferAll.selector, AssetType.ETH, address(0), uint256(0), forwardTo
        );
        steps[1] = IEntryPoint.SolutionStep({target: tokenHolder, value: uint256(0), callData: transferAllCall});

        return steps;
    }

    /**
     * Private helper function to build an asset-based intent struct.
     * @param callData1 The encoded call data for the first pass of the intent.
     * @param callData2 The encoded call data for the second pass of the intent.
     * @return The created UserIntent struct.
     */
    function _createIntent(bytes memory callData1, bytes memory callData2) internal view returns (UserIntent memory) {
        return
            AssetBasedIntentBuilder.create(_intentStandard.standardId(), address(_account), 0, 0, callData1, callData2);
    }

    /**
     * Private helper function to build an intent solution struct.
     * @param userIntent The UserIntent struct representing the user's intent.
     * @param steps1 The array of solution steps for the first pass.
     * @param steps2 The array of solution steps for the second pass.
     * @return The created IntentSolution struct.
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
     * Private helper function to add the account owner's signature to an intent.
     * @param userIntent The UserIntent struct representing the user's intent.
     * @return The UserIntent struct with the added signature.
     */
    function _signIntent(UserIntent memory userIntent) internal pure returns (UserIntent memory) {
        bytes32 userIntentHash = userIntent.hash();
        bytes32 digest = userIntentHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, digest);
        userIntent.signature = abi.encodePacked(r, s, v);
        return userIntent;
    }

    /**
     * Private helper function to combine solution steps.
     * @param a The array of solution steps for the first action.
     * @param b The array of solution steps for the second action.
     * @return The combined array of solution steps.
     */
    function _combineSolutionSteps(IEntryPoint.SolutionStep[] memory a, IEntryPoint.SolutionStep[] memory b)
        internal
        pure
        returns (IEntryPoint.SolutionStep[] memory)
    {
        IEntryPoint.SolutionStep[] memory steps = new IEntryPoint.SolutionStep[](a.length + b.length);
        for (uint256 i = 0; i < a.length; i++) {
            steps[i] = a[i];
        }
        for (uint256 i = 0; i < b.length; i++) {
            steps[a.length + i] = b[i];
        }
        return steps;
    }

    /**
     * Private helper function to get the public address of a private key.
     * @param privateKey The private key to derive the public address from.
     * @return The derived public address.
     */
    function _getPublicAddress(uint256 privateKey) internal pure returns (address) {
        bytes32 digest = keccak256(abi.encodePacked("test data"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return ecrecover(digest, v, r, s);
    }
}
