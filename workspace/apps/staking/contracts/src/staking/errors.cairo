use contracts_commons::errors::{Describable, ErrorDisplay};
use staking::staking::staking::Staking::COMMISSION_DENOMINATOR;

#[derive(Drop)]
pub enum Error {
    AMOUNT_LESS_THAN_MIN_STAKE,
    COMMISSION_OUT_OF_RANGE,
    UNSTAKE_IN_PROGRESS,
    POOL_ADDRESS_DOES_NOT_EXIST,
    CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    MISSING_UNSTAKE_INTENT,
    CALLER_IS_NOT_POOL_CONTRACT,
    MISSING_POOL_CONTRACT,
    DELEGATION_POOL_MISMATCH,
    GLOBAL_INDEX_DIFF_NOT_INDEX_TYPE,
    GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW,
    UNEXPECTED_BALANCE,
    STAKER_ALREADY_HAS_POOL,
    CONTRACT_IS_PAUSED,
    INVALID_UNDELEGATE_INTENT_VALUE,
    OPERATIONAL_NOT_ELIGIBLE,
    OPERATIONAL_IN_USE,
    CALLER_IS_ZERO_ADDRESS,
    SELF_SWITCH_NOT_ALLOWED,
    ILLEGAL_EXIT_DURATION,
}

impl DescribableError of Describable<Error> {
    #[inline(always)]
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::OPERATIONAL_NOT_ELIGIBLE => "Operational address had not been declared by staker",
            Error::OPERATIONAL_IN_USE => "Operational address is in use",
            Error::AMOUNT_LESS_THAN_MIN_STAKE => "Amount is less than min stake - try again with enough funds",
            Error::COMMISSION_OUT_OF_RANGE => format!(
                "Commission is out of range, expected to be 0-{}", COMMISSION_DENOMINATOR,
            ),
            Error::POOL_ADDRESS_DOES_NOT_EXIST => "Pool address does not exist",
            Error::MISSING_UNSTAKE_INTENT => "Unstake intent is missing",
            Error::UNSTAKE_IN_PROGRESS => "Unstake is in progress, staker is in an exit window",
            Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => "Claim rewards must be called from staker address or reward address",
            Error::CALLER_IS_NOT_POOL_CONTRACT => "Caller is not pool contract",
            Error::MISSING_POOL_CONTRACT => "Staker does not have a pool contract",
            Error::DELEGATION_POOL_MISMATCH => "to_pool is not the delegation pool contract for to_staker",
            Error::GLOBAL_INDEX_DIFF_NOT_INDEX_TYPE => "Global index diff does not fit in u128",
            Error::GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW => "Overflow during computation global index diff",
            Error::UNEXPECTED_BALANCE => "Unexpected balance",
            Error::STAKER_ALREADY_HAS_POOL => "Staker already has a pool",
            Error::CONTRACT_IS_PAUSED => "Contract is paused",
            Error::INVALID_UNDELEGATE_INTENT_VALUE => "Invalid undelegate intent value",
            Error::CALLER_IS_ZERO_ADDRESS => "Zero address caller is not allowed",
            Error::SELF_SWITCH_NOT_ALLOWED => "SELF_SWITCH_NOT_ALLOWED",
            Error::ILLEGAL_EXIT_DURATION => "ILLEGAL_EXIT_DURATION",
        }
    }
}
