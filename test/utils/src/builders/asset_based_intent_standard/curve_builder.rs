use crate::abigen::AssetBasedIntentCurve;
use ethers::{abi::AbiEncode, prelude::*};

impl AssetBasedIntentCurve {
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
pub struct CurveFlags {
    asset_type: AssetType,
    curve_type: CurveType,
    evaluation_type: EvaluationType,
}

impl CurveFlags {
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

impl AbiEncode for CurveFlags {
    fn encode(self) -> Vec<u8> {
        let evaluation_type_offset: u32 = 0b0000;
        let curve_type_offset: u32 = 0b0010;
        let asset_type_offset: u32 = 0b1000;

        let flag: u32 = ((self.asset_type as u32) << asset_type_offset)
            | ((self.curve_type as u32) << curve_type_offset)
            | ((self.evaluation_type as u32) << evaluation_type_offset);

        flag.encode()
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

pub enum CurveParameters {
    Constant(ConstantCurveParameters),
    Linear(LinearCurveParameters),
    Exponential(ExponentialCurveParameters),
}

pub struct ConstantCurveParameters {
    b: I256,
}

impl ConstantCurveParameters {
    pub fn new(b: I256) -> Self {
        Self { b }
    }
}

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

impl Into<Vec<I256>> for CurveParameters {
    fn into(self) -> Vec<I256> {
        match self {
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
}
