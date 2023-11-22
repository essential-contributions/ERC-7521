use crate::builders::{
    curve_type::CurveParameters,
    erc20_curve_builder::{Erc20Curve, Erc20CurveFlags},
    evaluation_type::EvaluationType,
};
use ethers::{
    abi::{AbiDecode, AbiEncode},
    prelude::*,
};

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct Erc20ReleaseIntentSegment {
    pub standard: [u8; 32],
    pub release: Erc20Curve,
}

impl Erc20ReleaseIntentSegment {
    pub fn new(
        standard: [u8; 32],
        erc20_contract: Address,
        timestamp: u64,
        curve_parameters: CurveParameters,
    ) -> Self {
        let flags: u128 = AbiDecode::decode(
            Erc20CurveFlags::new(curve_parameters.get_curve_type(), EvaluationType::ABSOLUTE)
                .encode(),
        )
        .unwrap();
        let curve = Erc20Curve::new(erc20_contract, timestamp, flags, curve_parameters.into());

        Self {
            standard,
            release: curve,
        }
    }
}
