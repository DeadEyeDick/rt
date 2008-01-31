# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
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
# http://www.gnu.org/copyleft/gpl.html.
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
# This Action will open the base if a dependent is resolved.
package RT::ScripAction::AutoOpen;

use strict;
use warnings;

use base qw(RT::ScripAction::Generic);

=head1 description

Opens a ticket unless it's allready open, but only unless transaction
L<RT::Model::Transaction/IsInbound is inbound>.

Doesn't open a ticket if message's head has field C<RT-Control> with
C<no-autoopen> substring.

=cut

sub prepare {
    my $self = shift;

# if the ticket is already open or the ticket is new and the message is more mail from the
# requestor, don't reopen it.

    my $status = $self->ticket_obj->status;
    return undef if $status eq 'open';
    return undef if $status eq 'new' && $self->transaction_obj->is_inbound;

    if ( my $msg = $self->transaction_obj->message->first ) {
        return undef
            if ( $msg->get_header('RT-Control') || '' ) =~ /\bno-autoopen\b/i;
    }

    return 1;
}

sub commit {
    my $self = shift;

    my $oldstatus = $self->ticket_obj->status;
    $self->ticket_obj->__set( column => 'Status', value => 'open' );
    $self->ticket_obj->_new_transaction(
        type      => 'Status',
        field     => 'Status',
        old_value => $oldstatus,
        new_value => 'open',
        data      => 'Ticket auto-opened on incoming correspondence'
    );

    return 1;
}

1;
