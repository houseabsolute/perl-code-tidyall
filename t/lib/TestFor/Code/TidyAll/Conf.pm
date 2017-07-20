package TestFor::Code::TidyAll::Conf;

use Code::TidyAll;
use Code::TidyAll::Util qw(tempdir_simple);
use Test::Class::Most parent => 'TestHelper::Test::Class';

my @tests = (
    {
        name   => 'valid config',
        config => <<'EOF',
backup_ttl = 5m
no_cache = 1
inc = /foo
inc = /bar

[+TestHelper::Plugin::UpperText]
select = **/*.txt

[+TestHelper::Plugin::RepeatFoo]
select = **/foo*
select = **/bar*
times = 3
EOF
        methods => {
            backup_ttl      => '5m',
            backup_ttl_secs => '300',
            inc             => [ '/foo', '/bar' ],
            no_backups      => undef,
            no_cache        => 1,
            plugins         => {
                '+TestHelper::Plugin::UpperText' => {
                    select => ['**/*.txt'],
                },
                '+TestHelper::Plugin::RepeatFoo' => {
                    select => [ '**/foo*', '**/bar*' ],
                    times  => 3,
                },
            },
        },
    },
    {
        name   => 'space-separate select & ignore',
        config => <<'EOF',
[+TestHelper::Plugin::RepeatFoo]
select = **/foo* **/bar*
ignore = buz baz
EOF
        methods => {
            plugins => {
                '+TestHelper::Plugin::RepeatFoo' => {
                    select => [ '**/foo*', '**/bar*' ],
                    ignore => [ 'buz',     'baz' ],
                },
            },
        },
    },
);

sub test_config_file_handling : Tests {
    my $self     = shift;
    my $root_dir = tempdir_simple();

    for my $test (@tests) {
        subtest(
            $test->{name},
            sub {
                my $conf_file = $root_dir->child('tidyall.ini');
                $conf_file->spew( $test->{config} );

                my $ct = Code::TidyAll->new_from_conf_file($conf_file);
                for my $method ( sort keys %{ $test->{methods} } ) {
                    cmp_deeply(
                        $ct->$method,
                        $test->{methods}{$method},
                        $method
                    );
                }

                is(
                    $ct->root_dir,
                    $root_dir,
                    'root_dir comes from config file path'
                );

                is(
                    $ct->data_dir,
                    "$root_dir/.tidyall.d",
                    'data dir is below root dir'
                );
            }
        );
    }
}

sub test_bad_config : Tests {
    my $self     = shift;
    my $root_dir = tempdir_simple();

    my $conf_file = $root_dir->child('tidyall.ini');
    ( my $config = $tests[0]{config} ) =~ s/times/timez/;
    $conf_file->spew($config);

    throws_ok { my $ct = Code::TidyAll->new_from_conf_file($conf_file)->plugin_objects }
    qr/unknown option 'timez'/;
}

1;
