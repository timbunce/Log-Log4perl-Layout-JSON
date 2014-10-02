# Log::Log4perl::Layout::JSON

Layout a log message as a JSON hash, including MDC data

[![Build Status](https://secure.travis-ci.org/timbunce/Log-Log4perl-Layout-JSON.png)](http://travis-ci.org/timbunce/Log-Log4perl-Layout-JSON)
[![Coverage Status](https://coveralls.io/repos/timbunce/Log-Log4perl-Layout-JSON/badge.png)](https://coveralls.io/r/timbunce/Log-Log4perl-Layout-JSON)

# SYNOPSIS

Example configuration:

    log4perl.rootLogger = INFO, Test
    log4perl.appender.Test = Log::Log4perl::Appender::String
    log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON


    # Specify which fields to include in the JSON hash:
    # (using PatternLayout placeholders)

    log4perl.appender.Test.layout.field.message = %m
    log4perl.appender.Test.layout.field.category = %c
    log4perl.appender.Test.layout.field.class = %C
    log4perl.appender.Test.layout.field.file = %F{1}
    log4perl.appender.Test.layout.field.sub = %M{1}


    # Specify a prefix string for the JSON (optional)
    # http://blog.gerhards.net/2012/03/cee-enhanced-syslog-defined.html

    log4perl.appender.Test.layout.prefix = @cee:


    # Include the data in the Log::Log4perl::MDC hash (optional)
    log4perl.appender.Test.layout.include_mdc = 1

    # Use this field name for MDC data (else MDC data is placed at top level)
    log4perl.appender.Test.layout.name_for_mdc = mdc


    # Use canonical order for hash keys (optional)

    log4perl.appender.Test.layout.canonical = 1

# DESCRIPTION

This class implements a "Log::Log4perl" layout format, similar to
Log::Log4perl::Layout::PatternLayout except that the output is a JSON
hash.

The JSON hash is ASCII encoded, with no newlines or other whitespace,
and is suitable for output, via Log::Log4perl appenders, to files and
syslog etc.

Contextual data in the Log::Log4perl::MDC hash can be included.

## EXAMPLE

    local Log::Log4perl::MDC->get_context->{request} = {
        request_uri => $req->request_uri,
        query_parameters => $req->query_parameters
    };

    # ...

    for my $id (@list_of_ids) {

        local Log::Log4perl::MDC->get_context->{id} = $id;

        do_something_useful($id);

    }

Using code like that shown above, any log messages produced by
`do_something_useful()` will automatically include 'contextual data'
showing the request URI, the hash of decoded query parameters, and the
current value of $id.

If there's a `$SIG{__WARN__}` handler setup to log warnings via
"Log::Log4perl" then any warnings from perl, such as uninitialized
values, will also be logged with this context data included.

The use of "local" ensures that contextual data doesn't stay in the MDC
beyond the relevant scope. (For more complex cases you could use
something like Scope::Guard or simply take care to delete old data.)
