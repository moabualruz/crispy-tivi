use std::collections::HashMap;

use super::source_registry::build_provider_commit_shape;
use super::source_registry::seeded_source_registry_snapshot;
use super::{
    SourceProviderEntrySnapshot, SourceRegistrySnapshot,
    runtime_bundle_snapshot_from_source_registry,
};

pub fn update_source_setup_json(
    source_registry_json: &str,
    action: &str,
    selected_provider_type: Option<&str>,
    selected_source_index: Option<i32>,
    target_step: Option<&str>,
    field_key: Option<&str>,
    field_value: Option<&str>,
) -> Result<String, String> {
    let source_registry: SourceRegistrySnapshot = serde_json::from_str(source_registry_json)
        .map_err(|error| format!("source runtime registry JSON parse failed: {error}"))?;
    let updated = apply_source_setup_action(
        source_registry,
        action,
        selected_provider_type,
        selected_source_index,
        target_step,
        field_key,
        field_value,
    )?;
    serde_json::to_string_pretty(&updated)
        .map_err(|error| format!("source setup state serialization failed: {error}"))
}

pub fn commit_source_setup_json(source_registry_json: &str) -> Result<String, String> {
    let source_registry: SourceRegistrySnapshot = serde_json::from_str(source_registry_json)
        .map_err(|error| format!("source runtime registry JSON parse failed: {error}"))?;
    let updated = commit_source_setup(source_registry)?;
    serde_json::to_string_pretty(&runtime_bundle_snapshot_from_source_registry(updated))
        .map_err(|error| format!("source runtime committed bundle serialization failed: {error}"))
}

fn apply_source_setup_action(
    mut source_registry: SourceRegistrySnapshot,
    action: &str,
    selected_provider_type: Option<&str>,
    selected_source_index: Option<i32>,
    target_step: Option<&str>,
    field_key: Option<&str>,
    field_value: Option<&str>,
) -> Result<SourceRegistrySnapshot, String> {
    match action {
        "seed_demo" => return Ok(seeded_source_registry_snapshot()),
        "select_source" => {
            let index = normalized_index(
                selected_source_index.unwrap_or(source_registry.onboarding.selected_source_index),
            );
            let provider = source_registry
                .configured_providers
                .get(index)
                .cloned()
                .ok_or_else(|| format!("configured provider index {index} is out of range"))?;
            source_registry.onboarding.selected_source_index = index as i32;
            source_registry.onboarding.selected_provider_kind = provider.provider_type;
            clear_wizard_state(&mut source_registry);
        }
        "start_add" => {
            if let Some(provider_type) = selected_provider_type {
                ensure_provider_type_exists(&source_registry, provider_type)?;
                source_registry.onboarding.selected_provider_kind = provider_type.to_owned();
            }
            source_registry.onboarding.wizard_active = true;
            source_registry.onboarding.wizard_mode = "add".to_owned();
            source_registry.onboarding.active_wizard_step = first_step(&source_registry)?;
            source_registry.onboarding.field_values.clear();
        }
        "start_edit" => {
            let index =
                selected_source_index.unwrap_or(source_registry.onboarding.selected_source_index);
            seed_selected_provider(&mut source_registry, index)?;
            source_registry.onboarding.wizard_active = true;
            source_registry.onboarding.wizard_mode = "edit".to_owned();
            source_registry.onboarding.active_wizard_step =
                preferred_step(&source_registry, "Connection")?;
            source_registry.onboarding.field_values.clear();
        }
        "start_reconnect" => {
            let index =
                selected_source_index.unwrap_or(source_registry.onboarding.selected_source_index);
            seed_selected_provider(&mut source_registry, index)?;
            source_registry.onboarding.wizard_active = true;
            source_registry.onboarding.wizard_mode = "reconnect".to_owned();
            source_registry.onboarding.active_wizard_step =
                preferred_step(&source_registry, "Credentials")?;
            source_registry.onboarding.field_values.clear();
        }
        "start_import" => {
            let index =
                selected_source_index.unwrap_or(source_registry.onboarding.selected_source_index);
            seed_selected_provider(&mut source_registry, index)?;
            source_registry.onboarding.wizard_active = true;
            source_registry.onboarding.wizard_mode = "import".to_owned();
            source_registry.onboarding.active_wizard_step =
                preferred_step(&source_registry, "Import")?;
            source_registry.onboarding.field_values.clear();
        }
        "select_provider_type" => {
            let provider_type = selected_provider_type
                .ok_or_else(|| "selected_provider_type is required".to_owned())?;
            ensure_provider_type_exists(&source_registry, provider_type)?;
            source_registry.onboarding.selected_provider_kind = provider_type.to_owned();
            source_registry
                .onboarding
                .field_values
                .insert("source_type".to_owned(), provider_type.to_owned());
        }
        "select_wizard_step" => {
            if !source_registry.onboarding.wizard_active {
                return Ok(source_registry);
            }
            let target = target_step.ok_or_else(|| "target_step is required".to_owned())?;
            ensure_step_exists(&source_registry, target)?;
            source_registry.onboarding.active_wizard_step = target.to_owned();
        }
        "update_field" => {
            let key = field_key.ok_or_else(|| "field_key is required".to_owned())?;
            let value = field_value.ok_or_else(|| "field_value is required".to_owned())?;
            source_registry
                .onboarding
                .field_values
                .insert(key.to_owned(), value.to_owned());
        }
        "advance_wizard" => {
            if !source_registry.onboarding.wizard_active {
                return Ok(source_registry);
            }
            let current_index = step_index(&source_registry)?;
            if current_index + 1 < source_registry.onboarding.step_order.len() {
                source_registry.onboarding.active_wizard_step =
                    source_registry.onboarding.step_order[current_index + 1].clone();
            }
        }
        "retreat_wizard" => {
            if !source_registry.onboarding.wizard_active {
                return Ok(source_registry);
            }
            let current_index = step_index(&source_registry)?;
            if current_index > 0 {
                source_registry.onboarding.active_wizard_step =
                    source_registry.onboarding.step_order[current_index - 1].clone();
            } else {
                clear_wizard_state(&mut source_registry);
            }
        }
        "clear_wizard" => clear_wizard_state(&mut source_registry),
        other => return Err(format!("unsupported source setup action `{other}`")),
    }

    Ok(source_registry)
}

