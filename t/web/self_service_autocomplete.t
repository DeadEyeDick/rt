use strict;
use warnings;
use RT::Test tests => 16;
use JSON qw(from_json);

RT->Config->Set('AllowUserAutocompleteForUnprivileged', 1);
my ($url, $m) = RT::Test->started_ok;

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

$m->login();

$m->get_ok( '/SelfService/Autocomplete/Users',
	    'request with no params' );

# Output has an extra encoded newline. Not sure where it's
# coming from.
$m->content_contains('', 'empty with no params');

$m->get_ok( '/SelfService/Autocomplete/Users?return=Name',
	    'request with no params' );

$m->content_contains('', 'empty with just return param');

autocomplete_contains('us', 'user_a', $m);

# Shouldn't get root with a term of us.
autocomplete_lacks('us', 'root', $m);

# Lifted from ticket_owner_autocomplete.t and modified
# Should probably be put somewhere shared.

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
