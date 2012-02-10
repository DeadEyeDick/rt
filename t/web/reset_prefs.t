#!/usr/bin/perl -w
use strict;

use RT::Test tests => undef;
my ($baseurl, $m) = RT::Test->started_ok;
$m->login;
my $url = $m->rt_base_url;

#TODO Test resetting RT at a glance

# find a saved search
my $search;
{
    my $system = RT::System->new(RT->SystemUser);
    while (my $attribute = $system->Attributes->Next) {
        if ($attribute->Name =~ /^Search - /) {
            $search = $attribute;
            last;
        }
    }
}

my $search_name = 'RT::Attribute-'.$search->id;
my $pref_name = 'Pref-'.$search_name;
my $uri = URI->new($url.'Prefs/Search.html');
$uri->query_form(
    OrderBy => 'Priority|Due', # something different from the default
    name    => $search_name,
);

$m->get($uri);

require RT::User;
my $user = RT::User->new(RT->SystemUser);
$user->Load('root');

require RT::Attribute;
my $pref = RT::Attribute->new($user);

my ($pref_created, $pref_exists);
($pref_exists) = $pref->LoadByNameAndObject(Name => $pref_name, Object => $user);
ok(!$pref_exists, 'Preference does not exist yet');

$m->form_name('BuildQuery');
$m->click_button(name => 'Save');

($pref_created) = $pref->LoadByNameAndObject(Name => $pref_name, Object => $user);
ok($pref_created, 'Preference was successfully created upon saving');

$m->form_name('ResetSearchOptions');
$m->click_button(name => 'ResetSearchOptions');

$m->form_name('BuildQuery');
isnt($m->value('OrderBy', 2), 'Due', 'Custom prefs were cleared');

undef $m;
done_testing();