fn commit_source_setup(
    mut source_registry: SourceRegistrySnapshot,
) -> Result<SourceRegistrySnapshot, String> {
    let provider_type = source_registry.onboarding.selected_provider_kind.clone();
    let wizard_mode = source_registry.onboarding.wizard_mode.clone();
    let selected_source_index = source_registry.onboarding.selected_source_index;
    let field_values = source_registry.onboarding.field_values.clone();
    let template = source_registry
        .provider_types
        .iter()
        .find(|provider| provider.provider_type == provider_type)
        .cloned()
        .ok_or_else(|| format!("source provider type `{provider_type}` not found in catalog"))?;

    let committed = build_committed_provider(template, &wizard_mode, &field_values);
    let slot_index = normalized_index(selected_source_index);

    match wizard_mode.as_str() {
        "add" => {
            source_registry.configured_providers.push(committed);
            source_registry.onboarding.selected_source_index =
                (source_registry.configured_providers.len() - 1) as i32;
        }
        "edit" | "reconnect" | "import" => {
            if source_registry.configured_providers.is_empty() {
                source_registry.configured_providers.push(committed);
                source_registry.onboarding.selected_source_index = 0;
            } else if slot_index < source_registry.configured_providers.len() {
                source_registry.configured_providers[slot_index] = committed;
                source_registry.onboarding.selected_source_index = slot_index as i32;
            } else {
                source_registry.configured_providers.push(committed);
                source_registry.onboarding.selected_source_index =
                    (source_registry.configured_providers.len() - 1) as i32;
            }
        }
        "idle" => return Ok(source_registry),
        other => return Err(format!("unsupported source setup wizard mode `{other}`")),
    }

    source_registry.onboarding.selected_provider_kind = provider_type;
    source_registry.onboarding.active_wizard_step = first_step(&source_registry)?;
    clear_wizard_state(&mut source_registry);
    Ok(source_registry)
}

