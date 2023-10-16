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
    Default,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct Erc20RequireIntentSegment {
    requirement: Erc20Curve,
}

impl Erc20RequireIntentSegment {
    pub fn new(
        erc20_contract: Address,
        curve_parameters: CurveParameters,
        evaluation_type: EvaluationType,
    ) -> Self {
        let flags: u128 = AbiDecode::decode(
            Erc20CurveFlags::new(curve_parameters.get_curve_type(), evaluation_type).encode(),
        )
        .unwrap();
        let curve = Erc20Curve::new(erc20_contract, flags, curve_parameters.into());

        Self { requirement: curve }
    }
}
