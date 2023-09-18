use crate::{
    builders::{
        asset_based_intent_standard::{
            curve_builder::{
                ConstantCurveParameters, CurveParameters, EvaluationType, LinearCurveParameters,
            },
            intent_builder::IntentBuilder,
            segment_builder::SegmentBuilder,
        },
        solution_builder::SolutionBuilder,
    },
    deploy::{deploy_all, TestContracts},
    wrappers::client::WrappedClient,
};
use ethers::{
    prelude::*,
    utils::{parse_ether, Anvil},
};
use eyre::Result;
use std::{convert::TryFrom, sync::Arc, time::Duration};

pub async fn setup() -> Result<TestContracts> {
    let anvil = Anvil::new().spawn();
    let deployer_wallet: LocalWallet = anvil.keys()[0].clone().into();

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

    token_swap(&test_contracts).await.unwrap();

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

async fn token_swap(test_contracts: &TestContracts) -> Result<()> {
    let intent = constant_release_intent(test_contracts);
    let solver_intent = constant_release_solver_intent(test_contracts);
    let solution = SolutionBuilder::new(solver_intent, intent);

    let _ = test_contracts.entry_point.handle_intents(solution).await;

    Ok(())
}

fn constant_release_intent(test_contracts: &TestContracts) -> IntentBuilder {
    let mut constant_release_intent = IntentBuilder::create(
        test_contracts
            .asset_based_intent_standard
            .contract
            .address(),
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
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

    let release_erc20_segment = SegmentBuilder::new(0.into(), vec![])
        .release_erc20(test_contracts.test_erc20.contract.address(), release_params)
        .clone();

    let require_eth_segment = SegmentBuilder::new(0.into(), vec![])
        .require_eth(require_params, EvaluationType::RELATIVE)
        .clone();

    constant_release_intent.add_segment(release_erc20_segment);
    constant_release_intent.add_segment(require_eth_segment);

    constant_release_intent
}

fn constant_release_solver_intent(test_contracts: &TestContracts) -> IntentBuilder {
    let mut solution = IntentBuilder::create(
        test_contracts
            .asset_based_intent_standard
            .contract
            .address(),
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        0,
        0,
    );

    let solver_calldata = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_and_forward(&test_contracts);

    let solver_segment = SegmentBuilder::new(0.into(), solver_calldata.to_vec()).clone();
    solution.add_segment(solver_segment);

    solution
}
