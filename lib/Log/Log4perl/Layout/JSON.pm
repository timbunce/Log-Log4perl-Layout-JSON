package Log::Log4perl::Layout::JSON;

=encoding utf8

=head1 NAME

Log::Log4perl::Layout::JSON - Layout a log message as a JSON hash, including MDC data

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This class implements a C<Log::Log4perl> layout format, similar to
L<Log::Log4perl::Layout::PatternLayout> except that the output is a JSON hash.

The JSON hash is ASCII encoded, with no newlines or other whitespace, and is
suitable for output, via Log::Log4perl appenders, to files and syslog etc.

Contextual data in the L<Log::Log4perl::MDC> hash can be included.

=head2 EXAMPLE

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
do_something_useful() will automatically include 'contextual data'
showing the request URI, the hash of decoded query parameters, and the current
value of $id.

If there's a C<$SIG{__WARN__}> handler setup to log warnings via C<Log::Log4perl>
then any warnings from perl, such as uninitialized values, will also be logged
with this context data included.

The use of C<local> ensures that contextual data doesn't stay in the MDC
beyond the relevant scope. (For more complex cases you could use something like
L<Scope::Guard> or simply take care to delete old data.)

=cut


use 5.008;
use strict;
use warnings;

use Log::Log4perl ();
use Log::Log4perl::Level;
use Log::Log4perl::Layout::PatternLayout;
use JSON::MaybeXS;

use parent qw(Log::Log4perl::Layout);


# TODO
#   add eval around encode
#   add way to include/exclude MDC items when include_mdc is enabled (eg by name and perhaps allow a regex)
#   more tests
#   consider ways to limit depth/breadth of encoded mdc data
#   add overall message size limit

use Class::Tiny {

    prefix => "",

    codec => sub {
        return JSON::MaybeXS->new
            ->indent(0)          # to prevent newlines (and save space)
            ->ascii(1)           # to avoid encoding issues downstream
            ->allow_unknown(1)   # encode null on bad value (instead of exception)
            ->convert_blessed(1) # call TO_JSON on blessed ref, if it exists
            ->allow_blessed(1)   # encode null on blessed ref that can't be converted
            ;
    },

    # mdc_handler is a code ref that, when called, returns name-value pairs
    # of values from the MDC
    mdc_handler => sub {
        my $self = shift;

        return sub { } unless $self->include_mdc;

        my $mdc_hash = Log::Log4perl::MDC->get_context;

        if (my $mdc_field = $self->name_for_mdc) {
            return sub {
                return () unless %$mdc_hash;
                return ($mdc_field => $mdc_hash);
            };
        }
        else {
            return sub { return %$mdc_hash };
        }
    },

    field => sub {
        return { message => { value => "%m{chomp}" } };
    },
    include_mdc => 0,
    name_for_mdc => undef,

    _separator => "\x01\x00\x01",

    _pattern_layout => sub {
        my $self = shift;

        my $fields = { %{ $self->field } };

        # the lines marked ## are just to ensure message is the first field
        my $message_pattern = delete $fields->{message}; ##
        my @field_patterns = map { $_ => $fields->{$_}->{value} } sort keys %$fields;
        unshift @field_patterns, message => $message_pattern->{value}
            if $message_pattern; ##

        return Log::Log4perl::Layout::PatternLayout->new(join $self->_separator, @field_patterns);
    },

};
BEGIN { push our @ISA, 'Class::Tiny::Object' }

my $last_render_error;


sub BUILD { ## no critic (RequireArgUnpacking)
    my ($self, $args) = @_;

    delete $args->{value}; # => 'Log::Log4perl::Layout::JSON'

    if (my $arg = delete $args->{canonical}) {
        $self->codec->canonical($arg->{value});
    }

    $self->field(delete $args->{field}) if $args->{field};

    for my $arg_name (qw(prefix include_mdc name_for_mdc)) {
        my $arg = delete $args->{$arg_name}
            or next;
        $self->$arg_name( $arg->{value} );
    }

    warn "Unknown configuration items: @{[ sort keys %$args ]}"
        if %$args;

    # sanity check to catch problems with the config at build time
    if (1) {
        undef $last_render_error;
        $self->render("Testing $self config", "test", 1, 0);
        die $last_render_error if $last_render_error;
   }

    return $self;
}


sub render {
    my($self, $message, $category, $priority, $caller_level) = @_;

    my @fields = split $self->_separator,
        $self->_pattern_layout->render($message, $category, $priority, $caller_level);

    my @mdc_items = $self->mdc_handler->();

    # @mdc_items might contain refs that cause encode to croak
    # so we fall-back to include progressively less data data
    my $err;
    my $json = eval {                $self->codec->encode(+{ @fields, @mdc_items }) }
            || eval { $err="mdc";    $self->codec->encode(+{ @fields })             }
            || eval { $err="fields"; $self->codec->encode(+{ message => $message }) };
    if ($err) {
        chomp $@;
        # avoid warn due to recursion risk
        $last_render_error = sprintf "Error encoding %s %s: %s (%s)",
            __PACKAGE__, $err, $@, join(' ', @fields, @mdc_items);
        print STDERR "$last_render_error\n";
    }

    return $self->prefix . $json;
}

1;

__END__

