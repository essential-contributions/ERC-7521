use ethers::{prelude::*, utils::parse_ether};
use scenarios::token_swaps::{constant_release_intent, constant_release_solver_intent};
use std::cmp::max;
use utils::setup::setup;
use utils::{
    abigen::entry_point::IntentSolution,
    builders::asset_based_intent_standard::curve_builder::{
        ConstantCurveParameters, CurveParameters, LinearCurveParameters,
    },
    setup::{sign_intent, PROVIDER},
};

#[tokio::test]
async fn token_swap_constant_release() {
    let artifacts = setup().await;
    let block_number: U256 = max(1, PROVIDER.get_block_number().await.unwrap().as_u64()).into();

    let solver_initial_eth_balance = PROVIDER
        .get_balance(artifacts.solver_wallet.address(), None)
        .await
        .unwrap();
    let user_initial_erc20_balance = artifacts
        .test_contracts
        .test_erc20
        .balance_of(artifacts.test_contracts.user_account.contract.address())
        .await;
    let erc20_release_amount = parse_ether(10).unwrap();
    let m = I256::from_raw(parse_ether(0.01).unwrap());
    let b = I256::from_raw(parse_ether(7).unwrap());
    let max = I256::from(100);

    let release_params: CurveParameters = CurveParameters::Constant(ConstantCurveParameters::new(
        I256::from_raw(erc20_release_amount),
    ));

    let require_params: CurveParameters =
        CurveParameters::Linear(LinearCurveParameters::new(m, b, max));

    let mut intent = constant_release_intent(
        &artifacts,
        artifacts.test_contracts.user_account.contract.address(),
        release_params,
        require_params.clone(),
    );
    intent = sign_intent(
        &artifacts.test_contracts,
        intent,
        artifacts.user_wallet.clone(),
    )
    .await;

    let evaluation: U256 = require_params.evaluate(block_number).into_raw();

    let solver_intent = constant_release_solver_intent(
        &artifacts,
        artifacts.solver_wallet.address(),
        artifacts.test_contracts.user_account.contract.address(),
        erc20_release_amount,
        evaluation,
    );

    let solution = IntentSolution::new(block_number, vec![intent, solver_intent], vec![]);

    artifacts
        .test_contracts
        .entry_point
        .handle_intents(solution)
        .await
        .unwrap();

    let solver_balance = PROVIDER
        .get_balance(artifacts.solver_wallet.address(), None)
        .await
        .unwrap();
    let expected_solver_balance =
        solver_initial_eth_balance + erc20_release_amount - evaluation + 5;
    assert_eq!(
        solver_balance, expected_solver_balance,
        "The solver ended up with incorrect balance"
    );

    let user_balance = PROVIDER
        .get_balance(
            artifacts.test_contracts.user_account.contract.address(),
            None,
        )
        .await
        .unwrap();
    let expected_user_balance = evaluation;
    assert_eq!(
        user_balance, expected_user_balance,
        "The user ended up with incorrect balance"
    );

    let user_erc20_tokens = artifacts
        .test_contracts
        .test_erc20
        .balance_of(artifacts.test_contracts.user_account.contract.address())
        .await;
    let expected_user_erc20_balance = user_initial_erc20_balance - erc20_release_amount;
    assert_eq!(
        user_erc20_tokens, expected_user_erc20_balance,
        "The user released more ERC20 tokens than expected"
    );
}
