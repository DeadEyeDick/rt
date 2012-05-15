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

package RT::Autocomplete::Groups;

use strict;
use warnings;
use base qw( RT::Autocomplete );

=head1 NAME

RT::Autocomplete::Groups - Autocomplete for groups

=head1 DESCRIPTION

Perform searches on group fields like Name to find groups
to suggest in group entry fields in forms.

=head1 METHODS

=cut

=head2 ValidateParams

Validation specific to Groups autocomplete. Called from parent
_Init before the object is created. Receives a hashref of arguments
passed to new.

=cut

sub ValidateParams {
    my $self = shift;
    my $args_ref = shift;

    return ( 0, 'Permission Denied' )
      unless $args_ref->{CurrentUser}->UserObj->Privileged;

    # Set to LIKE to allow fuzzier searching for group names
    $args_ref->{Op} = 'LIKE'
      unless $args_ref->{Op} =~ /^(?:LIKE|(?:START|END)SWITH|=|!=)$/i;

    return 1;
}

=head2 FetchSuggestions

Main method to search for group suggestions.

Creates an RT::Groups object and searches based on Term, which should
be the first few characters a user typed.

See parent FetchSuggestions
for additional values that can modify the search.

=cut

sub FetchSuggestions {
    my $self = shift;

    my $groups = RT::Groups->new( $self->CurrentUser );
    $groups->RowsPerPage( $self->Max );
    $groups->LimitToUserDefinedGroups();

    $groups->Limit(
		   FIELD           => 'Name',
		   OPERATOR        => $self->Op,
		   VALUE           => $self->Term,
		  );

    # Exclude groups we don't want
    foreach my $exclude (split /\s*,\s*/, $self->Exclude) {
	$groups->Limit(FIELD => 'id', VALUE => $exclude, OPERATOR => '!=');
    }

    return $groups;
}

=head2 FormatResults

Hook for applying formating to autocomplete results.

=cut

sub FormatResults {
    my $self = shift;
    my $groups = shift;

    my @suggestions;
    while ( my $group = $groups->Next ) {
	# No extra formatting right now.
        push @suggestions, $group->Name;
    }
    return \@suggestions;
}

1;
