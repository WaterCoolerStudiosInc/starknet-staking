use contracts::types::{Amount, Index, Inflation};
use contracts_commons::constants::{MINUTE, WEEK};
use contracts_commons::types::time::TimeDelta;

pub(crate) const DEFAULT_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 3 * WEEK };
pub(crate) const MAX_EXIT_WAIT_WINDOW: TimeDelta = TimeDelta { seconds: 12 * WEEK };
pub(crate) const BASE_VALUE: Index = 10_000_000_000_000_000_000_000_000_000; // 10**28
pub(crate) const MIN_TIME_BETWEEN_INDEX_UPDATES: TimeDelta = TimeDelta { seconds: 30 * MINUTE };
pub(crate) const STRK_IN_FRIS: Amount = 1_000_000_000_000_000_000; // 10**18
pub(crate) const DEFAULT_C_NUM: Inflation = 160;
pub(crate) const MAX_C_NUM: Inflation = 500;
pub(crate) const C_DENOM: Inflation = 10_000;
