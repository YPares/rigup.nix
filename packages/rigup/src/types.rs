use serde::Deserialize;
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
    pub broken: bool,
    #[serde(default)]
    pub version: String,
    #[serde(rename = "whenToUse", default)]
    pub when_to_use: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub struct RigMeta {
    #[serde(flatten)]
    pub riglets: HashMap<String, RigletMeta>,
}

#[derive(Deserialize, Debug)]
pub struct InputData {
    #[serde(default)]
    pub riglets: HashMap<String, RigletMeta>,
    #[serde(default)]
    pub rigs: HashMap<String, RigMeta>,
}
