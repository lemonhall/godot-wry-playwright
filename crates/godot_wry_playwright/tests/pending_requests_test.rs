use godot_wry_playwright::pending::PendingRequests;

#[test]
fn expires_requests_at_deadline() {
  let mut pending = PendingRequests::new();
  let id = pending.new_request(100, 50);
  assert!(pending.expired(149).is_empty());
  let expired = pending.expired(150);
  assert_eq!(expired, vec![id]);
}

#[test]
fn complete_removes_pending_request() {
  let mut pending = PendingRequests::new();
  let id = pending.new_request(100, 50);
  assert!(pending.complete(id));
  assert!(pending.expired(1000).is_empty());
}

#[test]
fn insert_tracks_explicit_request_id() {
  let mut pending = PendingRequests::new();
  pending.insert(42, 100, 50);
  assert_eq!(pending.expired(150), vec![42]);
}
