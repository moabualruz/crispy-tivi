mod controller;
mod runtime;
mod source_registry;

#[cfg(test)]
mod tests;

pub use controller::{commit_source_setup_json, update_source_setup_json};
pub use runtime::{
    HydratedRuntimeSnapshot, RuntimeBundleSnapshot, runtime_bundle_json,
    runtime_bundle_json_from_source_registry_json, runtime_bundle_snapshot,
    runtime_bundle_snapshot_from_source_registry,
};
#[cfg(test)]
pub(crate) use source_registry::seeded_source_registry_snapshot;
pub use source_registry::{
    SourceAuthSnapshot, SourceCapabilitySnapshot, SourceHealthSnapshot,
    SourceImportDetailsSnapshot, SourceOnboardingSnapshot, SourceProviderEntrySnapshot,
    SourceProviderWizardCopySnapshot, SourceRegistrySnapshot, SourceWizardStepDescriptorSnapshot,
    source_registry_json, source_registry_snapshot,
};
