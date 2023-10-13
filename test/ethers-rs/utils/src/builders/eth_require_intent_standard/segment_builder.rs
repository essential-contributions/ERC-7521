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
pub struct EthRequireIntentSegment {
    require: EthCurve,
}

impl EthRequireIntentSegment {
    pub fn new(curve_parameters: CurveParameters, evaluation_type: EvaluationType) -> Self {
        let flags: u128 = AbiDecode::decode(
            EthCurveFlags::new(curve_parameters.get_curve_type(), evaluation_type).encode(),
        )
        .unwrap();
        let curve = EthCurve::new(flags, curve_parameters.into());

        Self { require: curve }
    }
}
