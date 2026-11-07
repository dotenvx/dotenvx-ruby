use magnus::{function, prelude::*, Error, Ruby};

fn load_env(input_json: String) -> Result<String, Error> {
    let options = serde_json::from_str::<dotenvx_ll::LoadOptions>(&input_json)
        .map_err(|error| runtime_error(error.to_string()))?;
    serde_json::to_string(&dotenvx_ll::load(&options))
        .map_err(|error| runtime_error(error.to_string()))
}

fn runtime_error(message: String) -> Error {
    let ruby = Ruby::get().expect("Ruby VM is not available");
    Error::new(ruby.exception_runtime_error(), message)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let dotenvx = ruby.define_module("Dotenvx")?;
    let native = dotenvx.define_module("Native")?;
    native.define_singleton_method("load_env", function!(load_env, 1))?;
    Ok(())
}
