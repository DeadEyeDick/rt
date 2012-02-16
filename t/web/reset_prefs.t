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

$m->get($url.'Prefs/MyRT.html');

diag("Verifying Dashboards are not a default");
{
    lacks_dashboards_ok('body-Selected', "'Dashboards' is not a default pref");
}
{ undef $m; done_testing(); exit } # XXX

diag("Adding a component to body prefs");
{
    $m->form_name('SelectionBox-body');
    $m->field('body-Available' => 'component-Dashboards');
    $m->click_button(name => 'Add');
    has_dashboards_ok('body-Selected', 'Dashboards are now in the prefs');
}

diag("Resetting the body prefs");
{
    $m->submit_form(fields => {Reset => 1});

    lacks_dashboard_ok('body-Selected', 'Dashboards are no longer in the prefs');
}

undef $m;
done_testing();

sub _has_dashboards {
    my $input_name = shift;
    $m->form_name('SelectionBox-body');

    # Load the potential value of each input in the select
    my @selected_values = grep { defined }
                          map { $_->possible_values }
                          $m->current_form->find_input($input_name);

    my $has_dashboards = grep { $_ eq 'component-Dashboards' } @selected_values;
    return $has_dashboards;
}

sub lacks_dashboards_ok {
    my ($input_name, $message) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $has_dashboards = _has_dashboards($input_name);
    ok(!$has_dashboards, $message);
}

sub has_dashboards_ok {
    my ($input_name, $message) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $has_dashboards = _has_dashboards($input_name);
    ok($has_dashboards, $message);
}
