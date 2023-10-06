use ethers::prelude::*;
use utils::{
    abigen::entry_point::UserIntent,
    builders::{
        asset_based_intent_standard::{
            curve_builder::{CurveParameters, EvaluationType},
            segment_builder::AssetBasedIntentSegment,
        },
        default::segment_builder::DefaultIntentSegment,
    },
    setup::SetupArtifacts,
};

pub fn constant_release_intent(
    artifacts: &SetupArtifacts,
    sender: Address,
    release_params: CurveParameters,
    require_params: CurveParameters,
) -> UserIntent {
    let mut constant_release_intent = UserIntent::create_asset_based(
        artifacts
            .test_contracts
            .asset_based_intent_standard
            .standard_id
            .clone(),
        sender,
        0,
        0,
    );

    let release_erc20_segment = AssetBasedIntentSegment::new(U256::from(1000000), Bytes::default())
        .release_erc20(
            artifacts.test_contracts.test_erc20.contract.address(),
            release_params,
        )
        .clone();

    let require_eth_segment = AssetBasedIntentSegment::new(U256::from(1000000), Bytes::default())
        .require_eth(require_params, EvaluationType::RELATIVE)
        .clone();

    constant_release_intent.add_segment_asset_based(release_erc20_segment);
    constant_release_intent.add_segment_asset_based(require_eth_segment);

    constant_release_intent
}

pub fn constant_release_solver_intent(
    artifacts: &SetupArtifacts,
    sender: Address,
    other: Address,
    erc20_release_amount: U256,
    evaluation: U256,
) -> UserIntent {
    let mut solution = UserIntent::create_default(
        artifacts
            .test_contracts
            .entry_point
            .default_standard_id
            .clone(),
        artifacts.test_contracts.solver_utils.contract.address(),
        0,
        0,
    );

    let solver_calldata = artifacts
        .test_contracts
        .solver_utils
        .swap_all_erc20_for_eth_and_forward(
            &artifacts.test_contracts,
            sender,
            other,
            erc20_release_amount,
            evaluation,
        );

    let solver_segment = DefaultIntentSegment::new(U256::from(1000000), solver_calldata).clone();
    solution.add_segment_default(solver_segment);

    solution
}
