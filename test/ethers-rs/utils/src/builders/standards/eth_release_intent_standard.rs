use crate::builders::{
    curve_type::CurveParameters,
    eth_curve_builder::{EthCurve, EthCurveFlags},
    evaluation_type::EvaluationType,
};
use ethers::abi::{AbiDecode, AbiEncode};

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct EthReleaseIntentSegment {
    pub standard: [u8; 32],
    pub release: EthCurve,
}

impl EthReleaseIntentSegment {
    pub fn new(standard: [u8; 32], curve_parameters: CurveParameters) -> Self {
        let flags: u128 = AbiDecode::decode(
            EthCurveFlags::new(curve_parameters.get_curve_type(), EvaluationType::ABSOLUTE)
                .encode(),
        )
        .unwrap();
        let curve = EthCurve::new(flags, curve_parameters.into());

        Self {
            standard,
            release: curve,
        }
    }
}
