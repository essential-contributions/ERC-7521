use crate::{
    abigen::entry_point::UserIntent,
    deploy::{deploy_all, TestContracts},
};
use ethers::{
    abi::FixedBytes,
    prelude::*,
    utils::{parse_ether, Anvil, AnvilInstance},
};
use eyre::Result;
use std::{convert::TryFrom, sync::Arc, time::Duration};

static ANVIL: Lazy<AnvilInstance> = Lazy::new(|| Anvil::new().spawn());
pub static DEPLOYER_WALLET: Lazy<LocalWallet> = Lazy::new(|| ANVIL.keys()[0].clone().into());
pub static USER_WALLET: Lazy<LocalWallet> = Lazy::new(|| ANVIL.keys()[1].clone().into());
pub static SOLVER_WALLET: Lazy<LocalWallet> = Lazy::new(|| ANVIL.keys()[2].clone().into());
pub static PROVIDER: Lazy<Provider<Http>> = Lazy::new(|| {
    Provider::<Http>::try_from(ANVIL.endpoint())
        .unwrap()
        .interval(Duration::from_millis(10u64))
});

pub async fn setup() -> TestContracts {
    let test_contracts = deploy_all(Arc::new(SignerMiddleware::new(
        PROVIDER.clone(),
        DEPLOYER_WALLET.clone().with_chain_id(ANVIL.chain_id()),
    )))
    .await;

    fund_exchange(&test_contracts, parse_ether(1000).unwrap())
        .await
        .unwrap();

    fund_account_erc20(&test_contracts, parse_ether(100).unwrap())
        .await
        .unwrap();

    test_contracts
}

async fn fund_exchange(test_contracts: &TestContracts, fund_amount: U256) -> Result<()> {
    test_contracts
        .test_erc20
        .mint(test_contracts.test_uniswap.contract.address(), fund_amount)
        .await;

    test_contracts
        .test_wrapped_native_token
        .deposit(fund_amount.as_u128())
        .await;

    test_contracts
        .test_wrapped_native_token
        .transfer(test_contracts.test_uniswap.contract.address(), fund_amount)
        .await;

    Ok(())
}

pub async fn fund_account_erc20(
    test_contracts: &TestContracts,
    erc20_fund_amount: U256,
) -> Result<()> {
    test_contracts
        .test_erc20
        .mint(
            test_contracts.user_account.contract.address(),
            erc20_fund_amount,
        )
        .await;

    Ok(())
}

pub async fn sign_intent(
    test_contracts: &TestContracts,
    mut intent: UserIntent,
    signer: LocalWallet,
) -> UserIntent {
    let intent_hash: FixedBytes = test_contracts
        .entry_point
        .contract
        .get_user_intent_hash(intent.clone())
        .call()
        .await
        .unwrap()
        .to_vec();

    let signature = signer.sign_message(intent_hash).await.unwrap();

    intent.signature = signature.to_vec().into();

    intent
}
