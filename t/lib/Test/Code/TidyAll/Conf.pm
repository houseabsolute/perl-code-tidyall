package Test::Code::TidyAll::Conf;

use Code::TidyAll;
use Code::TidyAll::Util qw(dirname tempdir_simple write_file);
use Test::Class::Most parent => 'Code::TidyAll::Test::Class';

my $conf1;

sub test_conf_file : Tests {
    my $self      = shift;
    my $root_dir  = tempdir_simple();
    my $conf_file = "$root_dir/tidyall.ini";
    write_file( $conf_file, $conf1 );

    my $ct       = Code::TidyAll->new_from_conf_file($conf_file);
    my %expected = (
        backup_ttl      => '5m',
        backup_ttl_secs => '300',
        no_backups      => undef,
        no_cache        => 1,
        root_dir        => dirname($conf_file),
        data_dir        => "$root_dir/.tidyall.d",
        plugins         => {
            '+Code::TidyAll::Test::Plugin::UpperText' => { select => '**/*.txt' },
            '+Code::TidyAll::Test::Plugin::RepeatFoo' => { select => '**/foo* **/bar*', times => 3 }
        }
    );
    while ( my ( $method, $value ) = each(%expected) ) {
        cmp_deeply( $ct->$method, $value, "$method" );
    }

    my $conf2 = $conf1;
    $conf2 =~ s/times/timez/;
    write_file( $conf_file, $conf2 );
    throws_ok { my $ct = Code::TidyAll->new_from_conf_file($conf_file)->plugin_objects }
    qr/unknown option 'timez'/;

}

$conf1 = '
backup_ttl = 5m
no_cache = 1

[+Code::TidyAll::Test::Plugin::UpperText]
select = **/*.txt

[+Code::TidyAll::Test::Plugin::RepeatFoo]
select = **/foo*
select = **/bar*
times = 3
';
