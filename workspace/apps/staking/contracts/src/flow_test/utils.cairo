use MainnetAddresses::MAINNET_L2_BRIDGE_ADDRESS;
use MainnetAddresses::{MAINNET_MINTING_CURVE_ADDRESS, MAINNET_UPGRADE_GOVERNOR};
use MainnetAddresses::{MAINNET_REWARD_SUPPLIER_ADDRESS, MAINNET_STAKING_CONTRCT_ADDRESS};
use contracts_commons::components::replaceability::interface::IReplaceableDispatcher;
use contracts_commons::components::replaceability::interface::IReplaceableDispatcherTrait;
use contracts_commons::components::replaceability::interface::ImplementationData;
use contracts_commons::constants::{NAME, SYMBOL};
use contracts_commons::test_utils::{
    Deployable, TokenConfig, TokenState, TokenTrait, cheat_caller_address_once,
    set_account_as_app_role_admin, set_account_as_security_admin, set_account_as_security_agent,
    set_account_as_token_admin, set_account_as_upgrade_governor,
};
use contracts_commons::types::time::time::{Time, TimeDelta, Timestamp};
use core::num::traits::zero::Zero;
use core::traits::Into;
use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, start_cheat_block_timestamp_global};
use staking::minting_curve::interface::IMintingCurveDispatcher;
use staking::pool::interface::{IPoolDispatcher, IPoolDispatcherTrait};
use staking::reward_supplier::interface::{
    IRewardSupplierDispatcher, IRewardSupplierDispatcherTrait,
};
use staking::staking::interface::{
    IStakingConfigDispatcher, IStakingConfigDispatcherTrait, IStakingDispatcher,
    IStakingDispatcherTrait, StakerInfoTrait,
};
use staking::test_utils::StakingInitConfig;
use staking::test_utils::constants::STRK_TOKEN_ADDRESS;
use staking::types::{Amount, Commission};
use starknet::{ClassHash, ContractAddress};

pub mod MainnetAddresses {
    use starknet::{ContractAddress, contract_address_const};

    pub fn MAINNET_STAKING_CONTRCT_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<
            0x00ca1702e64c81d9a07b86bd2c540188d92a2c73cf5cc0e508d949015e7e84a7,
        >()
    }
    pub fn MAINNET_L2_BRIDGE_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<
            0x0594c1582459ea03f77deaf9eb7e3917d6994a03c13405ba42867f83d85f085d,
        >()
    }
    pub fn MAINNET_REWARD_SUPPLIER_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<
            0x009035556d1ee136e7722ae4e78f92828553a45eed3bc9b2aba90788ec2ca112,
        >()
    }
    pub fn MAINNET_MINTING_CURVE_ADDRESS() -> ContractAddress nopanic {
        contract_address_const::<
            0x00ca1705e74233131dbcdee7f1b8d2926bf262168c7df339004b3f46015b6984,
        >()
    }
    pub fn MAINNET_UPGRADE_GOVERNOR() -> ContractAddress nopanic {
        contract_address_const::<
            0x0663cc699d9c51b7d4d434e06f5982692167546ce525d9155edb476ac9a117d6,
        >()
    }
}

/// The `StakingRoles` struct represents the various roles involved in the staking contract.
/// It includes addresses for different administrative and security roles.
#[derive(Drop, Copy)]
pub struct StakingRoles {
    pub upgrade_governor: ContractAddress,
    pub security_admin: ContractAddress,
    pub security_agent: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub token_admin: ContractAddress,
}

/// The `StakingConfig` struct represents the configuration settings for the staking contract.
/// It includes various parameters and roles required for the staking contract's operation.
///
/// # Fields
/// - `min_stake` (Amount): The minimum amount of tokens required to stake.
/// - `pool_contract_class_hash` (ClassHash): The class hash of the pool contract.
/// - `reward_supplier` (ContractAddress): The address of the reward supplier contract.
/// - `pool_contract_admin` (ContractAddress): The address of the pool contract administrator.
/// - `governance_admin` (ContractAddress): The address of the governance administrator.
#[derive(Drop, Copy)]
pub struct StakingConfig {
    pub min_stake: Amount,
    pub pool_contract_class_hash: ClassHash,
    pub reward_supplier: ContractAddress,
    pub pool_contract_admin: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: StakingRoles,
}

