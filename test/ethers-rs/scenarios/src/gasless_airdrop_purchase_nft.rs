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

pub async fn gasless_airdrop_purchase_nft_scenario(
    release_parameters: CurveParameters,
    require_parameters: CurveParameters,
    claim_amount: U256,
) -> (TestBalances, U256) {
    // setup
    let test_contracts = setup().await;

    // block number to evaluate the curves at
    let block_number: U256 =
        std::cmp::max(1, PROVIDER.get_block_number().await.unwrap().as_u64()).into();

    // get nft price
    let nft_price = test_contracts.test_erc1155.nft_cost().await;

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

    test_balances.user.erc1155.initial = Some(U256::zero());

    // calculate release amount
    let release_evaluation = release_parameters.evaluate(block_number).into_raw();

    // create user intent
    let mut intent = gasless_airdrop_purchase_nft_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        release_parameters.clone(),
        require_parameters.clone(),
        claim_amount,
        nft_price,
    );
    intent = sign_intent(&test_contracts, intent, USER_WALLET.clone()).await;

    // create solver intent
    let solver_intent = gasless_airdrop_purchase_nft_solver_intent(
        &test_contracts,
        SOLVER_WALLET.address(),
        test_contracts.user_account.contract.address(),
        release_evaluation,
        nft_price,
    );

    // create intent solution
    let solution = IntentSolution::new(block_number, vec![intent, solver_intent], vec![]);

    // call handle intents
    test_contracts
        .entry_point
        .handle_intents(solution)
        .await
        .unwrap();

    let nft_id = test_contracts.test_erc1155.last_bought_nft().await;

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
    test_balances.user.erc1155.r#final = Some(
        test_contracts
            .test_erc1155
            .balance_of(test_contracts.user_account.contract.address(), nft_id)
            .await,
    );

    (test_balances, nft_price)
}

fn gasless_airdrop_purchase_nft_intent(
    test_contracts: &TestContracts,
    sender: Address,
    release_parameters: CurveParameters,
    require_params: CurveParameters,
    claim_amount: U256,
    nft_price: U256,
) -> UserIntent {
    let mut gasless_airdrop_purchase_nft_intent = UserIntent::create_asset_based(
        test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        sender,
        0,
        0,
    );

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

    let buy_erc1155_calldata = test_contracts.test_erc1155.buy_nft_calldata(
        test_contracts.user_account.contract.address(),
        U256::from(1),
    );
    let buy_erc1155_execute_calldata = test_contracts.user_account.execute_calldata(
        test_contracts.test_erc1155.contract.address(),
        nft_price,
        buy_erc1155_calldata,
    );
    let buy_erc1155_segment = AssetBasedIntentSegment::new(buy_erc1155_execute_calldata);

    let require_eth_segment = AssetBasedIntentSegment::new(Bytes::default())
        .add_asset_requirement_curve(
            Address::default(),
            U256::zero(),
            AssetType::ETH,
            require_params,
            EvaluationType::ABSOLUTE,
        )
        .clone();

    gasless_airdrop_purchase_nft_intent.add_segment_asset_based(claim_airdrop_erc20_segment);
    gasless_airdrop_purchase_nft_intent.add_segment_asset_based(release_erc20_segment);
    gasless_airdrop_purchase_nft_intent.add_segment_asset_based(buy_erc1155_segment);
    gasless_airdrop_purchase_nft_intent.add_segment_asset_based(require_eth_segment);

    gasless_airdrop_purchase_nft_intent
}

fn gasless_airdrop_purchase_nft_solver_intent(
    test_contracts: &TestContracts,
    sender: Address,
    other: Address,
    min_eth: U256,
    nft_price: U256,
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
            min_eth,
            nft_price,
        );

    let solver_segment = DefaultIntentSegment::new(solver_calldata);
    solution.add_segment_default(solver_segment);

    solution
}
