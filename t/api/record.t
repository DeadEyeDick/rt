
use Test::More qw/no_plan/;
use RT;
use RT::Test;


{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

ok (require RT::Record);


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $ticket = RT::Ticket->new($RT::SystemUser);
my $group = RT::Group->new($RT::SystemUser);
is($ticket->ObjectTypeStr, 'Ticket', "Ticket returns correct typestring");
is($group->ObjectTypeStr, 'Group', "Group returns correct typestring");


    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

{
    undef $main::_STDOUT_;
    undef $main::_STDERR_;

my $t1 = RT::Ticket->new($RT::SystemUser);
my ($id, $trans, $msg) = $t1->Create(Subject => 'DepTest1', Queue => 'general');
ok($id, "Created dep test 1 - $msg");

my $t2 = RT::Ticket->new($RT::SystemUser);
my ($id2, $trans, $msg2) = $t2->Create(Subject => 'DepTest2', Queue => 'general');
ok($id2, "Created dep test 2 - $msg2");
my $t3 = RT::Ticket->new($RT::SystemUser);
my ($id3, $trans, $msg3) = $t3->Create(Subject => 'DepTest3', Queue => 'general', Type => 'approval');
ok($id3, "Created dep test 3 - $msg3");
my ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t2->id));
ok ($addid, $addmsg);
ok (($addid, $addmsg) =$t1->AddLink( Type => 'DependsOn', Target => $t3->id));

ok ($addid, $addmsg);
my $link = RT::Link->new($RT::SystemUser);
my ($rv, $msg) = $link->Load($addid);
ok ($rv, $msg);
ok ($link->LocalTarget == $t3->id, "Link LocalTarget is correct");
ok ($link->LocalBase   == $t1->id, "Link LocalBase   is correct");

ok ($t1->HasUnresolvedDependencies, "Ticket ".$t1->Id." has unresolved deps");
ok (!$t1->HasUnresolvedDependencies( Type => 'blah' ), "Ticket ".$t1->Id." has no unresolved blahs");
ok ($t1->HasUnresolvedDependencies( Type => 'approval' ), "Ticket ".$t1->Id." has unresolved approvals");
ok (!$t2->HasUnresolvedDependencies, "Ticket ".$t2->Id." has no unresolved deps");
;

my ($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
my ($rid2, $rmsg2) = $t2->Resolve();
ok ($rid2, $rmsg2);
($rid, $rmsg)= $t1->Resolve();
ok(!$rid, $rmsg);
my ($rid3,$rmsg3) = $t3->Resolve;
ok ($rid3,$rmsg3);
($rid, $rmsg)= $t1->Resolve();
ok($rid, $rmsg);



    undef $main::_STDOUT_;
    undef $main::_STDERR_;
}

1;
