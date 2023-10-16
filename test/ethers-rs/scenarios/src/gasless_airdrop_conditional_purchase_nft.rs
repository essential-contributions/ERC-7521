use ethers::prelude::*;
use utils::{
    abigen::entry_point::{IntentSolution, UserIntent},
    balance::TestBalances,
    builders::{
        asset_curve_builder::AssetType,
        curve_type::CurveParameters,
        evaluation_type::EvaluationType,
        standards::{
            asset_require_intent_standard::AssetRequireIntentSegment,
            call_intent_standard::CallIntentSegment,
            erc20_release_intent_standard::Erc20ReleaseIntentSegment,
            eth_require_intent_standard::EthRequireIntentSegment,
        },
    },
    deploy::TestContracts,
    setup::{setup, sign_intent, PROVIDER, SOLVER_WALLET, USER_WALLET},
};

pub async fn gasless_airdrop_conditional_purchase_nft_scenario(
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

    // get next erc721 token id
    let token_id = test_contracts.test_erc721.next_nft_for_sale().await;

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
    let mut intent = gasless_airdrop_conditional_purchase_nft_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        release_parameters.clone(),
        require_parameters.clone(),
        claim_amount,
        nft_price,
        token_id,
    );
    intent = sign_intent(&test_contracts, intent, USER_WALLET.clone()).await;

    // create solver intent
    let solver_intent = gasless_airdrop_conditional_purchase_nft_solver_intent(
        &test_contracts,
        test_contracts.user_account.contract.address(),
        token_id,
        release_evaluation,
        nft_price,
    );

    // create intent solution
    let solution = IntentSolution::new(
        block_number,
        vec![intent, solver_intent],
        vec![U256::from(0), U256::from(0), U256::from(1), U256::from(0)],
    );

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

fn gasless_airdrop_conditional_purchase_nft_intent(
    test_contracts: &TestContracts,
    sender: Address,
    release_parameters: CurveParameters,
    require_params: CurveParameters,
    claim_amount: U256,
    nft_price: U256,
    token_id: U256,
) -> UserIntent {
    let mut gasless_airdrop_conditional_purchase_nft_intent = UserIntent::create(sender, 0, 0);

    let claim_erc20_airdrop_calldata = test_contracts
        .test_erc20
        .mint_calldata(test_contracts.user_account.contract.address(), claim_amount);
    let claim_erc20_airdrop_execute_calldata = test_contracts.user_account.execute_calldata(
        test_contracts.test_erc20.contract.address(),
        U256::zero(),
        claim_erc20_airdrop_calldata,
    );
    let claim_erc20_airdrop_segment = CallIntentSegment::new(claim_erc20_airdrop_execute_calldata);

    let release_erc20_segment = Erc20ReleaseIntentSegment::new(
        test_contracts.test_erc20.contract.address(),
        release_parameters.clone(),
    )
    .clone();

    let buy_erc1155_calldata = test_contracts.test_erc1155.buy_nft_calldata(
        test_contracts.user_account.contract.address(),
        U256::from(1),
    );
    let transfer_erc721_calldata = test_contracts.test_erc721.transfer_from_calldata(
        test_contracts.user_account.contract.address(),
        test_contracts.call_intent_standard.contract.address(),
        token_id,
    );
    let buy_erc1155_and_transfer_erc721_execute_multi_calldata =
        test_contracts.user_account.execute_multi_calldata(
            vec![
                test_contracts.test_erc1155.contract.address(),
                test_contracts.test_erc721.contract.address(),
            ],
            vec![nft_price, U256::from(0)],
            vec![buy_erc1155_calldata, transfer_erc721_calldata],
        );
    let buy_erc1155_and_transfer_erc721_segment =
        CallIntentSegment::new(buy_erc1155_and_transfer_erc721_execute_multi_calldata);

    let require_eth_segment =
        EthRequireIntentSegment::new(require_params.clone(), EvaluationType::ABSOLUTE);

    let require_erc721_segment = AssetRequireIntentSegment::new(
        test_contracts.test_erc721.contract.address(),
        token_id,
        AssetType::ERC721,
        require_params,
        EvaluationType::ABSOLUTE,
    )
    .clone();

    gasless_airdrop_conditional_purchase_nft_intent.add_segment_call(
        test_contracts.call_intent_standard.standard_id.clone(),
        claim_erc20_airdrop_segment,
    );
    gasless_airdrop_conditional_purchase_nft_intent.add_segment_erc20_release(
        test_contracts
            .erc20_release_intent_standard
            .standard_id
            .clone(),
        release_erc20_segment,
    );
    gasless_airdrop_conditional_purchase_nft_intent.add_segment_call(
        test_contracts.call_intent_standard.standard_id.clone(),
        buy_erc1155_and_transfer_erc721_segment,
    );
    gasless_airdrop_conditional_purchase_nft_intent.add_segment_eth_require(
        test_contracts
            .eth_require_intent_standard
            .standard_id
            .clone(),
        require_eth_segment,
    );
    gasless_airdrop_conditional_purchase_nft_intent.add_segment_asset_require(
        test_contracts
            .asset_require_intent_standard
            .standard_id
            .clone(),
        require_erc721_segment,
    );

    gasless_airdrop_conditional_purchase_nft_intent
}

fn gasless_airdrop_conditional_purchase_nft_solver_intent(
    test_contracts: &TestContracts,
    other: Address,
    token_id: U256,
    min_eth: U256,
    nft_price: U256,
) -> UserIntent {
    let mut solution = UserIntent::create(test_contracts.solver_utils.contract.address(), 0, 0);

    let calldata_1 = test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_buy_nft_and_forward_calldata(
            test_contracts,
            other,
            min_eth,
            nft_price,
            nft_price,
        );

    let calldata_2 = test_contracts
        .solver_utils
        .sell_erc721_and_forward_all_calldata(test_contracts, token_id, SOLVER_WALLET.address());

    solution.add_segment_call(
        test_contracts.call_intent_standard.standard_id.clone(),
        CallIntentSegment::new(calldata_1),
    );
    solution.add_segment_call(
        test_contracts.call_intent_standard.standard_id.clone(),
        CallIntentSegment::new(calldata_2),
    );

    solution
}
