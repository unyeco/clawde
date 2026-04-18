//! Feature gate — enforces ClawDE+ requirements on RPC handlers.

use anyhow::Result;

use crate::license::LicenseInfo;

/// Error returned when a feature requires a higher subscription tier.
#[derive(Debug)]
pub struct FeatureGateError {
    pub feature: String,
    pub required_tier: String,
    pub current_tier: String,
}

impl std::fmt::Display for FeatureGateError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "feature '{}' requires {} tier (current: {})",
            self.feature, self.required_tier, self.current_tier
        )
    }
}

impl std::error::Error for FeatureGateError {}

/// Assert that the license has ClawDE+ active.
/// Returns `Err(FeatureGateError)` if the feature is not available on the
/// current tier.
pub fn require_clawde_plus(license: &LicenseInfo) -> Result<()> {
    if license.is_clawde_plus() {
        Ok(())
    } else {
        Err(anyhow::anyhow!(FeatureGateError {
            feature: "ClawDE+".to_string(),
            required_tier: "clawde_plus".to_string(),
            current_tier: license.tier.clone(),
        }))
    }
}

/// Assert that the license has the relay feature active.
/// Returns `Err(FeatureGateError)` if relay is not available on the current tier.
pub fn require_relay(license: &LicenseInfo) -> Result<()> {
    if license.is_relay_enabled() {
        Ok(())
    } else {
        Err(anyhow::anyhow!(FeatureGateError {
            feature: "relay".to_string(),
            required_tier: "personal_remote".to_string(),
            current_tier: license.tier.clone(),
        }))
    }
}

/// Assert that the license has the auto-switch feature active.
/// Returns `Err(FeatureGateError)` if auto-switch is not available on the
/// current tier.
pub fn require_auto_switch(license: &LicenseInfo) -> Result<()> {
    if license.is_auto_switch_enabled() {
        Ok(())
    } else {
        Err(anyhow::anyhow!(FeatureGateError {
            feature: "auto-switch".to_string(),
            required_tier: "cloud_pro".to_string(),
            current_tier: license.tier.clone(),
        }))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::license::{Features, LicenseInfo};

    fn make_license(tier: &str, relay: bool, auto_switch: bool, clawde_plus: bool) -> LicenseInfo {
        LicenseInfo {
            tier: tier.to_string(),
            features: Features {
                relay,
                auto_switch,
                clawde_plus,
            },
            grace_days_remaining: None,
        }
    }

    // ─── ClawDE+ gate ─────────────────────────────────────────────────────────

    #[test]
    fn test_clawde_plus_gate_passes_when_enabled() {
        let lic = make_license("clawde_plus", true, true, true);
        assert!(require_clawde_plus(&lic).is_ok());
    }

    #[test]
    fn test_clawde_plus_gate_fails_when_disabled() {
        let lic = LicenseInfo::free();
        let err = require_clawde_plus(&lic);
        assert!(err.is_err());
        assert!(err.unwrap_err().to_string().contains("ClawDE+"));
    }

    #[test]
    fn test_clawde_plus_gate_error_mentions_tier() {
        let lic = make_license("personal_remote", true, false, false);
        let err = require_clawde_plus(&lic).unwrap_err();
        let msg = err.to_string();
        assert!(msg.contains("clawde_plus"), "expected required_tier in message: {msg}");
        assert!(msg.contains("personal_remote"), "expected current_tier in message: {msg}");
    }

    // ─── Relay gate ───────────────────────────────────────────────────────────

    #[test]
    fn test_relay_gate_passes_when_enabled() {
        let lic = make_license("personal_remote", true, false, false);
        assert!(require_relay(&lic).is_ok());
    }

    #[test]
    fn test_relay_gate_fails_when_disabled() {
        let lic = LicenseInfo::free();
        let err = require_relay(&lic);
        assert!(err.is_err());
        assert!(err.unwrap_err().to_string().contains("relay"));
    }

    // ─── Auto-switch gate ─────────────────────────────────────────────────────

    #[test]
    fn test_auto_switch_gate_passes_when_enabled() {
        let lic = make_license("cloud_pro", true, true, true);
        assert!(require_auto_switch(&lic).is_ok());
    }

    #[test]
    fn test_auto_switch_gate_fails_when_disabled() {
        let lic = LicenseInfo::free();
        let err = require_auto_switch(&lic);
        assert!(err.is_err());
        assert!(err.unwrap_err().to_string().contains("auto-switch"));
    }
}
