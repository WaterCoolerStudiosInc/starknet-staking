use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

pub mod Constants {
    use starknet::contract_address_const;
    use super::ContractAddress;

    pub fn WRONG_ADMIN() -> ContractAddress {
        contract_address_const::<'WRONG_ADMIN'>()
    }
    pub fn INITIAL_ROOT_ADMIN() -> ContractAddress {
        contract_address_const::<'INITIAL_ROOT_ADMIN'>()
    }
    pub fn GOVERNANCE_ADMIN() -> ContractAddress {
        contract_address_const::<'GOVERNANCE_ADMIN'>()
    }
    pub fn SECURITY_ADMIN() -> ContractAddress {
        contract_address_const::<'SECURITY_ADMIN'>()
    }
    pub fn APP_ROLE_ADMIN() -> ContractAddress {
        contract_address_const::<'APP_ROLE_ADMIN'>()
    }
    pub fn APP_GOVERNOR() -> ContractAddress {
        contract_address_const::<'APP_GOVERNOR'>()
    }
    pub fn OPERATOR() -> ContractAddress {
        contract_address_const::<'OPERATOR'>()
    }
    pub fn TOKEN_ADMIN() -> ContractAddress {
        contract_address_const::<'TOKEN_ADMIN'>()
    }
    pub fn UPGRADE_GOVERNOR() -> ContractAddress {
        contract_address_const::<'UPGRADE_GOVERNOR'>()
    }
    pub fn SECURITY_AGENT() -> ContractAddress {
        contract_address_const::<'SECURITY_AGENT'>()
    }
}

pub fn deploy_mock_contract() -> ContractAddress {
    let mock_contract = *declare("MockContract").unwrap().contract_class();
    let (contract_address, _) = mock_contract
        .deploy(@array![Constants::INITIAL_ROOT_ADMIN().into()])
        .unwrap();
    contract_address
}
