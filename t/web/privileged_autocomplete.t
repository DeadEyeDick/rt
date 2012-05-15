use strict;
use warnings;
use RT::Test tests => 20;
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
	    'request with no params' );

$m->content_is("[]\n", 'empty JSON no params');

# Check uppercase param
$m->get_ok( '/Helpers/Autocomplete/Users?Return=Name',
	    'request with no params' );

$m->content_is("[]\n", 'empty JSON just return param');

# Works with lowercase too
$m->get_ok( '/Helpers/Autocomplete/Users?return=Name',
	    'request with no params' );

$m->content_is("[]\n", 'empty JSON just return param');

autocomplete_contains('us', 'user_a', $m);
autocomplete_contains('us', 'user_b', $m);

# Shouldn't get root with a term of us.
autocomplete_lacks('us', 'root', $m);

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
