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
pub struct AssetCurve {
    pub asset_id: U256,
    pub asset_contract: Address,
    pub flags: u128,
    pub params: Vec<I256>,
}

impl AssetCurve {
    pub fn new(asset_id: U256, asset_contract: Address, flags: u128, params: Vec<I256>) -> Self {
        Self {
            asset_id,
            asset_contract,
            flags,
            params,
        }
    }
}

#[derive(Debug, Clone)]
pub struct AssetCurveFlags {
    asset_type: AssetType,
    curve_type: CurveType,
    evaluation_type: EvaluationType,
}

impl AssetCurveFlags {
    pub fn new(
        asset_type: AssetType,
        curve_type: CurveType,
        evaluation_type: EvaluationType,
    ) -> Self {
        Self {
            asset_type,
            curve_type,
            evaluation_type,
        }
    }
}

impl From<AssetCurveFlags> for u128 {
    fn from(val: AssetCurveFlags) -> Self {
        let evaluation_type_offset: u8 = 0;
        let curve_type_offset: u8 = 2;
        let asset_type_offset: u8 = 8;

        ((val.asset_type as u128) << asset_type_offset)
            | ((val.curve_type as u128) << curve_type_offset)
            | ((val.evaluation_type as u128) << evaluation_type_offset)
    }
}

impl AbiEncode for AssetCurveFlags {
    fn encode(self) -> Vec<u8> {
        <Self as Into<u128>>::into(self).encode()
    }
}

#[derive(Debug, Clone)]
pub enum AssetType {
    ERC721,
    ERC721ID,
    ERC1155,
}
