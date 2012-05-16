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

package RT::Autocomplete::Owners;

use strict;
use warnings;
use base qw( RT::Autocomplete );

=head1 NAME

RT::Autocomplete::Owners - Autocomplete for ticket owners

=head1 DESCRIPTION

Perform searches to find RT users as options for owner fields
on tickets or for the query builder.

=head1 METHODS

=cut

=head2 ValidateParams

Validation specific to Owners autocomplete. Called from parent
_Init before the object is created. Receives a hashref of arguments
passed to new.

=cut

sub ValidateParams {
    my $self = shift;
    my $args_ref = shift;

    return ( 0, 'No limit provided.')
      unless defined $args_ref->{Limit};

    $args_ref->{Return} = 'Name'
      unless $args_ref->{Return} =~ /^(?:EmailAddress|Name|RealName|id)$/;

    $args_ref->{Op} = 'STARTSWITH'
      unless $args_ref->{Op} =~ /^(?:LIKE|(?:START|END)SWITH)$/i;

    return 1;
}

=head2 FetchSuggestions

Main method to search for owner suggestions.

Parses Limit for tickets and queues to search on.
Then creates RT::Users objects and searches based on Term, which should
be the first few characters a user typed. Accepts an empty Term
value to return all options.

See parent FetchSuggestions
for additional values that can modify the search.

=cut

sub FetchSuggestions {
    my $self = shift;

    my %fields = %{ RT->Config->Get('UserAutocompleteFields')
		      || { EmailAddress => 1, Name => 1, RealName => 'LIKE' } };

    my %user_uniq_hash;
    my $isSU = $self->CurrentUser
      ->HasRight( Right => 'SuperUser', Object => $RT::System );

    # Parse the Limit param for tickets and queues
    my $objects = $self->ParseLimit;

    # Find users for each
    foreach my $object ( @{$objects} ){
	my $users = RT::Users->new( $self->CurrentUser );
	$users->RowsPerPage( $self->Max );

	# Limit by our autocomplete term BEFORE we limit to OwnTicket
	# because that does a funky union hack
	$self->LimitForFields(\%fields);

	$users->WhoHaveRight(
	   Right               => 'OwnTicket',
           Object              => $object,
           IncludeSystemRights => 1,
           IncludeSuperusers   => $isSU );

	while ( my $user = $users->Next() ) {
	    next if $user_uniq_hash{ $user->Id };
	    $user_uniq_hash{ $user->Id() } = [
	       $user,
               $HTML::Mason::Commands::m->scomp(
                         '/Elements/ShowUser',
                          User => $user,
                          NoEscape => 1 )
               ];
	}
    }

    # Add Nobody if we don't already have it
    $self->AddNobody(\%user_uniq_hash);

    my @users = sort { lc $a->[1] cmp lc $b->[1] }
                 values %user_uniq_hash;

    return \@users;
}

=head2 FormatResults

Hook for applying formating to autocomplete results.

=cut

sub FormatResults {
    my $self = shift;
    my $users = shift;
    my $count = 1;
    my @suggestions;

    for my $tuple ( @{$users} ) {
	last if $count > $self->Max;
	my $formatted = $tuple->[1];
	$formatted =~ s/\n//g;
	my $return = $self->Return;
	push @suggestions, {
                label => $formatted,
                value => $tuple->[0]->$return };
	$count++;
    }

    return \@suggestions;
}

=head2 ParseLimit

The Limit param contains tickets or queues on which to find possible
Owners. This method parses that list and returns an array of
objects for the user search.

=cut

sub ParseLimit {
    my $self = shift;
    my @objects;

    # Turn RT::Ticket-1|RT::Queue-2 into ['RT::Ticket', 1], ['RT::Queue', 2]
    foreach my $spec (map { [split /\-/, $_, 2] } split /\|/, $self->Limit) {
	next unless $spec->[0] =~ /^RT::(Ticket|Queue)$/;

	my $object = $spec->[0]->new( $self->CurrentUser );

	if ( $spec->[1] ) {
	    $object->Load( $spec->[1] );

	    # Warn if we couldn't load an object
	    unless ( $object->id ) {
		$RT::Logger->warn("Owner autocomplete couldn't load an '$spec->[0]' with id '$spec->[1]'");
		next;
	    }
	    push @objects, $object;
	}
    }
    return \@objects;
}

=head2 AddNobody

Add the Nobody user to the user list.

=cut

sub AddNobody {
    my $self = shift;
    my $user_uniq_hash = shift;

    my $nobody = qr/^n(?:o(?:b(?:o(?:d(?:y)?)?)?)?)?$/i;
    if ( not $user_uniq_hash->{RT->Nobody->id} and $self->Term =~ $nobody ) {
	$user_uniq_hash->{RT->Nobody->id} = [
              RT->Nobody,
              $HTML::Mason::Commands::m->scomp(
                    '/Elements/ShowUser',
                    User => RT->Nobody,
                    NoEscape => 1 )
              ];
    }
    return;
}


1;
