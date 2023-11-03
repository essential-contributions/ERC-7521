use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        curve_type::CurveParameters,
        evaluation_type::EvaluationType,
        intent_segment::IntentSegment,
        standards::{
            call_intent_standard::CallIntentSegment,
            erc20_release_intent_standard::Erc20ReleaseIntentSegment,
            eth_require_intent_standard::EthRequireIntentSegment,
            sequential_nonce::SequentialNonceSegment,
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
    let mut token_swap_intent = UserIntent::create(sender, 0);

    let release_erc20_segment = Erc20ReleaseIntentSegment::new(
        test_contracts.erc20_release_intent_standard.standard_id,
        test_contracts.test_erc20.contract.address(),
        release_params,
    );

    let require_eth_segment = EthRequireIntentSegment::new(
        test_contracts.eth_require_intent_standard.standard_id,
        require_params,
        EvaluationType::RELATIVE,
    );

    let sequential_nonce_segment =
        SequentialNonceSegment::new(test_contracts.sequential_nonce.standard_id, U256::from(1));

    token_swap_intent.add_segment(IntentSegment::Erc20Release(release_erc20_segment));
    token_swap_intent.add_segment(IntentSegment::EthRequire(require_eth_segment));
    token_swap_intent.add_segment(IntentSegment::SequentialNonce(sequential_nonce_segment));

    token_swap_intent
}

fn token_swap_solver_intent(
    test_contracts: &TestContracts,
    sender: Address,
    other: Address,
    erc20_release_amount: U256,
    evaluation: U256,
) -> UserIntent {
    let mut solution = UserIntent::create(test_contracts.solver_utils.contract.address(), 0);
    let solver_calldata = test_contracts
        .solver_utils
        .swap_erc20_for_eth_and_forward_calldata(
            test_contracts,
            sender,
            other,
            erc20_release_amount,
            evaluation,
        );

    let solver_segment = CallIntentSegment::new(
        test_contracts.call_intent_standard.standard_id,
        solver_calldata,
    );
    solution.add_segment(IntentSegment::Call(solver_segment));

    solution
}
