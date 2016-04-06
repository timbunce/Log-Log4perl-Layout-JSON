package Log::Log4perl::Layout::JSON;

=encoding utf8

=head1 NAME

Log::Log4perl::Layout::JSON - Layout a log message as a JSON hash, including MDC data

=head1 SYNOPSIS

Example configuration:

    log4perl.appender.Example.layout = Log::Log4perl::Layout::JSON
    log4perl.appender.Example.layout.field.message = %m{chomp}
    log4perl.appender.Example.layout.field.category = %c
    log4perl.appender.Example.layout.field.class = %C
    log4perl.appender.Example.layout.field.file = %F{1}
    log4perl.appender.Example.layout.field.sub = %M{1}
    log4perl.appender.Example.layout.include_mdc = 1

See below for more configuration options.

=head1 DESCRIPTION

This class implements a C<Log::Log4perl> layout format, similar to
L<Log::Log4perl::Layout::PatternLayout> except that the output is a JSON hash.

The JSON hash is ASCII encoded, with no newlines or other whitespace, and is
suitable for output, via Log::Log4perl appenders, to files and syslog etc.

Contextual data in the L<Log::Log4perl::MDC> hash will be included if
L</include_mdc> is true.

=head1 LAYOUT CONFIGURATION

=head2 field

Specify one or more fields to include in the JSON hash. The value is a string
containing one of more L<Log::Log4perl::Layout::PatternLayout> placeholders.
For example:

    log4perl.appender.Example.layout.field.message = %m{chomp}
    log4perl.appender.Example.layout.field.category = %c
    log4perl.appender.Example.layout.field.where = %F{1}:%L

If no fields are specified, the default is C<message = %m{chomp}>.
It is recommended that C<message> be the first field.

=head2 prefix

Specify a prefix string for the JSON. For example:

    log4perl.appender.Example.layout.prefix = @cee:

See http://blog.gerhards.net/2012/03/cee-enhanced-syslog-defined.html

=head2 include_mdc

Include the data in the Log::Log4perl::MDC hash.

    log4perl.appender.Example.layout.include_mdc = 1

See also L</name_for_mdc>.

=head2 name_for_mdc

Use this name as the key in the JSON hash for the contents of MDC data

    log4perl.appender.Example.layout.name_for_mdc = mdc

If not set then MDC data is placed at top level of the hash.

Where MDC field names match the names of fields defined by the Log4perl
configuration then the MDC values take precedence. This is currently construde
as a feature.

=head2 canonical

If true then use canonical order for hash keys when encoding the JSON.

    log4perl.appender.Example.layout.canonical = 1

This is mainly intended for testing.

=head2 max_json_length_kb

Set the maximum JSON length in kilobytes. The default is 20KB.

    log4perl.appender.Example.layout.max_json_length_kb = 3.8

This is useful where some downstream system has a limit on the maximum size of
a message.

For example, rsyslog has a C<maxMessageSize> configuration parameter with a
default of 4KB. Longer messages are simply truncated (which would corrupt the
JSON). We use rsyslog with maxMessageSize set to 128KB.

If the JSON is larger than the specified size (not including L</prefix>)
then some action is performed to reduce the size of the JSON.

Currently fields are simply removed until the JSON is within the size.
The MDC field/fields are removed first and then the fields specified in the
Log4perl config, in reverse order. A message is printed on C<STDERR> for each
field removed.

In future this rather dumb logic will be replaced by something smarter.

=head2 EXAMPLE USING Log::Log4perl::MDC

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
do_something_useful() will automatically include the 'contextual data',
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

use Carp;

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
            return sub {
                return %$mdc_hash unless $self->canonical;
                return map { $_ => $mdc_hash->{$_} } sort keys %$mdc_hash;
            };
        }
    },

    field => sub {
        return { message => { value => "%m{chomp}" } };
    },
    canonical => 0,
    include_mdc => 0,
    name_for_mdc => undef,
    max_json_length_kb => 20,

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

    if (my $arg = $args->{canonical}) {
        $self->codec->canonical($arg->{value});
    }

    $self->field(delete $args->{field}) if $args->{field};

    for my $arg_name (qw(
        canonical prefix include_mdc name_for_mdc max_json_length_kb
    )) {
        my $arg = delete $args->{$arg_name}
            or next;
        $self->$arg_name( $arg->{value} );
    }

    warn "Unknown configuration items: @{[ sort keys %$args ]}"
        if %$args;

    #use Data::Dumper; warn Dumper $self;

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
    $caller_level++;
    my $layed_out_msg = $self->_pattern_layout->render($message, $category, $priority, $caller_level);

    my @fields = (
        split($self->_separator, $layed_out_msg),
        $self->mdc_handler->($self) # MDC fields override non-MDC fields (not sure if this is a feature)
    );

    my $max_json_length = $self->max_json_length_kb * 1024;
    my @dropped;
    my $json;

    RETRY: {

        # MDC items might contain refs that cause encode to croak
        # or the JSON might be too long
        # so we fall-back to include progressively less data data
        eval {
            $json = $self->codec->encode(+{ @fields });

            die sprintf "length %d > %d\n", length($json), $max_json_length
                if length($json) > $max_json_length;
        };
        if ($@) {
            chomp $@;
            my $encode_error = $@;

            # first look for any top-level field that's more than half of max_json_length
            # for non-ref values truncate the string and add some explanatory text
            # for ref values replace with undef
            # this should catch most cases of an individual field that's too big
            my @truncated;
            for my $i (0 .. @fields/2) {
                my ($k, $v) = ($fields[$i], $fields[$i+1]);

                # we use eval here to protect against fatal encoding errors
                # (they'll get dealt with by the field pruning below)
                my $len;
                if (ref $v) {
                    my $encoded = eval { $self->codec->encode(+{ $k => $v }) };
                    if (not defined $encoded) {
                        $fields[$i+1] = undef;
                        push @truncated, sprintf "%s %s set to undef after encoding error (%s)", $k, ref($v), $@;
                        next;
                    }
                    $len = length $encoded;
                }
                else {
                    $len = length $v;
                }
                next if $len <= $max_json_length/2;

                if (ref $v) {
                    $fields[$i+1] = undef;
                    push @truncated, sprintf "truncated %s %s from %d to undef", $k, ref($v), $len;
                }
                else {
                    my $trunc_marker = sprintf("...[truncated, was %d chars total]...", $len);
                    substr($fields[$i+1], ($max_json_length/2) - length($trunc_marker)) = $trunc_marker;
                    push @truncated, sprintf "truncated %s from %d to %d", $k, $len, length($fields[$i+1]);
                }
            }

            my $msg;
            if (@truncated) {
                $msg = join(", ", @truncated).", retrying";
            }
            else {
                my ($name) = splice @fields, -2;
                push @dropped, $name;
                $msg = "retrying without ".join(", ", @dropped);
            }

            # TODO get smarter here, especially if name_for_mdc is being used.
            #
            # Could encode each field and order by size then discard from top down.
            # Note: if we edit any refs we'd need to edit clones
            # If the 'message' field itself is > $max_json_length/2 then truncate
            # the message to $max_json_length/2 first so we don't loose all the context data.
            # Add an extra field to indicate truncation has happened?


            $last_render_error = sprintf "Error encoding %s: %s (%s)",
                ref($self), $encode_error, $msg;
            # avoid warn due to recursion risk
            print STDERR "$last_render_error\n";

            goto RETRY if @fields;
        }
    }

    return $self->prefix . $json . "\n";
}

1;

__END__

