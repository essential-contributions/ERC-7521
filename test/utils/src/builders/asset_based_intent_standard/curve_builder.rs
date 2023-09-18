use ethers::{
    abi::{AbiDecode, AbiEncode},
    prelude::*,
};

#[derive(Debug, Clone)]
pub struct AssetBasedIntentCurve {
    asset_id: Bytes,
    asset_contract: Address,
    flags: Vec<u8>, // [u8; 12]
    parameters: Vec<I256>,
}

impl AssetBasedIntentCurve {
    pub fn new(
        asset_id: Bytes,
        asset_contract: Address,
        flags: Vec<u8>,
        parameters: Vec<I256>,
    ) -> Self {
        Self {
            asset_id,
            asset_contract,
            flags,
            parameters,
        }
    }
}

impl AbiEncode for AssetBasedIntentCurve {
    fn encode(self) -> Vec<u8> {
        let mut encoded = vec![];
        encoded.extend_from_slice(&self.asset_id);
        encoded.extend_from_slice(&self.asset_contract.as_bytes());
        encoded.extend_from_slice(&self.flags.encode());
        for parameter in &self.parameters {
            encoded.extend_from_slice(&parameter.encode());
        }
        encoded
    }
}

impl AbiDecode for AssetBasedIntentCurve {
    fn decode(bytes: impl AsRef<[u8]>) -> Result<Self, AbiError> {
        let bytes = bytes.as_ref();
        let asset_id: Bytes = bytes[..32].to_vec().into();
        let asset_contract: Address = Address::from_slice(&bytes[32..52]);
        let flags = bytes[52..148].to_vec();
        let parameters = Vec::decode(bytes[64..bytes.len()].to_vec()).unwrap();
        Ok(Self {
            asset_id,
            asset_contract,
            flags,
            parameters,
        })
    }
}

impl Into<Vec<Bytes>> for AssetBasedIntentCurve {
    fn into(self) -> Vec<Bytes> {
        vec![
            self.asset_id,
            Bytes::from(self.asset_contract.to_fixed_bytes()),
            self.flags.encode().into(),
            self.parameters.encode().into(),
        ]
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

const FLAGS_EVAL_TYPE_OFFSET: u32 = 0;
const FLAGS_CURVE_TYPE_OFFSET: u32 = 2;
const FLAGS_ASSET_TYPE_OFFSET: u32 = 8;

const FLAGS_EVAL_TYPE_MASK: u16 = 0x0003;
const FLAGS_CURVE_TYPE_MASK: u16 = 0x00fc;
const FLAGS_ASSET_TYPE_MASK: u16 = 0xff00;

impl AbiEncode for CurveFlags {
    fn encode(self) -> Vec<u8> {
        // TODO
        vec![]
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
