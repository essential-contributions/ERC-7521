use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        curve_type::{ConstantCurveParameters, CurveParameters},
        evaluation_type::EvaluationType,
        intent_segment::IntentSegment,
        standards::{
            call_intent_standard::CallIntentSegment,
            erc20_release_intent_standard::Erc20ReleaseIntentSegment,
            erc20_require_intent_standard::Erc20RequireIntentSegment,
        },
    },
    deploy::TestContracts,
    setup::{setup, sign_intent, PROVIDER, SOLVER_WALLET, USER_WALLET},
};

pub async fn transfer_erc20_scenario(
    release_parameters: CurveParameters,
    require_parameters: CurveParameters,
    transfer_amount: U256,
    block_number: U256,
    release_evaluation: U256,
) -> TestBalances {
    // setup
    let test_contracts = setup().await;

    // record initial balances
    let mut test_balances = TestBalances::default();

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

    test_balances.recipient.erc20.initial = Some(
        test_contracts
            .test_erc20
            .balance_of(USER_WALLET.address())
            .await,
    );

    // create user intent
    let mut intent = transfer_erc20_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        release_parameters.clone(),
        CurveParameters::Constant(ConstantCurveParameters::new(I256::from_raw(
            transfer_amount,
        ))),
        require_parameters.clone(),
    );
    intent = sign_intent(&test_contracts, intent, USER_WALLET.clone()).await;

    // create solver intent
    let solver_intent = transfer_erc20_solver_intent(
        &test_contracts,
        SOLVER_WALLET.address(),
        release_evaluation,
        transfer_amount,
        USER_WALLET.address(),
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

    test_balances.user.erc20.r#final = Some(
        test_contracts
            .test_erc20
            .balance_of(test_contracts.user_account.contract.address())
            .await,
    );

    test_balances.recipient.erc20.r#final = Some(
        test_contracts
            .test_erc20
            .balance_of(USER_WALLET.address())
            .await,
    );

    test_balances
}

fn transfer_erc20_intent(
    test_contracts: &TestContracts,
    sender: Address,
    erc20_release_params: CurveParameters,
    erc20_transfer_params: CurveParameters,
    erc20_require_params: CurveParameters,
) -> UserIntent {
    let mut transfer_erc20_intent = UserIntent::create(sender, 0, 0);

    let release_erc20_segment = Erc20ReleaseIntentSegment::new(
        test_contracts.erc20_release_intent_standard.standard_id,
        test_contracts.test_erc20.contract.address(),
        erc20_release_params,
    )
    .clone();

    let transfer_erc20_segment = Erc20ReleaseIntentSegment::new(
        test_contracts.erc20_release_intent_standard.standard_id,
        test_contracts.test_erc20.contract.address(),
        erc20_transfer_params,
    );

    let require_erc20_segment = Erc20RequireIntentSegment::new(
        test_contracts.erc20_require_intent_standard.standard_id,
        test_contracts.test_erc20.contract.address(),
        erc20_require_params,
        EvaluationType::ABSOLUTE,
    );

    transfer_erc20_intent.add_segment(IntentSegment::Erc20Release(release_erc20_segment));
    transfer_erc20_intent.add_segment(IntentSegment::Erc20Release(transfer_erc20_segment));
    transfer_erc20_intent.add_segment(IntentSegment::Erc20Require(require_erc20_segment));

    transfer_erc20_intent
}

fn transfer_erc20_solver_intent(
    test_contracts: &TestContracts,
    solver: Address,
    erc20_release_amount: U256,
    erc20_transfer_amount: U256,
    recipient: Address,
) -> UserIntent {
    let mut solution = UserIntent::create(test_contracts.solver_utils.contract.address(), 0, 0);
    let swap_erc20_for_eth_segment = CallIntentSegment::new(
        test_contracts.call_intent_standard.standard_id,
        test_contracts.solver_utils.swap_erc20_for_eth_calldata(
            test_contracts,
            solver,
            erc20_release_amount,
        ),
    );
    let transfer_erc20_segment = CallIntentSegment::new(
        test_contracts.call_intent_standard.standard_id,
        test_contracts.solver_utils.transfer_erc20_calldata(
            test_contracts,
            recipient,
            erc20_transfer_amount,
        ),
    );

    solution.add_segment(IntentSegment::Call(swap_erc20_for_eth_segment));
    solution.add_segment(IntentSegment::Call(transfer_erc20_segment));

    solution
}
