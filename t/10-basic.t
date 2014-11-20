#!/usr/bin/env perl

use Test::Most;

use Log::Log4perl;


subtest "no mdc" => sub {

    my $conf = q(
        log4perl.rootLogger = INFO, Test
        log4perl.appender.Test = Log::Log4perl::Appender::String
        log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON
        log4perl.appender.Test.layout.field.message = %m
        log4perl.appender.Test.layout.field.category = %c
        log4perl.appender.Test.layout.field.class = %C
        log4perl.appender.Test.layout.field.file = %F{1}
        log4perl.appender.Test.layout.field.sub = %M{1}
        log4perl.appender.Test.layout.canonical = 1
    );
    Log::Log4perl::init( \$conf );
    Log::Log4perl::MDC->remove;

    ok my $appender = Log::Log4perl->appender_by_name("Test");

    my $logger = Log::Log4perl->get_logger('foo');

    $logger->info('info message');
    is_deeply $appender->string(), '{"category":"foo","class":"Log::Log4perl::Logger","file":"Logger.pm","message":"info message","sub":"__ANON__"}'."\n";
    $appender->string('');
};

subtest "no mdc" => sub {

    my $conf = q(
        log4perl.rootLogger = INFO, Test
        log4perl.appender.Test = Log::Log4perl::Appender::String
        log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON
        log4perl.appender.Test.layout.field.message = %m
        log4perl.appender.Test.layout.field.category = %c
        log4perl.appender.Test.layout.field.class = %C
        log4perl.appender.Test.layout.field.file = %F{1}
        log4perl.appender.Test.layout.field.sub = %M{1}
        log4perl.appender.Test.layout.canonical = 1
    );
    Log::Log4perl::init( \$conf );
    Log::Log4perl::MDC->remove;

    ok my $appender = Log::Log4perl->appender_by_name("Test");

    my $logger = Log::Log4perl->get_logger('foo');

    $logger->info('info message');
    is_deeply $appender->string(), '{"category":"foo","class":"Log::Log4perl::Logger","file":"Logger.pm","message":"info message","sub":"__ANON__"}'."\n";
    $appender->string('');
};


subtest "with name_for_mdc" => sub {

    my $conf = q(
        log4perl.rootLogger = INFO, Test
        log4perl.appender.Test = Log::Log4perl::Appender::String
        log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON
        log4perl.appender.Test.layout.prefix = @cee:
        log4perl.appender.Test.layout.field.message = %m
        log4perl.appender.Test.layout.field.category = %c
        log4perl.appender.Test.layout.field.class = %C
        log4perl.appender.Test.layout.field.file = %F{1}
        log4perl.appender.Test.layout.field.sub = %M{1}
        log4perl.appender.Test.layout.include_mdc = 1
        log4perl.appender.Test.layout.name_for_mdc = context
        log4perl.appender.Test.layout.canonical = 1
    );
    Log::Log4perl::init( \$conf );
    Log::Log4perl::MDC->remove;

    ok my $appender = Log::Log4perl->appender_by_name("Test");

    my $logger = Log::Log4perl->get_logger('foo');

    $logger->info('info message');
    is_deeply $appender->string(), '@cee:{"category":"foo","class":"Log::Log4perl::Logger","file":"Logger.pm","message":"info message","sub":"__ANON__"}'."\n";
    $appender->string('');

    Log::Log4perl::MDC->get_context->{an_mdc_item}{second_level} = [ [ 42 ] ];

    $logger->warn('warn message');
    is_deeply $appender->string(), '@cee:{"category":"foo","class":"Log::Log4perl::Logger","context":{"an_mdc_item":{"second_level":[[42]]}},"file":"Logger.pm","message":"warn message","sub":"__ANON__"}'."\n";
    $appender->string('');
};

subtest "without mdc" => sub {

    my $conf = q(
        log4perl.rootLogger = INFO, Test
        log4perl.appender.Test = Log::Log4perl::Appender::String
        log4perl.appender.Test.layout = Log::Log4perl::Layout::JSON
        log4perl.appender.Test.layout.prefix = @cee:
        log4perl.appender.Test.layout.field.message = %m
        log4perl.appender.Test.layout.field.category = %c
        log4perl.appender.Test.layout.field.class = %C
        log4perl.appender.Test.layout.field.file = %F{1}
        log4perl.appender.Test.layout.field.sub = %M{1}
        log4perl.appender.Test.layout.include_mdc = 1
        log4perl.appender.Test.layout.canonical = 1
    );
    Log::Log4perl::init( \$conf );
    Log::Log4perl::MDC->remove;

    ok my $appender = Log::Log4perl->appender_by_name("Test");

    my $logger = Log::Log4perl->get_logger('foo');

    $logger->info('info message');
    is_deeply $appender->string(), '@cee:{"category":"foo","class":"Log::Log4perl::Logger","file":"Logger.pm","message":"info message","sub":"__ANON__"}'."\n";
    $appender->string('');

    Log::Log4perl::MDC->get_context->{an_mdc_item}{second_level} = [ [ 42 ] ];

    $logger->warn('warn message');
    is_deeply $appender->string(), '@cee:{"an_mdc_item":{"second_level":[[42]]},"category":"foo","class":"Log::Log4perl::Logger","file":"Logger.pm","message":"warn message","sub":"__ANON__"}'."\n";
    $appender->string('');
};

done_testing();
