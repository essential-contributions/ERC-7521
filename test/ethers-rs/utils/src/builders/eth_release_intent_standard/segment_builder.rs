use crate::builders::{
    asset_curve_builder::{CurveParameters, EvaluationType},
    eth_curve_builder::{EthCurve, EthCurveFlags},
};
use ethers::abi::{AbiDecode, AbiEncode};

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
pub struct EthReleaseIntentSegment {
    release: EthCurve,
}

impl EthReleaseIntentSegment {
    pub fn new(curve_parameters: CurveParameters) -> Self {
        let flags: u128 = AbiDecode::decode(
            EthCurveFlags::new(curve_parameters.get_curve_type(), EvaluationType::ABSOLUTE)
                .encode(),
        )
        .unwrap();
        let curve = EthCurve::new(flags, curve_parameters.into());

        Self { release: curve }
    }
}
