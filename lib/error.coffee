{make_errors} = require 'iced-error'

exports.E = make_errors
    NETWORK_FAIL:'Network connection may down.Cannot connect to the server.'
    CREDIT_ERROR:'The given refresh_token is illegal.'
    INVALID_JSON:'Cannot parse the response JSON.'