#!/usr/bin/perl
use strict;
use Test::More tests => 8;
use JSON;

BEGIN {
    use MusicBrainz::Server::Test;
    my $c = MusicBrainz::Server::Test->create_test_context();
    MusicBrainz::Server::Test->prepare_test_database($c);
    MusicBrainz::Server::Test->prepare_test_server();
}

use Test::WWW::Mechanize::Catalyst;
my $mech = Test::WWW::Mechanize::Catalyst->new(catalyst_app => 'MusicBrainz::Server', autolint => 1);

$mech->get_ok('/ajax/search?type=artist&query=Kate', 'perform artist lookup via ajax ws');
my $decoded = from_json ($mech->content ());
my $results = $decoded->{results};
my ($kate) = grep { $_->{gid} eq '4b585938-f271-45e2-b19a-91c634b5e396' } @$results;

is( $decoded->{hits}, 3, 'has result count');
is( $kate->{name}, 'Kate Bush', 'has correct search result');
is( $kate->{gid}, '4b585938-f271-45e2-b19a-91c634b5e396', 'has correct artist mbid');

$mech->get_ok('/ajax/search?type=artist&query=Artist', 'ajax lookup of "Artist"');
$decoded = from_json ($mech->content ());
$results = $decoded->{results};

my @deleted = grep { $_->{gid} eq 'c06aa285-520e-40c0-b776-83d2c9e8a6d1' } @$results;
is( @deleted, 0, 'Deleted Artist not among search results'); 


$mech->get_ok('/ajax/search?type=label&query=Label', 'ajax lookup of "Label"');
$decoded = from_json ($mech->content ());
$results = $decoded->{results};

@deleted = grep { $_->{gid} eq 'f43e252d-9ebf-4e8e-bba8-36d080756cc1' } @$results;
is( @deleted, 0, 'Deleted Label not among search results'); 

