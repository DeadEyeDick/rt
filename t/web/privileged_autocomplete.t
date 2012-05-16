use strict;
use warnings;
use RT::Test tests => 55;
use JSON qw(from_json);

my ($url, $m) = RT::Test->started_ok;

my ($ticket) =
  RT::Test->create_ticket( Queue => 'General', Subject => 'test subject' );

my $user_a = RT::Test->load_or_create_user(
    Name => 'user_a', Password => 'password',
);
ok( $user_a && $user_a->id, 'loaded or created user');

my $user_b = RT::Test->load_or_create_user(
    Name => 'user_b', Password => 'password',
);
ok( $user_b && $user_b->id, 'loaded or created user');

$m->login();

$m->get_ok( '/Helpers/Autocomplete/Users',
	    'Users request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

# Check uppercase param
$m->get_ok( '/Helpers/Autocomplete/Users?Return=Name',
	    'Users request with just Return param' );

$m->content_is("[]\n", 'empty JSON with just Return param');

# Works with lowercase too
$m->get_ok( '/Helpers/Autocomplete/Users?return=Name',
	    'Users request with return param' );

$m->content_is("[]\n", 'empty JSON with just return param');

autocomplete_contains('us', 'user_a', $m);
autocomplete_contains('us', 'user_b', $m);

# Shouldn't get root with a term of us.
autocomplete_lacks('us', 'root', $m);

# Group tests
$m->get_ok( '/Helpers/Autocomplete/Groups',
	    'Groups request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

$m->get_ok( '/Helpers/Autocomplete/Groups?return=Name',
	    'Groups request with just return param' );

$m->content_is("[]\n", 'empty JSON just return param');

# Create a new group
my $group = RT::Group->new(RT->SystemUser);
my $group_name = 'Autocomplete' . $$;
$group->CreateUserDefinedGroup(Name => $group_name);
ok($group->Id, "Created a new group");

$m->get_ok( '/Helpers/Autocomplete/Groups?return=Name&term=uto',
	    "request for $group_name" );

$m->content_contains($group_name, "Found $group_name");

# CF Values tests
$m->get_ok( '/Helpers/Autocomplete/CustomFieldValues',
	    'CFV request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

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
        $m->content_contains('Object created', 'added a value to the CF' ); # or diag $m->content;
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

my $ticket = RT::Test->create_ticket(
    Subject => 'Test CF value autocomplete',
    Queue   => 'General',
);

foreach my $term ( qw(qw AS 0), 'foo bar') {

    my $url = 'CustomFieldValues?Object-RT::Ticket-'
      . $ticket->id . '-CustomField-' . $cfid
	. '-Value&term=' . $term;

    $m->get_ok( "/Helpers/Autocomplete/$url",
		"request for values on CF $cfid" );

    $m->content_contains($term, "Found $term");
}

sub autocomplete {
    my $term = shift;
    my $agent = shift;
    $agent->get_ok("/Helpers/Autocomplete/Users?delim=,&term=$term&return=Name",
		   "fetched autocomplete values");
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