/// The `StakingState` struct represents the state of the staking contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct StakingState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: StakingRoles,
}

#[generate_trait]
pub impl StakingImpl of StakingTrait {
    fn deploy(self: StakingConfig, token: TokenState) -> StakingState {
        let mut calldata = ArrayTrait::new();
        token.address.serialize(ref calldata);
        self.min_stake.serialize(ref calldata);
        self.pool_contract_class_hash.serialize(ref calldata);
        self.reward_supplier.serialize(ref calldata);
        self.pool_contract_admin.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let staking_contract = snforge_std::declare("Staking").unwrap().contract_class();
        let (staking_contract_address, _) = staking_contract.deploy(@calldata).unwrap();
        let staking = StakingState {
            address: staking_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        staking.set_roles();
        staking
    }

    fn dispatcher(self: StakingState) -> IStakingDispatcher nopanic {
        IStakingDispatcher { contract_address: self.address }
    }

    fn set_roles(self: StakingState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
        set_account_as_security_admin(
            contract: self.address,
            account: self.roles.security_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_security_agent(
            contract: self.address,
            account: self.roles.security_agent,
            security_admin: self.roles.security_admin,
        );
        set_account_as_app_role_admin(
            contract: self.address,
            account: self.roles.app_role_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_token_admin(
            contract: self.address,
            account: self.roles.token_admin,
            app_role_admin: self.roles.app_role_admin,
        );
    }

    fn get_pool(self: StakingState, staker: Staker) -> ContractAddress {
        let staker_info = self.dispatcher().staker_info(staker_address: staker.staker.address);
        staker_info.get_pool_info().pool_contract
    }

    fn get_min_stake(self: StakingState) -> Amount {
        self.dispatcher().contract_parameters().try_into().unwrap().min_stake
    }

    fn get_total_stake(self: StakingState) -> Amount {
        self.dispatcher().get_total_stake()
    }

    fn get_exit_wait_window(self: StakingState) -> TimeDelta {
        self.dispatcher().contract_parameters().exit_wait_window
    }
}

/// The `MintingCurveRoles` struct represents the various roles involved in the minting curve
/// contract.
/// It includes addresses for different administrative roles.
#[derive(Drop, Copy)]
pub struct MintingCurveRoles {
    pub upgrade_governor: ContractAddress,
    pub app_role_admin: ContractAddress,
    pub token_admin: ContractAddress,
}

/// The `MintingCurveConfig` struct represents the configuration settings for the minting curve
/// contract.
/// It includes various parameters and roles required for the minting curve contract's operation.
///
/// # Fields
/// - `initial_supply` (Amount): The initial supply of tokens to be minted.
/// - `governance_admin` (ContractAddress).
/// - `l1_reward_supplier` (felt252).
/// - `roles` (MintingCurveRoles).
#[derive(Drop, Copy)]
pub struct MintingCurveConfig {
    pub initial_supply: Amount,
    pub governance_admin: ContractAddress,
    pub l1_reward_supplier: felt252,
    pub roles: MintingCurveRoles,
}

/// The `MintingCurveState` struct represents the state of the minting curve contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct MintingCurveState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: MintingCurveRoles,
}

#[generate_trait]
impl MintingCurveImpl of MintingCurveTrait {
    fn deploy(self: MintingCurveConfig, staking: StakingState) -> MintingCurveState {
        let mut calldata = ArrayTrait::new();
        staking.address.serialize(ref calldata);
        self.initial_supply.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let minting_curve_contract = snforge_std::declare("MintingCurve").unwrap().contract_class();
        let (minting_curve_contract_address, _) = minting_curve_contract.deploy(@calldata).unwrap();
        let minting_curve = MintingCurveState {
            address: minting_curve_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        minting_curve.set_roles();
        minting_curve
    }

    fn dispatcher(self: MintingCurveState) -> IMintingCurveDispatcher nopanic {
        IMintingCurveDispatcher { contract_address: self.address }
    }

    fn set_roles(self: MintingCurveState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
        set_account_as_app_role_admin(
            contract: self.address,
            account: self.roles.app_role_admin,
            governance_admin: self.governance_admin,
        );
        set_account_as_token_admin(
            contract: self.address,
            account: self.roles.token_admin,
            app_role_admin: self.roles.app_role_admin,
        );
    }
}

/// The `RewardSupplierRoles` struct represents the various roles involved in the reward supplier
/// contract.
/// It includes the address for the upgrade governor role.
#[derive(Drop, Copy)]
pub struct RewardSupplierRoles {
    pub upgrade_governor: ContractAddress,
}

/// The `RewardSupplierConfig` struct represents the configuration settings for the reward supplier
/// contract.
/// It includes various parameters and roles required for the reward supplier contract's operation.
///
/// # Fields
/// - `base_mint_amount` (Amount): The base amount of tokens to be minted.
/// - `l1_reward_supplier` (felt252).
/// - `starkgate_address` (ContractAddress): The address of the StarkGate contract.
/// - `governance_admin` (ContractAddress): The address of the governance administrator.
/// - `roles` (RewardSupplierRoles): The roles involved in the reward supplier contract.
#[derive(Drop, Copy)]
pub struct RewardSupplierConfig {
    pub base_mint_amount: Amount,
    pub l1_reward_supplier: felt252,
    pub starkgate_address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: RewardSupplierRoles,
}

/// The `RewardSupplierState` struct represents the state of the reward supplier contract.
/// It includes the contract address, governance administrator, and roles.
#[derive(Drop, Copy)]
pub struct RewardSupplierState {
    pub address: ContractAddress,
    pub governance_admin: ContractAddress,
    pub roles: RewardSupplierRoles,
}

#[generate_trait]
pub impl RewardSupplierImpl of RewardSupplierTrait {
    fn deploy(
        self: RewardSupplierConfig,
        minting_curve: MintingCurveState,
        staking: StakingState,
        token: TokenState,
    ) -> RewardSupplierState {
        let mut calldata = ArrayTrait::new();
        self.base_mint_amount.serialize(ref calldata);
        minting_curve.address.serialize(ref calldata);
        staking.address.serialize(ref calldata);
        token.address.serialize(ref calldata);
        self.l1_reward_supplier.serialize(ref calldata);
        self.starkgate_address.serialize(ref calldata);
        self.governance_admin.serialize(ref calldata);
        let reward_supplier_contract = snforge_std::declare("RewardSupplier")
            .unwrap()
            .contract_class();
        let (reward_supplier_contract_address, _) = reward_supplier_contract
            .deploy(@calldata)
            .unwrap();
        let reward_supplier = RewardSupplierState {
            address: reward_supplier_contract_address,
            governance_admin: self.governance_admin,
            roles: self.roles,
        };
        reward_supplier.set_roles();
        reward_supplier
    }

    fn dispatcher(self: RewardSupplierState) -> IRewardSupplierDispatcher nopanic {
        IRewardSupplierDispatcher { contract_address: self.address }
    }

    fn set_roles(self: RewardSupplierState) {
        set_account_as_upgrade_governor(
            contract: self.address,
            account: self.roles.upgrade_governor,
            governance_admin: self.governance_admin,
        );
    }

    fn get_unclaimed_rewards(self: RewardSupplierState) -> Amount {
        self.dispatcher().contract_parameters().try_into().unwrap().unclaimed_rewards
    }
}

/// The `SystemConfig` struct represents the configuration settings for the entire system.
/// It includes configurations for the token, staking, minting curve, and reward supplier contracts.
#[derive(Drop)]
struct SystemConfig {
    token: TokenConfig,
    staking: StakingConfig,
    minting_curve: MintingCurveConfig,
    reward_supplier: RewardSupplierConfig,
}

/// The `SystemState` struct represents the state of the entire system.
/// It includes the state for the token, staking, minting curve, and reward supplier contracts,
/// as well as a base account identifier.
#[derive(Drop, Copy)]
pub struct SystemState<TTokenState> {
    pub token: TTokenState,
    pub staking: StakingState,
    pub minting_curve: MintingCurveState,
    pub reward_supplier: RewardSupplierState,
    pub base_account: felt252,
}

#[generate_trait]
pub impl SystemConfigImpl of SystemConfigTrait {
    /// Configures the basic staking flow by initializing the system configuration with the
    /// provided staking initialization configuration.
    fn basic_stake_flow_cfg(cfg: StakingInitConfig) -> SystemConfig {
        let token = TokenConfig {
            name: NAME(),
            symbol: SYMBOL(),
            initial_supply: cfg.test_info.initial_supply,
            owner: cfg.test_info.owner_address,
        };
        let staking = StakingConfig {
            min_stake: cfg.staking_contract_info.min_stake,
            pool_contract_class_hash: cfg.staking_contract_info.pool_contract_class_hash,
            reward_supplier: cfg.staking_contract_info.reward_supplier,
            pool_contract_admin: cfg.test_info.pool_contract_admin,
            governance_admin: cfg.test_info.governance_admin,
            roles: StakingRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                security_admin: cfg.test_info.security_admin,
                security_agent: cfg.test_info.security_agent,
                app_role_admin: cfg.test_info.app_role_admin,
                token_admin: cfg.test_info.token_admin,
            },
        };
        let minting_curve = MintingCurveConfig {
            initial_supply: cfg.test_info.initial_supply.try_into().unwrap(),
            governance_admin: cfg.test_info.governance_admin,
            l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
            roles: MintingCurveRoles {
                upgrade_governor: cfg.test_info.upgrade_governor,
                app_role_admin: cfg.test_info.app_role_admin,
                token_admin: cfg.test_info.token_admin,
            },
        };
        let reward_supplier = RewardSupplierConfig {
            base_mint_amount: cfg.reward_supplier.base_mint_amount,
            l1_reward_supplier: cfg.reward_supplier.l1_reward_supplier,
            starkgate_address: cfg.reward_supplier.starkgate_address,
            governance_admin: cfg.test_info.governance_admin,
            roles: RewardSupplierRoles { upgrade_governor: cfg.test_info.upgrade_governor },
        };
        SystemConfig { token, staking, minting_curve, reward_supplier }
    }

    /// Deploys the system configuration and returns the system state.
    fn deploy(self: SystemConfig) -> SystemState<TokenState> {
        let token = self.token.deploy();
        let staking = self.staking.deploy(:token);
        let minting_curve = self.minting_curve.deploy(:staking);
        let reward_supplier = self.reward_supplier.deploy(:minting_curve, :staking, :token);
        // Fund reward supplier
        token
            .fund(
                recipient: reward_supplier.address, amount: self.minting_curve.initial_supply / 10,
            );
        // Set reward_supplier in staking
        let contract_address = staking.address;
        let staking_config_dispatcher = IStakingConfigDispatcher { contract_address };
        cheat_caller_address_once(:contract_address, caller_address: staking.roles.token_admin);
        staking_config_dispatcher.set_reward_supplier(reward_supplier: reward_supplier.address);
        SystemState { token, staking, minting_curve, reward_supplier, base_account: 0x100000 }
    }
}

#[generate_trait]
pub impl SystemImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of SystemTrait<TTokenState> {
    /// Creates a new account with the specified amount.
    fn new_account(ref self: SystemState<TTokenState>, amount: Amount) -> Account {
        self.base_account += 1;
        let account = AccountTrait::new(address: self.base_account, amount: amount);
        self.token.fund(recipient: account.address, :amount);
        account
    }

    /// Creates a new staker with the specified amount.
    fn new_staker(ref self: SystemState<TTokenState>, amount: Amount) -> Staker {
        let staker = self.new_account(:amount);
        let reward = self.new_account(amount: Zero::zero());
        let operational = self.new_account(amount: Zero::zero());
        StakerTrait::new(:staker, :reward, :operational)
    }

    /// Creates a new delegator with the specified amount.
    fn new_delegator(ref self: SystemState<TTokenState>, amount: Amount) -> Delegator {
        let delegator = self.new_account(:amount);
        let reward = self.new_account(amount: Zero::zero());
        DelegatorTrait::new(:delegator, :reward)
    }

    /// Advances the block timestamp by the specified amount of time.
    fn advance_time(ref self: SystemState<TTokenState>, time: TimeDelta) {
        start_cheat_block_timestamp_global(block_timestamp: Time::now().add(delta: time).into())
    }
}

/// The `Account` struct represents an account in the staking system.
/// It includes the account's address, amount of tokens, token state, and staking state.
#[derive(Drop, Copy)]
pub struct Account {
    pub address: ContractAddress,
    pub amount: Amount,
}

#[generate_trait]
pub impl AccountImpl of AccountTrait {
    fn new(address: felt252, amount: Amount) -> Account {
        Account { address: address.try_into().unwrap(), amount }
    }
}

/// The `Staker` struct represents a staker in the staking system.
/// It includes the staker's account, reward account, and operational account.
#[derive(Drop, Copy)]
pub struct Staker {
    pub staker: Account,
    pub reward: Account,
    pub operational: Account,
}

#[generate_trait]
impl StakerImpl of StakerTrait {
    fn new(staker: Account, reward: Account, operational: Account) -> Staker nopanic {
        Staker { staker, reward, operational }
    }
}

#[generate_trait]
pub impl SystemStakerImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of SystemStakerTrait<TTokenState> {
    fn stake(
        self: SystemState<TTokenState>,
        staker: Staker,
        amount: Amount,
        pool_enabled: bool,
        commission: Commission,
    ) {
        self.token.approve(owner: staker.staker.address, spender: self.staking.address, :amount);
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self
            .staking
            .dispatcher()
            .stake(
                reward_address: staker.reward.address,
                operational_address: staker.operational.address,
                :amount,
                :pool_enabled,
                :commission,
            )
    }

    fn increase_stake(self: SystemState<TTokenState>, staker: Staker, amount: Amount) -> Amount {
        self.token.approve(owner: staker.staker.address, spender: self.staking.address, :amount);
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().increase_stake(staker_address: staker.staker.address, :amount)
    }

    fn staker_exit_intent(self: SystemState<TTokenState>, staker: Staker) -> Timestamp {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().unstake_intent()
    }

    fn staker_exit_action(self: SystemState<TTokenState>, staker: Staker) -> Amount {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().unstake_action(staker_address: staker.staker.address)
    }

    fn set_open_for_delegation(
        self: SystemState<TTokenState>, staker: Staker, commission: Commission,
    ) -> ContractAddress {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().set_open_for_delegation(:commission)
    }

    fn staker_claim_rewards(self: SystemState<TTokenState>, staker: Staker) -> Amount {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().claim_rewards(staker_address: staker.staker.address)
    }

    fn update_commission(self: SystemState<TTokenState>, staker: Staker, commission: Commission) {
        cheat_caller_address_once(
            contract_address: self.staking.address, caller_address: staker.staker.address,
        );
        self.staking.dispatcher().update_commission(:commission)
    }
}

/// The `Delegator` struct represents a delegator in the staking system.
/// It includes the delegator's account and reward account.
#[derive(Drop, Copy)]
pub struct Delegator {
    pub delegator: Account,
    pub reward: Account,
}

#[generate_trait]
impl DelegatorImpl of DelegatorTrait {
    fn new(delegator: Account, reward: Account) -> Delegator nopanic {
        Delegator { delegator, reward }
    }
}

#[generate_trait]
pub impl SystemDelegatorImpl<
    TTokenState, +TokenTrait<TTokenState>, +Drop<TTokenState>, +Copy<TTokenState>,
> of SystemDelegatorTrait<TTokenState> {
    fn delegate(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.enter_delegation_pool(reward_address: delegator.reward.address, :amount)
    }

    fn increase_delegate(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) -> Amount {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.add_to_delegation_pool(pool_member: delegator.delegator.address, :amount)
    }

    fn delegator_exit_intent(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.exit_delegation_pool_intent(:amount)
    }

    fn delegator_exit_action(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.exit_delegation_pool_action(pool_member: delegator.delegator.address)
    }

    fn switch_delegation_pool(
        self: SystemState<TTokenState>,
        delegator: Delegator,
        from_pool: ContractAddress,
        to_staker: ContractAddress,
        to_pool: ContractAddress,
        amount: Amount,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: from_pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: from_pool };
        pool_dispatcher.switch_delegation_pool(:to_staker, :to_pool, :amount)
    }

    fn delegator_claim_rewards(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress,
    ) -> Amount {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.claim_rewards(pool_member: delegator.delegator.address)
    }

    fn delegator_change_reward_address(
        self: SystemState<TTokenState>,
        delegator: Delegator,
        pool: ContractAddress,
        reward_address: ContractAddress,
    ) {
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.change_reward_address(:reward_address)
    }

    fn add_to_delegation_pool(
        self: SystemState<TTokenState>, delegator: Delegator, pool: ContractAddress, amount: Amount,
    ) -> Amount {
        self.token.approve(owner: delegator.delegator.address, spender: pool, :amount);
        cheat_caller_address_once(
            contract_address: pool, caller_address: delegator.delegator.address,
        );
        let pool_dispatcher = IPoolDispatcher { contract_address: pool };
        pool_dispatcher.add_to_delegation_pool(pool_member: delegator.delegator.address, :amount)
    }
}

// This interface is implemented by the `STRK` token contract.
#[starknet::interface]
trait IMintableToken<TContractState> {
    fn permissioned_mint(ref self: TContractState, account: ContractAddress, amount: u256);
    fn permissioned_burn(ref self: TContractState, account: ContractAddress, amount: u256);
}

/// The `STRKTokenState` struct represents the state of the `STRK` token contract.
/// It includes the `STRK` token address.
#[derive(Drop, Copy)]
pub struct STRKTokenState {
    pub address: ContractAddress,
}

impl STRKTTokenImpl of TokenTrait<STRKTokenState> {
    fn fund(self: STRKTokenState, recipient: ContractAddress, amount: u128) {
        let mintable_token_dispatcher = IMintableTokenDispatcher { contract_address: self.address };
        cheat_caller_address_once(
            contract_address: self.address, caller_address: MAINNET_L2_BRIDGE_ADDRESS(),
        );
        mintable_token_dispatcher.permissioned_mint(account: recipient, amount: amount.into());
    }

