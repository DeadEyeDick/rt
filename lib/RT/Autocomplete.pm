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

=head1 NAME

  RT::Autocomplete - generic baseclass for autocomplete classes

=head1 SYNOPSIS

    use RT::Autocomplete;
    my $auto = RT::Autocomplete->new(\%args);
    my $result_obj = $auto->FetchSuggestions(%args);

=head1 DESCRIPTION

Create the list of suggested values for an autocomplete field.

=head1 METHODS

=cut

package RT::Autocomplete;

use strict;
use warnings;

use base qw( RT::Base Class::Accessor::Fast );

__PACKAGE__->mk_accessors( qw(Return Term Max Privileged Exclude Op OpProvided) );

=head2 new

Create an RT::Autocomplete object. Most objects will be on child classes.

Valid parameters:

=over

=item * CurrentUser

CurrentUser object. Required.

=item * Term

Term to search with. Required.

=item * Return

The field to search on. Child class should set a reasonable default based
on the data type (i.e., EmailAddress for User autocomplete).

=item * Max

Maximum number of values to return. Defaults to 10.

=item * Privileged

Limit results to privileged users (mostly for Users).

=item * Exclude

Values to exclude from the autocomplete results.

=item * Op

Operator for the search.

=back

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    my ( $status, $msg ) = $self->_Init(@_);
    RT::Logger->warn($msg) unless $status;

    return $status ? $self : $status;
}

=head2 _Init

Base class validation and object setup.
Put any child class-specific validation in a method called
ValidateParams in the child class.

=cut

sub _Init {
    my $self = shift;
    my %args = (
        Return     => '',
        Term       => undef,
        Delim      => undef,
        Max        => 10,
        Privileged => undef,
        Exclude    => '',
        Op         => '',
        @_
    );

    return ( 0, 'CurrentUser required.' )
      unless $args{CurrentUser};

    $self->CurrentUser( $args{CurrentUser} );

    return ( 0, "No term provided." )
      unless defined $args{Term}
	and length $args{Term};

    # Hook for child class validation.
    my ($return, $msg) = $self->ValidateParams(\%args);
    return ($return, $msg) unless $return;

    # Reset op if an invalid option is passed in or set.
    if( $args{Op} !~ /^(?:LIKE|(?:START|END)SWITH)$/i ){
	$args{Op} = 'STARTSWITH';
    }

    $self->{'Return'} = $args{Return};

   # Use our delimeter if we have one
    if ( defined $args{Delim} and length $args{Delim} ) {
        if ( $args{Delim} eq ',' ) {
            $args{Delim} = qr/,\s*/;
        } else {
            $args{Delim} = qr/\Q$args{Delim}\E/;
        }

        # If the field handles multiple values, pop the last one off
        $args{Term} = ( split $args{Delim}, $args{Term} )[-1]
            if $args{Term} =~ $args{Delim};
    }

    $self->{'Term'} = $args{Term};
    $self->{'Max'} = $args{Max};
    $self->{'Privileged'} = $args{Privileged};
    $self->{'Exclude'} = $args{Exclude};
    $self->{'Op'} = $args{Op};

    return ( 1, 'Object created.' );
}

=head2 ValidateParams

This is a stub. The parent class does general validation in
_Init. Child classes can implement ValidateParams to add any
child-specific param validation before the object is
created.

The parent passes to this method a hashref with all arguments from the
autocomplete call. Child classes can modify values or set child-specific
defaults.

If validation fails, return the failure:

    return (0, 'Failure message.');

In this case the object is not created and the message is logged as
a warning.

=cut

sub ValidateParams{
    # This is a stub. Validation should be applied in child
    # classes.
    return (1, 'Params valid.');
}

=head2 FetchSuggestions

Empty in the base class. See child classes for implementations.

Child classes should create a record object appropriate to the field
they seek to autocomplete. The object provides CurrentUser and a
set of other values that may be passed through from the
autocomplete request. See the new method for parameters.

Child classes should return a record object (RT::Users, RT::Groups, etc.)
with limits set.

=cut

sub FetchSuggestions {
    my $self = shift;

    # This is a stub. Implement in child classes.
    return 1;
}

=head2 LimitForFields

Apply query values for the autocomplete query.
Expects a record object and a hashref with keys of fields and values of
comparison operators. Operator defaults to STARTSWITH, since that is the
common case for autocompletion.

=cut

sub LimitForFields {
    my $self = shift;
    my $records = shift;
    my $fields_ref = shift;

    while ( my ( $name, $op ) = each %{$fields_ref} ) {
        $records->Limit(
            FIELD           => $name,
            OPERATOR        => $op,
            VALUE           => $self->Term,
            ENTRYAGGREGATOR => 'OR',
            SUBCLAUSE       => 'autocomplete',
        );
    }
    return;
}

RT::Base->_ImportOverlays();

1;
