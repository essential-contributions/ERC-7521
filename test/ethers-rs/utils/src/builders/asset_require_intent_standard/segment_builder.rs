use crate::builders::asset_curve_builder::{
    AssetCurve, AssetCurveFlags, AssetType, CurveParameters, EvaluationType,
};
use ethers::{
    abi::{AbiDecode, AbiEncode},
    prelude::*,
};

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Default,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct AssetRequireIntentSegment {
    asset_requirement: AssetCurve,
}

impl AssetRequireIntentSegment {
    pub fn new(
        asset_contract: Address,
        asset_id: U256,
        asset_type: AssetType,
        curve_parameters: CurveParameters,
        evaluation_type: EvaluationType,
    ) -> Self {
        let flags: u128 = AbiDecode::decode(
            AssetCurveFlags::new(
                asset_type,
                curve_parameters.get_curve_type(),
                evaluation_type,
            )
            .encode(),
        )
        .unwrap();
        let curve = AssetCurve::new(asset_id, asset_contract, flags, curve_parameters.into());

        Self {
            asset_requirement: curve,
        }
    }
}
