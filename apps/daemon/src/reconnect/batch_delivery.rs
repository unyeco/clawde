use crate::ipc::event::EventBroadcaster;
use crate::reconnect::PendingOpsQueue;
use serde_json::json;

/// Called by the IPC server when a new client connection is established.
///
/// Drains any file ops that were buffered while no client was connected and
/// broadcasts them as a single `file.batchReplay` notification so the Flutter
/// app can reconcile its local state in one pass.
///
/// If the queue is empty this function returns immediately without broadcasting.
pub async fn drain_on_reconnect(queue: &PendingOpsQueue, broadcaster: &EventBroadcaster) {
    let ops = queue.drain().await;
    if ops.is_empty() {
        return;
    }

    let count = ops.len();
    broadcaster.broadcast(
        "file.batchReplay",
        json!({
            "ops": ops,
            "count": count,
        }),
    );
}
