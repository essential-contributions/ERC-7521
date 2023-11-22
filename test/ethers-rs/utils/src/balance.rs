use ethers::types::U256;

#[derive(Default)]
pub struct Chronology {
    pub initial: Option<U256>,
    pub r#final: Option<U256>,
}

#[derive(Default)]
pub struct Balance {
    pub eth: Chronology,
    pub erc20: Chronology,
}

#[derive(Default)]
pub struct TestBalances {
    pub user: Balance,
    pub solver: Balance,
    pub recipient: Balance,
}
