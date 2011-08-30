# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2011 Best Practical Solutions, LLC
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

package RT::Shredder::POD::HTML;
use strict;
use warnings;

use base qw(Pod::Select);

sub command
{
    my( $self, $command, $paragraph, $line_num ) = @_;

    my $tag;
    if ($command =~ /^head(\d+)$/) { $tag = "h$1" }
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;

    print $out_fh "<$tag>" if $tag;
    print $out_fh $expansion;
    print $out_fh "</$tag>" if $tag;
    print $out_fh "\n";
    return;
}

sub verbatim
{
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    print $out_fh "<pre>";
    print $out_fh $paragraph;
    print $out_fh "</pre>";
    print $out_fh "\n";
    return;
}

sub textblock {
    my ($self, $paragraph, $line_num) = @_;
    my $out_fh = $self->output_handle();
    my $expansion = $self->interpolate($paragraph, $line_num);
    $expansion =~ s/^\s+|\s+$//;
    print $out_fh "<p>";
    print $out_fh $expansion;
    print $out_fh "</p>";
    print $out_fh "\n";
    return;
}

sub interior_sequence {
    my ($self, $seq_command, $seq_argument) = @_;
    ## Expand an interior sequence; sample actions might be:
    return "<b>$seq_argument</b>" if $seq_command eq 'B';
    return "<i>$seq_argument</i>" if $seq_command eq 'I';
    return "<span class=\"pod-sequence-$seq_command\">$seq_argument</span>";
}

1;