    fn approve(
        self: STRKTokenState, owner: ContractAddress, spender: ContractAddress, amount: u128,
    ) {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        cheat_caller_address_once(contract_address: self.address, caller_address: owner);
        erc20_dispatcher.approve(spender: spender, amount: amount.into());
    }

    fn balance_of(self: STRKTokenState, account: ContractAddress) -> u128 {
        let erc20_dispatcher = IERC20Dispatcher { contract_address: self.address };
        erc20_dispatcher.balance_of(account: account).try_into().unwrap()
    }
}

#[generate_trait]
/// Replaceability utils for internal use of the system. Meant to be used before running a
/// regression test.
impl SystemReplaceabilityImpl of SystemReplaceabilityTrait {
    /// Upgrades the contracts in the system state with local implementations.
    fn upgrade_contracts_implementation(self: SystemState<STRKTokenState>) {
        self.upgrade_staking_implementation();
        self.upgrade_reward_supplier_implementation();
        self.upgrade_minting_curve_implementation();
    }

    /// Upgrades the staking contract in the system state with a local implementation.
    fn upgrade_staking_implementation(self: SystemState<STRKTokenState>) {
        let implementation_data = ImplementationData {
            impl_hash: declare_staking_contract(), eic_data: Option::None, final: false,
        };
        upgrade_implementation(
            contract_address: self.staking.address,
            :implementation_data,
            upgrade_governor: self.staking.roles.upgrade_governor,
        );
    }

