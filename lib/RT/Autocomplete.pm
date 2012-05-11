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
use base RT::Base;
use base Class::Accessor::Fast;

use strict;
use warnings;

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    bless( $self, $class );
    my ( $status, $msg ) = $self->_Init(@_);
    RT::Logger->warn($msg) unless $status;
    return $status ? $self : $status;
}

sub _Init {
    my $self        = shift;
    my %args = (
        return     => '',
        term       => undef,
        delim      => undef,
        max        => 10,
        privileged => undef,
        exclude    => '',
        op         => undef,
        @_
    );

    return ( 0, 'CurrentUser required.' )
      unless exists $args{CurrentUser}
	and defined $args{CurrentUser};

    # Require privileged users or overriding config
    return ( 0, 'Permission Denied' )
      unless $args{CurrentUser}->Privileged
	or RT->Config->Get('AllowUserAutocompleteForUnprivileged');

    $self->CurrentUser( $args{CurrentUser} );

    return ( 0, "No term provided." )
        unless defined $args{return}
            and defined $args{term}
            and length $args{term};

    # Only allow certain return fields
    $args{return} = 'EmailAddress'
        unless $args{return} =~ /^(?:EmailAddress|Name|RealName)$/;

    $self->{'Return'} = $args{return};

   # Use our delimeter if we have one
    if ( defined $args{delim} and length $args{delim} ) {
        if ( $args{delim} eq ',' ) {
            $args{delim} = qr/,\s*/;
        } else {
            $args{delim} = qr/\Q$args{delim}\E/;
        }

        # If the field handles multiple values, pop the last one off
        $args{term} = ( split $args{delim}, $args{term} )[-1]
            if $args{term} =~ $args{delim};
    }

    $self->{'Term'} = $args{term};
    $self->{'Max'} = $args{max};
    $self->{'Privileged'} = $args{privileged};
    $self->{'Exclude'} = $args{exclude};
    $self->{'Op'} = $args{op};

    $self->mk_accessors( qw(Return Term Max Privileged Exclude Op) );

    return ( 1, 'Object created.' );
}

sub FetchSuggestions {
    my $self = shift;

    # Nothing to see here. Look in a child class.
    return;
}

RT::Base->_ImportOverlays();

1;
