
use strict;
use warnings;
use RT;
use RT::Test tests => 17;

use_ok('RT::Autocomplete');

my $user = RT::User->new(RT->SystemUser);
$user->Load("root");
ok ($user->Id, "Created root user for parent");

my $auto = RT::Autocomplete->new(
				CurrentUser => RT::CurrentUser->new($user),
				Term => 'ro',);

isa_ok($auto, 'RT::Autocomplete');

use_ok('RT::Autocomplete::Users');

# Test with root user
test_user_autocomplete($user, 'root', 'ro');

my $user_a = RT::Test->load_or_create_user(
     Name => 'a_user', Password => 'password', );

# Test with normal user
test_user_autocomplete($user_a, 'a_user', 'a_us');

my $user_b = RT::Test->load_or_create_user(
     Name => 'b_user', Password => 'password', );

$user_b->SetPrivileged(0);

# Should fail unprivileged
my $auto_user = RT::Autocomplete::Users->new(
		      CurrentUser => RT::CurrentUser->new($user_b),
		      term => 'b_us',);

ok( !$auto_user, 'new fails with unprivileged user');

RT->Config->Set('AllowUserAutocompleteForUnprivileged', 1);
RT::Test->started_ok;

test_user_autocomplete($user_b, 'b_user', 'b_us');

sub test_user_autocomplete {
    my $user = shift;
    my $name = shift;
    my $term = shift;

    my $auto_user = RT::Autocomplete::Users->new(
		       CurrentUser => RT::CurrentUser->new($user),
		       Term        => $term,);

    isa_ok($auto_user, 'RT::Autocomplete::Users');

    my $users_obj = $auto_user->FetchSuggestions;
    isa_ok($users_obj, 'RT::Users');

    my $u = $users_obj->Next;
    is( $u->Name, $name, "Found $name user.");
}