    /// Upgrades the reward supplier contract in the system state with a local implementation.
    fn upgrade_reward_supplier_implementation(self: SystemState<STRKTokenState>) {
        let implementation_data = ImplementationData {
            impl_hash: declare_reward_supplier_contract(), eic_data: Option::None, final: false,
        };
        upgrade_implementation(
            contract_address: self.reward_supplier.address,
            :implementation_data,
            upgrade_governor: self.reward_supplier.roles.upgrade_governor,
        );
    }

    /// Upgrades the minting curve contract in the system state with a local implementation.
    fn upgrade_minting_curve_implementation(self: SystemState<STRKTokenState>) {
        let implementation_data = ImplementationData {
            impl_hash: declare_minting_curve_contract(), eic_data: Option::None, final: false,
        };
        upgrade_implementation(
            contract_address: self.minting_curve.address,
            :implementation_data,
            upgrade_governor: self.minting_curve.roles.upgrade_governor,
        );
    }
}

fn declare_staking_contract() -> ClassHash {
    *snforge_std::declare("Staking").unwrap().contract_class().class_hash
}

fn declare_reward_supplier_contract() -> ClassHash {
    *snforge_std::declare("RewardSupplier").unwrap().contract_class().class_hash
}

fn declare_minting_curve_contract() -> ClassHash {
    *snforge_std::declare("MintingCurve").unwrap().contract_class().class_hash
}

/// Upgrades implementation of the given contract.
fn upgrade_implementation(
    contract_address: ContractAddress,
    implementation_data: ImplementationData,
    upgrade_governor: ContractAddress,
) {
    let replaceability_dispatcher = IReplaceableDispatcher { contract_address };
    cheat_caller_address_once(:contract_address, caller_address: upgrade_governor);
    replaceability_dispatcher.add_new_implementation(:implementation_data);
    cheat_caller_address_once(:contract_address, caller_address: upgrade_governor);
    replaceability_dispatcher.replace_to(:implementation_data);
}

#[generate_trait]
/// System factory for creating system states used in flow and regression tests.
impl SystemFactoryImpl of SystemFactoryTrait {
    // System state used for flow tests.
    fn local_system() -> SystemState<TokenState> {
        let cfg: StakingInitConfig = Default::default();
        SystemConfigTrait::basic_stake_flow_cfg(:cfg).deploy()
    }

