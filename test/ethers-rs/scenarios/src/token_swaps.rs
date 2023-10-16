use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        curve_type::CurveParameters,
        evaluation_type::EvaluationType,
        standards::{
            call_intent_standard::CallIntentSegment,
            erc20_release_intent_standard::Erc20ReleaseIntentSegment,
            eth_require_intent_standard::EthRequireIntentSegment,
        },
    },
    deploy::TestContracts,
    setup::{setup, sign_intent, PROVIDER, SOLVER_WALLET, USER_WALLET},
};

pub async fn token_swap_scenario(
    release_parameters: CurveParameters,
    require_parameters: CurveParameters,
    block_number: U256,
    release_evaluation: U256,
    require_evaluation: U256,
) -> TestBalances {
    // setup
    let test_contracts = setup().await;

    // record initial balances
    let mut test_balances = TestBalances::default();

    test_balances.user.eth.initial = Some(
        PROVIDER
            .get_balance(test_contracts.user_account.contract.address(), None)
            .await
            .unwrap(),
    );

    test_balances.solver.eth.initial = Some(
        PROVIDER
            .get_balance(SOLVER_WALLET.address(), None)
            .await
            .unwrap(),
    );

    test_balances.user.erc20.initial = Some(
        test_contracts
            .test_erc20
            .balance_of(test_contracts.user_account.contract.address())
            .await,
    );

    // create user intent
    let mut intent = token_swap_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        release_parameters.clone(),
        require_parameters.clone(),
    );
    intent = sign_intent(&test_contracts, intent, USER_WALLET.clone()).await;

    // create solver intent
    let solver_intent = token_swap_solver_intent(
        &test_contracts,
        SOLVER_WALLET.address(),
        test_contracts.user_account.contract.address(),
        release_evaluation,
        require_evaluation,
    );

    // create intent solution
    let solution = IntentSolution::new(block_number, vec![intent, solver_intent], vec![]);

    // call handle intents
    test_contracts
        .entry_point
        .handle_intents(solution)
        .await
        .unwrap();

    // record final balances
    test_balances.solver.eth.r#final = Some(
        PROVIDER
            .get_balance(SOLVER_WALLET.address(), None)
            .await
            .unwrap(),
    );
    test_balances.user.eth.r#final = Some(
        PROVIDER
            .get_balance(test_contracts.user_account.contract.address(), None)
            .await
            .unwrap(),
    );
    test_balances.user.erc20.r#final = Some(
        test_contracts
            .test_erc20
            .balance_of(test_contracts.user_account.contract.address())
            .await,
    );

    test_balances
}

fn token_swap_intent(
    test_contracts: &TestContracts,
    sender: Address,
    release_params: CurveParameters,
    require_params: CurveParameters,
) -> UserIntent {
    let mut token_swap_intent = UserIntent::create(sender, 0, 0);

    let release_erc20_segment = Erc20ReleaseIntentSegment::new(
        test_contracts.test_erc20.contract.address(),
        release_params,
    )
    .clone();

    let require_eth_segment =
        EthRequireIntentSegment::new(require_params, EvaluationType::RELATIVE);

    token_swap_intent.add_segment_erc20_release(
        test_contracts
            .erc20_release_intent_standard
            .standard_id
            .clone(),
        release_erc20_segment,
    );

    token_swap_intent.add_segment_eth_require(
        test_contracts
            .eth_require_intent_standard
            .standard_id
            .clone(),
        require_eth_segment,
    );

    token_swap_intent
}

fn token_swap_solver_intent(
    test_contracts: &TestContracts,
    sender: Address,
    other: Address,
    erc20_release_amount: U256,
    evaluation: U256,
) -> UserIntent {
    let mut solution = UserIntent::create(test_contracts.solver_utils.contract.address(), 0, 0);
    let solver_calldata = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_and_forward_calldata(
            test_contracts,
            sender,
            other,
            erc20_release_amount,
            evaluation,
        );

    let solver_segment = CallIntentSegment::new(solver_calldata);
    solution.add_segment_call(
        test_contracts.call_intent_standard.standard_id.clone(),
        solver_segment,
    );

    solution
}
