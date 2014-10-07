#!/usr/bin/env perl

use Test::Most;

use Log::Log4perl;


subtest "max_json_length_kb" => sub {

    my $max_json_length_kb = 0.1;

    my $conf = qq(
        log4perl.rootLogger = INFO, Test
        log4perl.appender.Test = Log::Log4perl::Appender::String
        log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON
        log4perl.appender.Test.layout.field.message = %m
        log4perl.appender.Test.layout.include_mdc = 1
        log4perl.appender.Test.layout.max_json_length_kb = $max_json_length_kb
        log4perl.appender.Test.layout.canonical = 1
    );
    Log::Log4perl::init( \$conf );

    ok my $appender = Log::Log4perl->appender_by_name("Test");
    my $logger = Log::Log4perl->get_logger('foo');

    Log::Log4perl::MDC->remove;
    Log::Log4perl::MDC->put('foo', 'f' x 100);

    do {
        open my $fh, ">", \my $str or die $!;
        local *STDERR = $fh;
        $logger->info('info message');
        is $str, "Error encoding Log::Log4perl::Layout::JSON: length 135 > 102 (retrying without foo)\n";
    };

    is $appender->string(), '{"message":"info message"}';

    $appender->string('');
};


done_testing();