    // System state used for regression tests.
    fn mainnet_system() -> SystemState<STRKTokenState> {
        let system_state = SystemState {
            token: STRKTokenState { address: STRK_TOKEN_ADDRESS() },
            staking: mainnet_staking_state(),
            minting_curve: mainnet_minting_curve_state(),
            reward_supplier: mainnet_reward_supplier_state(),
            base_account: 0x100000,
        };
        system_state
    }
}

fn mainnet_staking_state() -> StakingState {
    StakingState {
        address: MAINNET_STAKING_CONTRCT_ADDRESS(),
        governance_admin: Zero::zero(),
        roles: StakingRoles {
            upgrade_governor: MAINNET_UPGRADE_GOVERNOR(),
            security_admin: Zero::zero(),
            security_agent: Zero::zero(),
            app_role_admin: Zero::zero(),
            token_admin: Zero::zero(),
        },
    }
}

fn mainnet_minting_curve_state() -> MintingCurveState {
    MintingCurveState {
        address: MAINNET_MINTING_CURVE_ADDRESS(),
        governance_admin: Zero::zero(),
        roles: MintingCurveRoles {
            upgrade_governor: MAINNET_UPGRADE_GOVERNOR(),
            app_role_admin: Zero::zero(),
            token_admin: Zero::zero(),
        },
    }
}

fn mainnet_reward_supplier_state() -> RewardSupplierState {
    RewardSupplierState {
        address: MAINNET_REWARD_SUPPLIER_ADDRESS(),
        governance_admin: Zero::zero(),
        roles: RewardSupplierRoles { upgrade_governor: MAINNET_UPGRADE_GOVERNOR() },
    }
}
