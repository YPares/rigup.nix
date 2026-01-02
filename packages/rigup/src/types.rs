use serde::Deserialize;
use serde_json::Value;
use std::collections::HashMap;

#[derive(Deserialize, Debug)]
pub struct RigletMeta {
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub keywords: Vec<String>,
    #[serde(default)]
    pub intent: String,
    #[serde(default)]
    pub status: String,
    #[serde(default)]
    pub disclosure: String,
    #[serde(default)]
    pub broken: bool,
    #[serde(default)]
    pub version: String,
    #[serde(rename = "whenToUse", default)]
    pub when_to_use: Vec<String>,
    #[serde(rename = "commandNames", default)]
    pub command_names: Vec<String>,
    #[serde(default)]
    pub entrypoint: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct RigMeta {
    pub riglets: HashMap<String, RigletMeta>,
    #[serde(default)]
    pub entrypoint: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct InputData {
    #[serde(default)]
    pub riglets: HashMap<String, RigletMeta>,
    #[serde(default)]
    pub rigs: HashMap<String, RigMeta>,
}

#[derive(Deserialize, Debug, Clone)]
pub struct ConfigOption {
    #[serde(default)]
    pub description: Option<String>,
    #[serde(rename = "type", default)]
    pub option_type: String,
    #[serde(rename = "isDefined", default)]
    pub is_defined: bool,
    #[serde(default)]
    pub default: Option<Value>,
    #[serde(default)]
    pub value: Option<Value>,
    #[serde(rename = "enumValues", default)]
    pub enum_values: Option<Vec<Value>>,
}

// Recursive type for nested config options
// Can be either a leaf option or a nested tree
// IMPORTANT: Nested must come first so serde tries it before Option
// (since ConfigOption has #[serde(default)] on all fields, it can match anything)
#[derive(Deserialize, Debug)]
#[serde(untagged)]
pub enum ConfigValue {
    Nested(HashMap<String, ConfigValue>),
    Option(ConfigOption),
}

#[derive(Deserialize, Debug)]
pub struct RigInspection {
    pub name: String,
    pub riglets: HashMap<String, RigletMeta>,
    #[serde(default)]
    pub entrypoint: Option<String>,
    #[serde(default)]
    pub options: HashMap<String, ConfigValue>,
}
