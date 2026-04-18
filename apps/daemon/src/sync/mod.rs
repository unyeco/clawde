//! ClawDE+ server-sync — pushes session snapshots to the ClawDE backend so
//! remote mobile clients and team members can see current session state.
//!
//! Only active when `license.features.clawde_plus == true`.
//!
//! Protocol:
//! - Every 30 seconds, POST `{api_base_url}/sync/sessions` with a JSON body:
//!   `{ "daemonId": "...", "sessions": [ { "id", "title", "status", "updatedAt" } ] }`
//! - Authorization: Bearer {license_token}
//! - 401/403 → log warning + stop syncing (license revoked)
//! - Network error → retry with 60s backoff, max 3 retries before skipping this cycle

use anyhow::Result;
use std::sync::Arc;
use std::time::Duration;
use tokio::time::interval;
use tracing::{info, warn};

use crate::config::DaemonConfig;
use crate::license::LicenseInfo;
use crate::session::SessionManager;

// ─── Sync payload ─────────────────────────────────────────────────────────────

/// Lightweight session snapshot sent to the server.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionSyncEntry {
    pub id: String,
    pub title: String,
    pub status: String,
    pub updated_at: String,
}

#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SyncPayload<'a> {
    daemon_id: &'a str,
    sessions: Vec<SessionSyncEntry>,
}

// ─── SyncService ──────────────────────────────────────────────────────────────

pub struct SyncService {
    config: Arc<DaemonConfig>,
    daemon_id: String,
    license: LicenseInfo,
    sessions: Arc<SessionManager>,
}

impl SyncService {
    pub fn new(
        config: Arc<DaemonConfig>,
        daemon_id: String,
        license: LicenseInfo,
        sessions: Arc<SessionManager>,
    ) -> Self {
        Self {
            config,
            daemon_id,
            license,
            sessions,
        }
    }

    /// Starts the background sync loop. No-op if `!license.features.clawde_plus`.
    pub async fn start(&self) {
        if !self.license.features.clawde_plus {
            return;
        }

        // Early-exit guard: a ClawDE+ feature flag without a token is a misconfiguration.
        if self.config.license_token.as_deref().map_or(true, str::is_empty) {
            warn!("sync: clawde_plus enabled but no license token — skipping sync");
            return;
        }

        info!("sync: ClawDE+ server-sync started (30s interval)");

        let mut ticker = interval(Duration::from_secs(30));
        ticker.tick().await; // consume the immediate first tick

        loop {
            ticker.tick().await;
            if let Err(e) = self.tick().await {
                warn!("sync: tick error: {e:#}");
            }
        }
    }

    /// Single sync cycle — collects sessions and POSTs to the server.
    /// Retries up to 3 times with 60s backoff on transient network errors.
    /// Stops permanently on 401/403 (license revoked).
    async fn tick(&self) -> Result<()> {
        let token = match &self.config.license_token {
            Some(t) if !t.is_empty() => t.clone(),
            _ => return Ok(()), // no token — skip silently
        };

        let session_views = self.sessions.list().await?;
        let entries: Vec<SessionSyncEntry> = session_views
            .into_iter()
            .map(|s| SessionSyncEntry {
                id: s.id,
                title: s.title,
                status: s.status,
                updated_at: s.updated_at,
            })
            .collect();

        let url = format!("{}/sync/sessions", self.config.api_base_url);
        let client = reqwest::Client::builder()
            .timeout(Duration::from_secs(15))
            .build()?;

        let mut last_err: Option<anyhow::Error> = None;
        for attempt in 0..3u8 {
            if attempt > 0 {
                tokio::time::sleep(Duration::from_secs(60)).await;
            }

            let payload = SyncPayload {
                daemon_id: &self.daemon_id,
                sessions: entries
                    .iter()
                    .map(|e| SessionSyncEntry {
                        id: e.id.clone(),
                        title: e.title.clone(),
                        status: e.status.clone(),
                        updated_at: e.updated_at.clone(),
                    })
                    .collect(),
            };

            let resp = match client
                .post(&url)
                .bearer_auth(&token)
                .json(&payload)
                .send()
                .await
            {
                Ok(r) => r,
                Err(e) => {
                    last_err = Some(e.into());
                    continue;
                }
            };

            let status = resp.status();
            if status == reqwest::StatusCode::UNAUTHORIZED
                || status == reqwest::StatusCode::FORBIDDEN
            {
                warn!("sync: license revoked ({}); stopping ClawDE+ sync", status);
                // Return an error that signals the caller to stop the sync loop.
                return Err(anyhow::anyhow!("sync: license revoked — stopping ({})", status));
            }

            if !status.is_success() {
                last_err = Some(anyhow::anyhow!("sync: server returned {}", status));
                continue;
            }

            return Ok(());
        }

        Err(last_err.unwrap_or_else(|| anyhow::anyhow!("sync: unknown error after retries")))
    }
}

// ─── Module entry point ───────────────────────────────────────────────────────

/// Spawn the sync background task if ClawDE+ is enabled.
/// Returns `true` if the task was started, `false` if disabled.
pub async fn spawn_if_enabled(
    config: Arc<DaemonConfig>,
    license: &LicenseInfo,
    daemon_id: String,
    sessions: Arc<SessionManager>,
) -> bool {
    if !license.features.clawde_plus {
        return false;
    }

    let service = SyncService::new(config, daemon_id, license.clone(), sessions);
    tokio::spawn(async move {
        service.start().await;
    });
    info!("sync: ClawDE+ sync task spawned");
    true
}
