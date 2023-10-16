use crate::builders::{curve_type::CurveType, evaluation_type::EvaluationType};
use ethers::{abi::AbiEncode, prelude::*};

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
pub struct EthCurve {
    pub flags: u128,
    pub params: Vec<I256>,
}

impl EthCurve {
    pub fn new(flags: u128, params: Vec<I256>) -> Self {
        Self { flags, params }
    }
}

#[derive(Debug, Clone)]
pub struct EthCurveFlags {
    curve_type: CurveType,
    evaluation_type: EvaluationType,
}

impl EthCurveFlags {
    pub fn new(curve_type: CurveType, evaluation_type: EvaluationType) -> Self {
        Self {
            curve_type,
            evaluation_type,
        }
    }
}

impl From<EthCurveFlags> for u128 {
    fn from(val: EthCurveFlags) -> Self {
        let evaluation_type_offset: u8 = 0;
        let curve_type_offset: u8 = 2;

        ((val.curve_type as u128) << curve_type_offset)
            | ((val.evaluation_type as u128) << evaluation_type_offset)
    }
}

impl AbiEncode for EthCurveFlags {
    fn encode(self) -> Vec<u8> {
        <Self as Into<u128>>::into(self).encode()
    }
}
