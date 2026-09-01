use dotenvx_primitives::{keyring, parse, KeyringOptions, ParseOptions, ParseResult, Value};
use magnus::{function, prelude::*, Error, Ruby};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::PathBuf;

type StringPairs = Vec<(String, String)>;
type ErrorPairs = Vec<(String, String)>;

fn runtime_error(message: impl Into<String>) -> Error {
    let ruby = Ruby::get().expect("Ruby VM is not available");
    Error::new(ruby.exception_runtime_error(), message.into())
}

fn scalar_values(values: HashMap<String, Value>) -> StringPairs {
    values
        .into_iter()
        .filter_map(|(key, value)| match value {
            Value::Scalar(value) => Some((key, value)),
            Value::Array(_) => None,
        })
        .collect()
}

fn parse_result(result: ParseResult) -> (StringPairs, StringPairs, ErrorPairs) {
    let errors = result
        .errors
        .iter()
        .map(|error| (error.code().to_owned(), error.to_string()))
        .collect();
    (
        scalar_values(result.parsed),
        scalar_values(result.injected),
        errors,
    )
}

#[derive(Deserialize)]
struct ParseInput {
    source: String,
    process_env: HashMap<String, String>,
    overwrite: bool,
    key_files: Vec<String>,
}

fn parse_dotenv(input_json: String) -> Result<(StringPairs, StringPairs, ErrorPairs), Error> {
    let input = serde_json::from_str::<ParseInput>(&input_json)
        .map_err(|error| runtime_error(error.to_string()))?;
    let process_env = input.process_env;
    let ring = keyring(&KeyringOptions {
        process_env: process_env.clone(),
        key_files: input.key_files.into_iter().map(PathBuf::from).collect(),
        ..Default::default()
    })
    .map_err(|error| runtime_error(error.to_string()))?;

    Ok(parse_result(parse(
        &input.source,
        &ParseOptions {
            process_env,
            overload: input.overwrite,
            ring,
            ..Default::default()
        },
    )))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let dotenvx = ruby.define_module("Dotenvx")?;
    let native = dotenvx.define_module("Native")?;
    native.define_singleton_method("parse_dotenv", function!(parse_dotenv, 1))?;
    Ok(())
}
