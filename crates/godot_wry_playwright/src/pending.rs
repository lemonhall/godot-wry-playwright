use std::collections::HashMap;

#[derive(Debug, Clone, Copy)]
struct Pending {
  deadline_ms: u64,
}

#[derive(Debug, Default)]
pub struct PendingRequests {
  next_id: i64,
  pending: HashMap<i64, Pending>,
}

impl PendingRequests {
  pub fn new() -> Self {
    Self::default()
  }

  pub fn new_request(&mut self, now_ms: u64, timeout_ms: u64) -> i64 {
    self.next_id += 1;
    let id = self.next_id;
    self.pending.insert(
      id,
      Pending {
        deadline_ms: now_ms.saturating_add(timeout_ms),
      },
    );
    id
  }

  pub fn expired(&mut self, now_ms: u64) -> Vec<i64> {
    let mut expired: Vec<i64> = Vec::new();
    self.pending.retain(|id, p| {
      if p.deadline_ms <= now_ms {
        expired.push(*id);
        false
      } else {
        true
      }
    });
    expired
  }

  pub fn complete(&mut self, _id: i64) -> bool {
    self.pending.remove(&_id).is_some()
  }

  pub fn insert(&mut self, _id: i64, _now_ms: u64, _timeout_ms: u64) {
    self.pending.insert(
      _id,
      Pending {
        deadline_ms: _now_ms.saturating_add(_timeout_ms),
      },
    );
  }
}
