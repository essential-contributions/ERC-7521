use ethers::prelude::abigen;

abigen!(
    IntentSolutionLib,
    "../../../out/IntentSolution.sol/IntentSolutionLib.json"
);
abigen!(
    UserIntentLib,
    "../../../out/UserIntent.sol/UserIntentLib.json"
);
abigen!(RevertReason, "../../../out/Exec.sol/RevertReason.json");
abigen!(EntryPoint, "../../../out/EntryPoint.sol/EntryPoint.json");

abigen!(
    CallIntentStandard,
    "../../../out/CallIntentStandard.sol/CallIntentStandard.json"
);
abigen!(
    AssetReleaseIntentStandard,
    "../../../out/AssetReleaseIntentStandard.sol/AssetReleaseIntentStandard.json"
);
abigen!(
    AssetRequireIntentStandard,
    "../../../out/AssetRequireIntentStandard.sol/AssetRequireIntentStandard.json"
);
abigen!(
    EthReleaseIntentStandard,
    "../../../out/EthReleaseIntentStandard.sol/EthReleaseIntentStandard.json"
);
abigen!(
    EthRequireIntentStandard,
    "../../../out/EthRequireIntentStandard.sol/EthRequireIntentStandard.json"
);
abigen!(
    Erc20ReleaseIntentStandard,
    "../../../out/Erc20ReleaseIntentStandard.sol/Erc20ReleaseIntentStandard.json"
);
abigen!(
    Erc20RequireIntentStandard,
    "../../../out/Erc20RequireIntentStandard.sol/Erc20RequireIntentStandard.json"
);

abigen!(
    AbstractAccount,
    "../../../out/AbstractAccount.sol/AbstractAccount.json"
);
abigen!(TestERC20, "../../../out/TestERC20.sol/TestERC20.json");
abigen!(TestERC721, "../../../out/TestERC721.sol/TestERC721.json");
abigen!(TestERC1155, "../../../out/TestERC1155.sol/TestERC1155.json");
abigen!(
    TestWrappedNativeToken,
    "../../../out/TestWrappedNativeToken.sol/TestWrappedNativeToken.json"
);
abigen!(TestUniswap, "../../../out/TestUniswap.sol/TestUniswap.json");
abigen!(SolverUtils, "../../../out/SolverUtils.sol/SolverUtils.json");
