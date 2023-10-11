use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        asset_based_intent_standard::{
            curve_builder::{AssetType, CurveParameters},
            segment_builder::AssetBasedIntentSegment,
        },
        default_intent_standard::segment_builder::DefaultIntentSegment,
    },
    deploy::TestContracts,
    setup::{setup, sign_intent, PROVIDER, SOLVER_WALLET, USER_WALLET},
};

pub async fn gasless_airdrop_scenario(
    release_parameters: CurveParameters,
    claim_amount: U256,
    gas_payment: U256,
) -> TestBalances {
    // setup
    let test_contracts = setup().await;

    // block number to evaluate the curves at
    let block_number: U256 =
        std::cmp::max(1, PROVIDER.get_block_number().await.unwrap().as_u64()).into();

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

    // create user intent
    let mut intent = gasless_airdrop_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        release_parameters.clone(),
        claim_amount,
    );
    intent = sign_intent(&test_contracts, intent, USER_WALLET.clone()).await;

    // create solver intent
    let solver_intent = gasless_airdrop_solver_intent(&test_contracts, gas_payment);

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

    test_balances
}

fn gasless_airdrop_intent(
    test_contracts: &TestContracts,
    sender: Address,
    release_parameters: CurveParameters,
    claim_amount: U256,
) -> UserIntent {
    let mut gasless_airdrop_intent = UserIntent::create(sender, 0, 0);

    let claim_airdrop_erc20_calldata = test_contracts
        .test_erc20
        .mint_calldata(test_contracts.user_account.contract.address(), claim_amount);
    let claim_airdrop_erc20_execute_calldata = test_contracts.user_account.execute_calldata(
        test_contracts.test_erc20.contract.address(),
        U256::zero(),
        claim_airdrop_erc20_calldata,
    );
    let claim_airdrop_erc20_segment =
        AssetBasedIntentSegment::new(claim_airdrop_erc20_execute_calldata);

    let release_erc20_segment = AssetBasedIntentSegment::new(Bytes::default())
        .add_asset_release_curve(
            test_contracts.test_erc20.contract.address(),
            U256::zero(),
            AssetType::ERC20,
            release_parameters,
        )
        .clone();

    gasless_airdrop_intent.add_segment_asset_based(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        claim_airdrop_erc20_segment,
    );
    gasless_airdrop_intent.add_segment_asset_based(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        release_erc20_segment,
    );

    gasless_airdrop_intent
}

fn gasless_airdrop_solver_intent(test_contracts: &TestContracts, gas_payment: U256) -> UserIntent {
    let mut solution = UserIntent::create(test_contracts.solver_utils.contract.address(), 0, 0);

    let swap_all_erc20_for_eth_calldata = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_calldata(test_contracts, SOLVER_WALLET.address(), gas_payment);

    solution.add_segment_default(
        test_contracts.entry_point.default_standard_id.clone(),
        DefaultIntentSegment::new(swap_all_erc20_for_eth_calldata),
    );

    solution
}