fn clear_wizard_state(source_registry: &mut SourceRegistrySnapshot) {
    source_registry.onboarding.wizard_active = false;
    source_registry.onboarding.wizard_mode = "idle".to_owned();
    source_registry.onboarding.active_wizard_step = source_registry
        .onboarding
        .step_order
        .first()
        .cloned()
        .unwrap_or_else(|| "Source Type".to_owned());
    source_registry.onboarding.field_values.clear();
}

fn first_step(source_registry: &SourceRegistrySnapshot) -> Result<String, String> {
    source_registry
        .onboarding
        .step_order
        .first()
        .cloned()
        .ok_or_else(|| "source wizard step order is empty".to_owned())
}

fn preferred_step(
    source_registry: &SourceRegistrySnapshot,
    preferred: &str,
) -> Result<String, String> {
    if source_registry
        .onboarding
        .step_order
        .iter()
        .any(|step| step == preferred)
    {
        Ok(preferred.to_owned())
    } else {
        first_step(source_registry)
    }
}

fn ensure_provider_type_exists(
    source_registry: &SourceRegistrySnapshot,
    provider_type: &str,
) -> Result<(), String> {
    if source_registry
        .provider_types
        .iter()
        .any(|provider| provider.provider_type == provider_type)
    {
        Ok(())
    } else {
        Err(format!(
            "source provider type `{provider_type}` not found in catalog"
        ))
    }
}

fn ensure_step_exists(
    source_registry: &SourceRegistrySnapshot,
    target_step: &str,
) -> Result<(), String> {
    if source_registry
        .onboarding
        .step_order
        .iter()
        .any(|step| step == target_step)
    {
        Ok(())
    } else {
        Err(format!(
            "source setup step `{target_step}` not found in wizard order"
        ))
    }
}

fn step_index(source_registry: &SourceRegistrySnapshot) -> Result<usize, String> {
    source_registry
        .onboarding
        .step_order
        .iter()
        .position(|step| step == &source_registry.onboarding.active_wizard_step)
        .ok_or_else(|| {
            format!(
                "active source setup step `{}` not found in wizard order",
                source_registry.onboarding.active_wizard_step
            )
        })
}

fn normalized_index(index: i32) -> usize {
    if index < 0 { 0 } else { index as usize }
}

fn seed_selected_provider(
    source_registry: &mut SourceRegistrySnapshot,
    index: i32,
) -> Result<(), String> {
    let normalized = normalized_index(index);
    let provider = source_registry
        .configured_providers
        .get(normalized)
        .cloned()
        .ok_or_else(|| format!("configured provider index {normalized} is out of range"))?;
    source_registry.onboarding.selected_source_index = normalized as i32;
    source_registry.onboarding.selected_provider_kind = provider.provider_type;
    Ok(())
}

fn build_committed_provider(
    mut template: SourceProviderEntrySnapshot,
    wizard_mode: &str,
    field_values: &HashMap<String, String>,
) -> SourceProviderEntrySnapshot {
    let display_name = value_or_fallback(
        field_values,
        "display_name",
        if template.display_name.trim().is_empty() {
            &template.provider_type
        } else {
            &template.display_name
        },
    );
    let shape = build_provider_commit_shape(
        &template.provider_type,
        &template.family,
        &template.connection_mode,
        &template.endpoint_label,
        wizard_mode,
        field_values,
    );
    template.display_name = display_name;
    template.summary = shape.summary;
    template.endpoint_label = shape.endpoint_label;
    template.health = shape.health;
    template.auth = shape.auth;
    template.import_details = shape.import_details;
    template.runtime_config = shape.runtime_config;
    template
}

fn value_or_fallback(field_values: &HashMap<String, String>, key: &str, fallback: &str) -> String {
    field_values
        .get(key)
        .map(|value| value.trim())
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_owned()
}
