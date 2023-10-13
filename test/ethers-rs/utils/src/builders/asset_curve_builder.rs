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
    ETH,
    ERC20,
    ERC721,
    ERC721ID,
    ERC1155,
}

#[derive(Debug, Clone)]
pub enum CurveType {
    CONSTANT,
    LINEAR,
    EXPONENTIAL,
}

#[derive(Debug, Clone)]
pub enum EvaluationType {
    ABSOLUTE,
    RELATIVE,
}

#[derive(Clone)]
pub enum CurveParameters {
    Constant(ConstantCurveParameters),
    Linear(LinearCurveParameters),
    Exponential(ExponentialCurveParameters),
}

#[derive(Clone)]
pub struct ConstantCurveParameters {
    b: I256,
}

impl ConstantCurveParameters {
    pub fn new(b: I256) -> Self {
        Self { b }
    }
}

#[derive(Clone)]
pub struct LinearCurveParameters {
    m: I256,
    b: I256,
    max: I256,
}

impl LinearCurveParameters {
    pub fn new(m: I256, b: I256, max: I256) -> Self {
        Self { m, b, max }
    }
}

#[derive(Clone)]
pub struct ExponentialCurveParameters {
    m: I256,
    b: I256,
    e: I256,
    max: I256,
}

impl ExponentialCurveParameters {
    pub fn new(m: I256, b: I256, e: I256, max: I256) -> Self {
        Self { m, b, e, max }
    }
}

impl From<CurveParameters> for Vec<I256> {
    fn from(val: CurveParameters) -> Self {
        match val {
            CurveParameters::Constant(params) => vec![params.b],
            CurveParameters::Linear(params) => vec![params.m, params.b, params.max],
            CurveParameters::Exponential(params) => {
                vec![params.m, params.b, params.e, params.max]
            }
        }
    }
}

impl From<Vec<I256>> for CurveParameters {
    fn from(vec: Vec<I256>) -> Self {
        match vec.len() {
            1 => CurveParameters::Constant(ConstantCurveParameters { b: vec[0] }),
            3 => CurveParameters::Linear(LinearCurveParameters {
                m: vec[0],
                b: vec[1],
                max: vec[2],
            }),
            4 => CurveParameters::Exponential(ExponentialCurveParameters {
                m: vec[0],
                b: vec[1],
                e: vec[2],
                max: vec[3],
            }),
            _ => panic!("Invalid curve parameters"),
        }
    }
}

impl CurveParameters {
    pub fn get_curve_type(&self) -> CurveType {
        match self {
            CurveParameters::Constant(_) => CurveType::CONSTANT,
            CurveParameters::Linear(_) => CurveType::LINEAR,
            CurveParameters::Exponential(_) => CurveType::EXPONENTIAL,
        }
    }

    pub fn evaluate(&self, at: U256) -> I256 {
        match self {
            CurveParameters::Constant(params) => params.b,
            CurveParameters::Linear(params) => {
                (params.m * std::cmp::min(params.max, I256::from_raw(at))) + params.b
            }

            CurveParameters::Exponential(params) => {
                (params.m
                    * I256::from_raw(
                        std::cmp::min(params.max.unsigned_abs(), at).pow(params.e.unsigned_abs()),
                    ))
                    + params.b
            }
        }
    }
}
