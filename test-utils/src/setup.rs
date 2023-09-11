use crate::{
    deploy::{deploy_all, TestContracts},
    wrappers::client::WrappedClient,
};
use ethers::{prelude::*, utils::Anvil};
use eyre::Result;
use std::{convert::TryFrom, sync::Arc, time::Duration};

pub async fn setup() -> Result<()> {
    let anvil = Anvil::new().spawn();
    let deployer_wallet: LocalWallet = anvil.keys()[0].clone().into();

    let provider =
        Provider::<Http>::try_from(anvil.endpoint())?.interval(Duration::from_millis(10u64));

    let client = SignerMiddleware::new(provider, deployer_wallet.with_chain_id(anvil.chain_id()));
    let client = WrappedClient {
        client: Arc::new(client),
    };

    let test_contracts = deploy_all(&client).await;
    let fund_amount = 1000 * (10 ^ 18);

    fund_exchange(&test_contracts, fund_amount).await.unwrap();

    Ok(())
}

async fn fund_exchange(test_contracts: &TestContracts, fund_amount: u128) -> Result<()> {
    test_contracts
        .test_erc20
        .mint(
            test_contracts.test_uniswap.contract.address(),
            U256::from(fund_amount),
        )
        .await;

    test_contracts
        .test_wrapped_native_token
        .deposit(fund_amount)
        .await;

    test_contracts
        .test_wrapped_native_token
        .transfer(
            test_contracts.test_uniswap.contract.address(),
            U256::from(fund_amount),
        )
        .await;

    Ok(())
}
