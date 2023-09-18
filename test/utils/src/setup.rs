use crate::{
    abigen::{entry_point::IntentSolution, entry_point::UserIntent},
    builders::asset_based_intent_standard::{
        curve_builder::{
            ConstantCurveParameters, CurveParameters, EvaluationType, LinearCurveParameters,
        },
        segment_builder::AssetBasedIntentSegment,
    },
    deploy::{deploy_all, TestContracts},
    wrappers::client::WrappedClient,
};
use ethers::{
    abi::FixedBytes,
    prelude::*,
    utils::{parse_ether, Anvil},
};
use eyre::Result;
use std::{convert::TryFrom, sync::Arc, time::Duration};

pub async fn setup() -> Result<TestContracts> {
    let anvil = Anvil::new().spawn();
    let deployer_wallet: LocalWallet = anvil.keys()[0].clone().into();
    let user_wallet: LocalWallet = anvil.keys()[1].clone().into();
    let solver_wallet: LocalWallet = anvil.keys()[2].clone().into();

    let provider = Provider::<Http>::try_from(anvil.endpoint())
        .unwrap()
        .interval(Duration::from_millis(10u64));

    let client = SignerMiddleware::new(provider, deployer_wallet.with_chain_id(anvil.chain_id()));
    let client = WrappedClient {
        client: Arc::new(client),
    };

    let test_contracts = deploy_all(&client).await;
    let fund_amount = parse_ether(1000).unwrap();

    fund_exchange(&test_contracts, fund_amount).await.unwrap();

    token_swap(&test_contracts, user_wallet, solver_wallet)
        .await
        .unwrap();

    Ok(test_contracts)
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

async fn token_swap(
    test_contracts: &TestContracts,
    user_wallet: LocalWallet,
    solver_wallet: LocalWallet,
) -> Result<()> {
    let mut intent = constant_release_intent(test_contracts, user_wallet.address());
    intent = sign_intent(test_contracts, intent, user_wallet).await;

    let mut solver_intent = constant_release_solver_intent(test_contracts, solver_wallet.address());
    solver_intent = sign_intent(test_contracts, solver_intent, solver_wallet).await;

    let solution = IntentSolution::new(solver_intent, intent);

    let _ = test_contracts.entry_point.handle_intents(solution).await;

    Ok(())
}

fn constant_release_intent(test_contracts: &TestContracts, sender: Address) -> UserIntent {
    let mut constant_release_intent = UserIntent::create(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        sender,
        0,
        0,
    );

    let release_params: CurveParameters = CurveParameters::Constant(ConstantCurveParameters::new(
        I256::from_raw(parse_ether(1).unwrap()),
    ));

    let require_params: CurveParameters = CurveParameters::Linear(LinearCurveParameters::new(
        I256::from_raw(parse_ether(0.001).unwrap()),
        I256::from_raw(parse_ether(7).unwrap()),
        I256::from(3000),
    ));

    let release_erc20_segment = AssetBasedIntentSegment::new(0.into(), vec![])
        .release_erc20(test_contracts.test_erc20.contract.address(), release_params)
        .clone();

    let require_eth_segment = AssetBasedIntentSegment::new(0.into(), vec![])
        .require_eth(require_params, EvaluationType::RELATIVE)
        .clone();

    constant_release_intent.add_segment(release_erc20_segment);
    constant_release_intent.add_segment(require_eth_segment);

    constant_release_intent
}

fn constant_release_solver_intent(test_contracts: &TestContracts, sender: Address) -> UserIntent {
    let mut solution = UserIntent::create(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        sender,
        0,
        0,
    );

    let solver_calldata = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_and_forward(&test_contracts);

    let solver_segment = AssetBasedIntentSegment::new(0.into(), vec![solver_calldata]).clone();
    solution.add_segment(solver_segment);

    solution
}

async fn sign_intent(
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
