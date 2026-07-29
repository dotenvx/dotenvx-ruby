use dotenvx_primitives::{keyring, parse, KeyringOptions, ParseOptions, ParseResult, Value};
use magnus::{function, prelude::*, Error, Ruby};
use std::collections::HashMap;
use std::path::PathBuf;

type StringPairs = Vec<(String, String)>;

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

fn parse_result(result: ParseResult) -> Result<(StringPairs, StringPairs), Error> {
    if !result.errors.is_empty() {
        let message = result
            .errors
            .iter()
            .map(ToString::to_string)
            .collect::<Vec<_>>()
            .join("\n");
        return Err(runtime_error(message));
    }

    Ok((scalar_values(result.parsed), scalar_values(result.injected)))
}

fn parse_dotenv(
    source: String,
    process_env: StringPairs,
    overwrite: bool,
    key_files: Vec<String>,
) -> Result<(StringPairs, StringPairs), Error> {
    let process_env = process_env.into_iter().collect::<HashMap<_, _>>();
    let ring = keyring(&KeyringOptions {
        process_env: process_env.clone(),
        key_files: key_files.into_iter().map(PathBuf::from).collect(),
        ..Default::default()
    })
    .map_err(|error| runtime_error(error.to_string()))?;

    parse_result(parse(
        &source,
        &ParseOptions {
            process_env,
            overload: overwrite,
            ring,
            ..Default::default()
        },
    ))
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let dotenvx = ruby.define_module("Dotenvx")?;
    let native = dotenvx.define_module("Native")?;
    native.define_singleton_method("parse_dotenv", function!(parse_dotenv, 4))?;
    Ok(())
}
