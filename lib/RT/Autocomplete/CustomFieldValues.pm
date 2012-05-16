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

package RT::Autocomplete::CustomFieldValues;

use strict;
use warnings;
use base qw( RT::Autocomplete );

=head1 NAME

RT::Autocomplete::CustomFieldValues - Autocomplete for CF values

=head1 DESCRIPTION

Perform searches on valid values for CF autocomplete fields.

=head1 METHODS

=cut

=head2 ValidateParams

Validation specific to CFValues autocomplete. Called from parent
_Init before the object is created. Receives a hashref of arguments
passed to new.

=cut

sub ValidateParams {
    my $self = shift;
    my $args_ref = shift;

    # Only autocomplete the last value
    $args_ref->{Term} = (split /\n/, $args_ref->{Term})[-1];

    # Find CFs in args
    # TODO: make this a param, maybe use Limit?
    my $CustomField;
    for my $k ( keys %{$args_ref} ) {
	next unless $k =~ /^Object-.*?-\d*-CustomField-(\d+)-Values?$/;
	$CustomField = $1;
	last;
    }

    return ( 0, 'No Custom Field Values param provided.')
      unless defined $CustomField;

    $self->{'CustomField'} = $CustomField;

    return 1;
}

=head2 FetchSuggestions

Main method to search for CF values.

Creates an RT::CustomField object and searches the selected CF
based on Term, which should be the first few characters a user typed.

=cut

sub FetchSuggestions {
    my $self = shift;

    my $CustomFieldObj = RT::CustomField->new( $self->CurrentUser );
    $CustomFieldObj->Load( $self->CustomField );

    my $values = $CustomFieldObj->Values;

    $values->Limit(
	FIELD           => 'Name',
        OPERATOR        => 'LIKE',
        VALUE           => $self->Term,
        SUBCLAUSE       => 'autocomplete',
        CASESENSITIVE   => 0,
     );

    $values->Limit(
        ENTRYAGGREGATOR => 'OR',
        FIELD           => 'Description',
        OPERATOR        => 'LIKE',
        VALUE           => $self->Term,
        SUBCLAUSE       => 'autocomplete',
        CASESENSITIVE   => 0,
     );

    return $values;
}

=head2 FormatResults

Hook for applying formating to autocomplete results.

=cut

sub FormatResults {
    my $self = shift;
    my $values = shift;

    my @suggestions;
    while( my $value = $values->Next ) {
	push @suggestions,
	  {
	   value => $value->Name,
	   label => $value->Description
	   ? $value->Name . ' (' . $value->Description . ')'
	   : $value->Name,
	  };
    }
    return \@suggestions;
}

1;
