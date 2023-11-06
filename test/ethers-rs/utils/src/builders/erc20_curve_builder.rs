use crate::builders::{curve_type::CurveType, evaluation_type::EvaluationType};
use ethers::{abi::AbiEncode, prelude::*};

#[derive(
    Clone,
    ::ethers::contract::EthAbiType,
    ::ethers::contract::EthAbiCodec,
    Debug,
    PartialEq,
    Eq,
    Hash,
)]
pub struct Erc20Curve {
    pub asset_contract: Address,
    pub timestamp: u64,
    pub flags: u128,
    pub params: Vec<I256>,
}

impl Erc20Curve {
    pub fn new(asset_contract: Address, timestamp: u64, flags: u128, params: Vec<I256>) -> Self {
        Self {
            asset_contract,
            timestamp,
            flags,
            params,
        }
    }
}

#[derive(Debug, Clone)]
pub struct Erc20CurveFlags {
    curve_type: CurveType,
    evaluation_type: EvaluationType,
}

impl Erc20CurveFlags {
    pub fn new(curve_type: CurveType, evaluation_type: EvaluationType) -> Self {
        Self {
            curve_type,
            evaluation_type,
        }
    }
}

impl From<Erc20CurveFlags> for u128 {
    fn from(val: Erc20CurveFlags) -> Self {
        let evaluation_type_offset: u8 = 0;
        let curve_type_offset: u8 = 2;

        ((val.curve_type as u128) << curve_type_offset)
            | ((val.evaluation_type as u128) << evaluation_type_offset)
    }
}

impl AbiEncode for Erc20CurveFlags {
    fn encode(self) -> Vec<u8> {
        <Self as Into<u128>>::into(self).encode()
    }
}
