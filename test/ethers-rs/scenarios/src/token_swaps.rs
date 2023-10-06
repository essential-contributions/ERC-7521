use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        asset_based_intent_standard::{
            curve_builder::{AssetType, CurveParameters, EvaluationType},
            segment_builder::AssetBasedIntentSegment,
        },
        default::segment_builder::DefaultIntentSegment,
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
    let mut token_swap_intent = UserIntent::create_asset_based(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        sender,
        0,
        0,
    );

    let release_erc20_segment = AssetBasedIntentSegment::new(Bytes::default())
        .add_asset_release_curve(
            test_contracts.test_erc20.contract.address(),
            U256::zero(),
            AssetType::ERC20,
            release_params,
        )
        .clone();

    let require_eth_segment = AssetBasedIntentSegment::new(Bytes::default())
        .add_asset_requirement_curve(
            Address::default(),
            U256::zero(),
            AssetType::ETH,
            require_params,
            EvaluationType::RELATIVE,
        )
        .clone();

    token_swap_intent.add_segment_asset_based(release_erc20_segment);
    token_swap_intent.add_segment_asset_based(require_eth_segment);

    token_swap_intent
}

fn token_swap_solver_intent(
    test_contracts: &TestContracts,
    sender: Address,
    other: Address,
    erc20_release_amount: U256,
    evaluation: U256,
) -> UserIntent {
    let mut solution = UserIntent::create_default(
        test_contracts.entry_point.default_standard_id.clone(),
        test_contracts.solver_utils.contract.address(),
        0,
        0,
    );

    let solver_calldata = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_and_forward_calldata(
            test_contracts,
            sender,
            other,
            erc20_release_amount,
            evaluation,
        );

    let solver_segment = DefaultIntentSegment::new(solver_calldata);
    solution.add_segment_default(solver_segment);

    solution
}
