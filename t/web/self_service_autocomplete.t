use strict;
use warnings;
use RT::Test tests => 49;
use JSON qw(from_json);

my ($ticket) =
  RT::Test->create_ticket( Queue => 'General', Subject => 'test subject' );

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok $user_a && $user_a->id, 'loaded or created user';

my $user_b = RT::Test->load_or_create_user(
    Name => 'user_b', Password => 'password',
);
ok $user_b && $user_b->id, 'loaded or created user';

$user_a->SetPrivileged(0);

RT->Config->Set('AllowUserAutocompleteForUnprivileged', 0);
my ($url, $m) = RT::Test->started_ok;
$m->login('user_a');

# Should be empty with AllowUserAutocompleteForUnprivileged turned off.
$m->get_ok("/SelfService/Autocomplete/Users?delim=,&term=root&return=Name", "fetched with unpriv turned off");
$m->content_is("[]\n", 'empty JSON no params');

$m->get_ok( '/SelfService/Autocomplete/CustomFieldValues',
            'CFV unpriv request with no params' );
$m->content_is("[]\n", 'empty JSON no params');

RT::Test->stop_server;

RT->Config->Set('AllowUserAutocompleteForUnprivileged', 1);
($url, $m) = RT::Test->started_ok;

$m->login('user_a');

$m->get_ok( '/SelfService/Autocomplete/Users',
	    'request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

$m->get_ok( '/SelfService/Autocomplete/Users?return=Name',
	    'request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

autocomplete_contains('us', ['user_a', 'user_b'], $m);

# Shouldn't get root with a term of us.
autocomplete_lacks('us', 'root', $m);

# CF Values tests

$m->get_ok( '/SelfService/Autocomplete/CustomFieldValues',
            'CFV request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

$m->logout;
$m->login('root');
my $cf_name = 'test enter one value with autocompletion';
my $cfid;
$m->get_ok(RT::Test::Web->rt_base_url);
diag "Create a CF";
{
    $m->follow_link_ok( {id => 'tools-config-custom-fields-create'} );
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            Name          => $cf_name,
            TypeComposite => 'Autocomplete-1',
            LookupType    => 'RT::Queue-RT::Ticket',
        },
    );
    $m->content_contains('Object created', 'created CF sucessfully' );
    $cfid = $m->form_name('ModifyCustomField')->value('id');
    ok $cfid, "found id of the CF in the form, it's #$cfid";
}

diag "add 'qwe', 'ASD', '0' and 'foo bar' as values to the CF";
{
    foreach my $value(qw(qwe ASD 0), 'foo bar') {
        $m->submit_form(
            form_name => "ModifyCustomField",
            fields => {
                "CustomField-". $cfid ."-Value-new-Name" => $value,
            },
            button => 'Update',
        );
        $m->content_contains('Object created', 'added a value to the CF' );
        my $v = $value;
        $v =~ s/^\s+$//;
        $v =~ s/\s+$//;
        $m->content_contains("value=\"$v\"", 'the added value is right' );
    }
}

diag "apply the CF to General queue";
{
    $m->follow_link( id => 'tools-config-queues');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( id => 'page-ticket-custom-fields');
    $m->title_is(q/Custom Fields for queue General/, 'admin-queue: general cfid');

    $m->form_name('EditCustomFields');
    $m->tick( "AddCustomField" => $cfid );
    $m->click('UpdateCFs');

    $m->content_contains('Object created', 'TCF added to the queue' );
}

#$user_a->PrincipalObj->GrantRight(Right => 'ModifyCustomField', Object => $RT::System);

my $cf_ticket = RT::Test->create_ticket(
    Subject => 'Test CF value autocomplete',
    Queue   => 'General',
);

$m->logout;
$m->login('user_a');

foreach my $term ( qw(qw AS 0), 'foo bar') {

    my $url = 'CustomFieldValues?Object-RT::Ticket-'
      . $cf_ticket->id . '-CustomField-' . $cfid
        . '-Value&term=' . $term;

    $m->get_ok( "/SelfService/Autocomplete/$url",
                "request for values on CF $cfid" );

    $m->content_contains($term, "Found $term");
}


sub autocomplete {
    my $term = shift;
    my $agent = shift;
    $agent->get_ok("/SelfService/Autocomplete/Users?delim=,&term=$term&return=Name", "fetched autocomplete values");
    return from_json($agent->content);
}

sub autocomplete_contains {
    my $term = shift;
    my $expected = shift;
    my $agent = shift;

    my $results = autocomplete( $term, $agent );

    my %seen;
    $seen{$_->{value}}++ for @$results;
    $expected = [$expected] unless ref $expected eq 'ARRAY';
    is((scalar grep { not $seen{$_} } @$expected), 0, "got all expected values");
}

sub autocomplete_lacks {
    my $term = shift;
    my $lacks = shift;
    my $agent = shift;

    my $results = autocomplete( $term, $agent );

    my %seen;
    $seen{$_->{value}}++ for @$results;
    $lacks = [$lacks] unless ref $lacks eq 'ARRAY';
    is((scalar grep { $seen{$_} } @$lacks), 0, "didn't get any unexpected values");
}
