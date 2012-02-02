#!/usr/bin/perl -w

use strict;
use warnings;

use RT::Test tests => 17;

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok($queue && $queue->id, "loaded or created queue");

diag "create a CF";
my $cf_name = "Test";
my $cf;
{
    $cf = RT::CustomField->new( RT->SystemUser );
    my ($ret, $msg) = $cf->Create(
        Name  => $cf_name,
        Queue => $queue->id,
        Type  => 'DateSingle',
    );
    ok($ret, "Custom Field Order created");
}

my $tester = RT::Test->load_or_create_user(
    Name => 'tester', Password => 'password',
);
ok $tester && $tester->id, 'loaded or created user';

ok( RT::Test->set_rights(
    { Principal => $tester, Right => [qw(SeeQueue ShowTicket CreateTicket ReplyToTicket)] },
    { Principal => $tester, Object => $queue, Right => [qw(SeeCustomField ModifyCustomField)] },
), 'set rights');


my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login(tester => 'password'), 'logged in' );

note 'make sure CF is not reset to no value';
{
    my $t = RT::Test->create_ticket(
        Queue => $queue->id,
        Subject => 'test',
        'CustomField-'.$cf->id => '2012-02-12',
    );
    ok $t && $t->id, 'created ticket';
    is $t->FirstCustomFieldValue($cf_name), '2012-02-12';

    $m->goto_ticket($t->id);
    $m->follow_link_ok({id => 'page-basics'});
    my $form = $m->form_name('TicketModify');
    my $input = $form->find_input(
        'Object-RT::Ticket-'. $t->id .'-CustomField-'. $cf->id .'-Values'
    );
    ok $input, 'found input';
    $m->click('SubmitTicket');

    my $tid = $t->id;
    $t = RT::Ticket->new( $RT::SystemUser );
    $t->Load( $tid );
    is $t->FirstCustomFieldValue($cf_name), '2012-02-12';
}

