
use strict;
use warnings;
use RT;
use RT::Test tests => 7;

use_ok('RT::Autocomplete');

# my $user = RT::Test->load_or_create_user(
#     Name => 'user_a', Password => 'password',
# );

my $user = RT::User->new(RT->SystemUser);
$user->Load("root");
ok ($user->Id, "Found the root user");

my $auto = RT::Autocomplete->new(
				CurrentUser => $user,
				term => 'ro',);

isa_ok($auto, 'RT::Autocomplete');

use_ok('RT::Autocomplete::Users');

my $auto_user = RT::Autocomplete::Users->new(
				CurrentUser => $user,
				term => 'ro',);

isa_ok($auto_user, 'RT::Autocomplete::Users');

my $users_obj = $auto_user->FetchSuggestions;
isa_ok($users_obj, 'RT::Users');

my $u = $users_obj->Next;
is( $u->Name, 'root', 'Found root user.');
