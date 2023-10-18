use crate::wrappers::{
    abstract_account::AbstractAccountContract,
    entry_point::EntryPointContract,
    solver_utils::SolverUtilsContract,
    standards::{
        asset_release_intent_standard::AssetReleaseIntentStandardContract,
        asset_require_intent_standard::AssetRequireIntentStandardContract,
        call_intent_standard::CallIntentStandardContract,
        erc20_release_intent_standard::Erc20ReleaseIntentStandardContract,
        erc20_require_intent_standard::Erc20RequireIntentStandardContract,
        eth_release_intent_standard::EthReleaseIntentStandardContract,
        eth_require_intent_standard::EthRequireIntentStandardContract,
        user_operation::UserOperationContract,
    },
    test_erc1155::TestERC1155Contract,
    test_erc20::TestERC20Contract,
    test_erc721::TestERC721Contract,
    test_uniswap::TestUniswapContract,
    test_wrapped_native_token::TestWrappedNativeTokenContract,
};
use ethers::prelude::*;
use k256::ecdsa::SigningKey;
use std::sync::Arc;

pub struct TestContracts {
    pub entry_point: EntryPointContract,
    pub call_intent_standard: CallIntentStandardContract,
    pub asset_release_intent_standard: AssetReleaseIntentStandardContract,
    pub asset_require_intent_standard: AssetRequireIntentStandardContract,
    pub eth_release_intent_standard: EthReleaseIntentStandardContract,
    pub eth_require_intent_standard: EthRequireIntentStandardContract,
    pub erc20_release_intent_standard: Erc20ReleaseIntentStandardContract,
    pub erc20_require_intent_standard: Erc20RequireIntentStandardContract,
    pub user_operation: UserOperationContract,
    pub user_account: AbstractAccountContract,
    pub test_erc20: TestERC20Contract,
    pub test_erc721: TestERC721Contract,
    pub test_erc1155: TestERC1155Contract,
    pub test_wrapped_native_token: TestWrappedNativeTokenContract,
    pub test_uniswap: TestUniswapContract,
    pub solver_utils: SolverUtilsContract,
}

pub async fn deploy_all(
    client: Arc<SignerMiddleware<Provider<Http>, Wallet<SigningKey>>>,
) -> TestContracts {
    let entry_point = EntryPointContract::deploy(client.clone()).await;
    let call_intent_standard = CallIntentStandardContract::new(client.clone(), &entry_point).await;
    let asset_release_intent_standard =
        AssetReleaseIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let asset_require_intent_standard =
        AssetRequireIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let eth_release_intent_standard =
        EthReleaseIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let eth_require_intent_standard =
        EthRequireIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let erc20_release_intent_standard =
        Erc20ReleaseIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let erc20_require_intent_standard =
        Erc20RequireIntentStandardContract::deploy(client.clone(), &entry_point).await;
    let user_operation = UserOperationContract::deploy(client.clone(), &entry_point).await;
    let user_account = AbstractAccountContract::deploy(client.clone(), &entry_point).await;
    let test_erc20 = TestERC20Contract::deploy(client.clone()).await;
    let test_erc721 = TestERC721Contract::deploy(client.clone()).await;
    let test_erc1155 = TestERC1155Contract::deploy(client.clone()).await;
    let test_wrapped_native_token = TestWrappedNativeTokenContract::deploy(client.clone()).await;
    let test_uniswap =
        TestUniswapContract::deploy(client.clone(), test_wrapped_native_token.contract.address())
            .await;
    let solver_utils = SolverUtilsContract::deploy(
        client.clone(),
        test_uniswap.contract.address(),
        test_erc20.contract.address(),
        test_wrapped_native_token.contract.address(),
    )
    .await;

    TestContracts {
        entry_point,
        call_intent_standard,
        asset_release_intent_standard,
        asset_require_intent_standard,
        eth_release_intent_standard,
        eth_require_intent_standard,
        erc20_release_intent_standard,
        erc20_require_intent_standard,
        user_operation,
        user_account,
        test_erc20,
        test_erc721,
        test_erc1155,
        test_wrapped_native_token,
        test_uniswap,
        solver_utils,
    }
}
