use ethers::prelude::*;

#[derive(Debug, Clone)]
pub enum CurveType {
    CONSTANT,
    LINEAR,
    EXPONENTIAL,
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
