use strict;
use warnings;

use Test::Deep;
use Data::Dumper ();

use RT::Test tests => undef;

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(), 'logged in' );

$m->follow_link_ok( { text => 'System Configuration' }, 'followed link to "System Configuration"' );
$m->follow_link_ok( { text => 'Edit' }, 'followed link to Edit page' );

my $tests = [
    {
        name      => 'change a string value',
        form_id   => 'form-System-Base_configuration',
        setting   => 'CorrespondAddress',
        new_value => 'rt-correspond-edited@example.com',
    },
    {
        name      => 'change a boolean value',
        form_id   => 'form-System-Outgoing_mail',
        setting   => 'NotifyActor',
        new_value => 1,
    },
    {
        name      => 'change an arrayref value',
        form_id   => 'form-System-Extra_security',
        setting   => 'ReferrerWhitelist',
        new_value => ['www.example.com:443', 'www3.example.com:80'],
    },
    {
        name      => 'change a hashref value',
        form_id   => 'form-System-Outgoing_mail',
        setting   => 'OverrideOutgoingMailFrom',
        new_value => { 1 => 'new-outgoing-from@example.com' },
    },
];

run_test( %{$_} ) for @{$tests};

sub run_test {
    my %args = @_;

    diag $args{name} if $ENV{TEST_VERBOSE};

    $m->submit_form_ok(
        {
            form_id => $args{form_id},
            fields  => {
                $args{setting} => stringify( $args{new_value} ),
            },
        },
        'form was submitted successfully'
    );

    # RT::Config in the test is not running in the same process as the one in the test server.
    # ensure the config object in the test is up to date with the changes.
    RT->Config->LoadConfigFromDatabase();

    $m->content_like( qr/$args{setting} changed from/, 'UI indicated the value was changed' );

    # RT::Configuration->Content returns the value as string.
    # in the test below we need to also ensure the new value is string.
    my $rt_configuration = RT::Configuration->new( RT->SystemUser );
    $rt_configuration->Load( $args{setting} );
    my $rt_configuration_value = $rt_configuration->Content;

    my $rt_config_value = RT->Config->Get( $args{setting} );

    cmp_deeply( $rt_configuration_value, stringify($args{new_value}), 'value from RT::Configuration->Load matches new value' );
    cmp_deeply( $rt_config_value, $args{new_value}, 'value from RT->Config->Get matches new value' );
}

sub stringify {
    my $value = shift;

    return $value unless ref $value;

    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 2;
    local $Data::Dumper::Sortkeys = 1;

    my $output = Data::Dumper::Dumper $value;
    chomp $output;
    return $output;
}

done_testing;
