# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2012 Best Practical Solutions, LLC
#                                          <sales@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

package RT::Autocomplete::Users;

use strict;
use warnings;
use base qw( RT::Autocomplete );

=head1 NAME

RT::Autocomplete:Users - Autocomplete for users

=head1 DESCRIPTION

Perform searches on user fields like EmailAddress and Name to find users
to suggest in user entry fields in forms.

=head1 METHODS

=cut

=head2 ValidateParams

Validation specific to Users autocomplete. Called from parent
_Init before the object is created. Receives a hashref of arguments
passed to new.

Defaults 'return' field for user searches to EmailAddress.

=cut

sub ValidateParams {
    my $self = shift;
    my $args_ref = shift;

    return ( 0, 'Permission Denied' )
      unless $args_ref->{CurrentUser}->UserObj->Privileged
	or RT->Config->Get('AllowUserAutocompleteForUnprivileged');

    # Remember if the operator was provided to restrict the search
    # later.
    if( defined $args_ref->{Op}
	and $args_ref->{Op} =~ /^(?:LIKE|(?:START|END)SWITH|=|!=)$/i ){
	$self->{'OpProvided'} = $args_ref->{Op};
    }

    # Only allow certain return fields for User entries
    $args_ref->{Return} = 'EmailAddress'
      unless $args_ref->{Return} =~ /^(?:EmailAddress|Name|RealName)$/;

    $args_ref->{Op} = 'STARTSWITH'
      unless $args_ref->{Op} =~ /^(?:LIKE|(?:START|END)SWITH|=|!=)$/i;

    return 1;
}

=head2 FetchSuggestions

Main method to search for user suggestions.

Creates an RT::Users object and searches based on Term, which should
be the first few characters a user typed.

$self->Return, from the autocomplete call, determines
which user field to search on. Also references the RT_Config
value UserAutocompleteFields for search terms and match methods.

See parent FetchSuggestions
for additional values that can modify the search.

Returns an RT::Users object which can be passed to FormatResults.

=cut

sub FetchSuggestions {
    my $self = shift;

    my %fields = %{ RT->Config->Get('UserAutocompleteFields')
		      || { EmailAddress => $self->Op,
			   Name => $self->Op,
			   RealName => 'LIKE' } };

    # If an operator is provided, check against only the returned field
    # using that operator
    %fields = ( $self->Return => $self->Op ) if $self->OpProvided;

    my $users = RT::Users->new($self->CurrentUser);
    $users->RowsPerPage($self->Max);

    $users->LimitToPrivileged() if $self->Privileged;

    $self->LimitForFields($users, \%fields);

    # Exclude users we don't want
    foreach ( split /\s*,\s*/, $self->Exclude ) {
        $users->Limit( FIELD => 'id', VALUE => $_, OPERATOR => '!=' );
    }

    return $users;
}

=head2 FormatResults

Apply final formatting to the suggestions.

Accepts an RT::Users object.

=cut

sub FormatResults {
    my $self = shift;
    my $users = shift;

    my @suggestions;

    while ( my $user = $users->Next ) {
        next if $user->id == RT->SystemUser->id
          or $user->id == RT->Nobody->id;

        my $formatted = $HTML::Mason::Commands::m->scomp(
			   '/Elements/ShowUser',
                           User => $user,
                           NoEscape => 1 );
	$formatted =~ s/\n//g;
        my $return = $self->Return;
        my $suggestion = { label => $formatted, value => $user->$return };

        push @suggestions, $suggestion;
    }

    return \@suggestions;
}

1;
