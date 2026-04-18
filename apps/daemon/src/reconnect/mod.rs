pub mod batch_delivery;

use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::sync::Arc;
use tokio::sync::Mutex;

const MAX_BUFFERED_OPS: usize = 200;

/// A single file operation that occurred while no Flutter client was connected.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FileOp {
    pub op: String, // "read" | "write" | "delete" | "rename"
    pub path: String,
    pub session_id: String,
    pub timestamp: String, // ISO-8601
    #[serde(skip_serializing_if = "Option::is_none")]
    pub new_path: Option<String>, // for rename ops
}

/// A bounded queue of file operations buffered while no Flutter client is connected.
///
/// Capacity: max 200 ops. When the queue is full, the oldest op is dropped to
/// make room for the incoming one so that the newest state is always preserved.
#[derive(Clone)]
pub struct PendingOpsQueue {
    inner: Arc<Mutex<VecDeque<FileOp>>>,
}

impl Default for PendingOpsQueue {
    fn default() -> Self {
        Self::new()
    }
}

impl PendingOpsQueue {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(Mutex::new(VecDeque::with_capacity(MAX_BUFFERED_OPS))),
        }
    }

    /// Push a file op onto the queue.
    ///
    /// If the queue has reached `MAX_BUFFERED_OPS`, the oldest entry is evicted
    /// before the new one is inserted so that the most-recent ops are retained.
    pub async fn push(&self, op: FileOp) {
        let mut queue = self.inner.lock().await;
        if queue.len() >= MAX_BUFFERED_OPS {
            queue.pop_front();
        }
        queue.push_back(op);
    }

    /// Drain all pending ops and return them in insertion order (oldest first).
    ///
    /// The queue is empty after this call.
    pub async fn drain(&self) -> Vec<FileOp> {
        let mut queue = self.inner.lock().await;
        queue.drain(..).collect()
    }

    /// Returns `true` if there is at least one pending op in the queue.
    pub async fn has_pending(&self) -> bool {
        let queue = self.inner.lock().await;
        !queue.is_empty()
    }

    /// Returns the current number of ops in the queue.
    pub async fn len(&self) -> usize {
        let queue = self.inner.lock().await;
        queue.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_op(n: u32) -> FileOp {
        FileOp {
            op: "write".to_string(),
            path: format!("/tmp/file_{}.txt", n),
            session_id: format!("sess_{}", n),
            timestamp: format!("2024-01-01T00:00:{:02}Z", n % 60),
            new_path: None,
        }
    }

    #[tokio::test]
    async fn test_push_and_drain() {
        let q = PendingOpsQueue::new();

        q.push(make_op(1)).await;
        q.push(make_op(2)).await;
        q.push(make_op(3)).await;

        assert_eq!(q.len().await, 3);
        assert!(q.has_pending().await);

        let ops = q.drain().await;
        assert_eq!(ops.len(), 3);
        // Oldest first
        assert_eq!(ops[0].path, "/tmp/file_1.txt");
        assert_eq!(ops[1].path, "/tmp/file_2.txt");
        assert_eq!(ops[2].path, "/tmp/file_3.txt");

        // Queue is empty after drain
        assert_eq!(q.len().await, 0);
        assert!(!q.has_pending().await);
    }

    #[tokio::test]
    async fn test_capacity_drops_oldest() {
        let q = PendingOpsQueue::new();

        // Push 201 ops — op 0 should be evicted, op 1..=200 should remain.
        for i in 0..=200u32 {
            q.push(make_op(i)).await;
        }

        assert_eq!(q.len().await, MAX_BUFFERED_OPS);

        let ops = q.drain().await;
        assert_eq!(ops.len(), MAX_BUFFERED_OPS);

        // The first op (index 0) was evicted; the remaining 200 are ops 1..=200.
        assert_eq!(ops[0].path, "/tmp/file_1.txt");
        assert_eq!(ops[199].path, "/tmp/file_200.txt");
    }
}
