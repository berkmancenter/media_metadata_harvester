#!/usr/bin/perl -w

use Feed::Find;
use Data::Dumper;
use Encode;
use LWP::UserAgent;
use XML::LibXML;
use Carp;

#use XML::LibXML::Enhanced;

use DBIx::Simple;

use List::MoreUtils qw{
  any all none notall true false
  firstidx first_index lastidx last_index
  insert_after insert_after_string
  apply indexes
  after after_incl before before_incl
  firstval first_value lastval last_value
  each_array each_arrayref
  pairwise natatime
  mesh zip uniq  minmax part
};

use 5.10.0;

use strict;
use warnings;
use warnings::unused;
use Readonly;

sub _get_data_hash_from_item_entry
{
    my ( $entry ) = @_;

    #say "starting: _get_data_hash_from_item_entry";

    #say Dumper( $entry );

    my $xc = XML::LibXML::XPathContext->new( $entry );

    $xc->setContextNode( $entry );
    $xc->registerNs( 'a', 'http://www.w3.org/2005/Atom' );

    #say Dumper($entry->toHash( 1) );

    my $id = $entry->getAttribute( 'id' );

    my $full_string = $entry->toStringC14N();

    my $ret = {
        id              => $id,
        full_xml_string => $full_string,
    };

    #say Dumper( $ret );

    #say "ending:_get_data_hash_from_item_entry";

    return $ret;
}

sub _get_db
{
    my $dbargs = {
        AutoCommit => 1,
        RaiseError => 1,
        PrintError => 1,
    };

    my $dbh = DBIx::Simple->connect( DBI->connect( "dbi:SQLite:dbname=yt.db", "", "", $dbargs ) );

    return $dbh;
}

sub _store_item_in_db
{
    my ( $hash ) = @_;

    #say "storing video in the db";
    my $dbh = _get_db();

    $dbh->insert( 'npr_items_raw', $hash );
}

sub _get_item_db_record
{
    my ( $hash ) = @_;

    my $dbh = _get_db();

    #say "_get_item_db_record: id: " . $hash->{ id };

    my $ret = $dbh->query( 'select * from npr_items_raw where id = ? ', $hash->{ id } )->hash;

    if ( !$ret )
    {
        _store_item_in_db( $hash );
        $ret = $dbh->query( 'select * from npr_items_raw where id = ? ', $hash->{ id } )->hash;
        die unless $ret;
    }

    #say "done _get_item_db_record: id: " . $hash->{ id };
    return $ret;
}

Readonly my $total_stories_per_id => 200;

sub npr_api_url
{
    my ( $base_url ) = @_;

    say "npr_api_url '$base_url'";

    confess unless $base_url;

    # max size

    my $start_index = 1;

    my $numResults = 20;

    while ( $start_index <= $total_stories_per_id )
    {

        my $req_url = "$base_url&startNum=$start_index&numResults=$numResults";

        my $uri = URI->new( $req_url );

        say STDERR "Requesting'$req_url' : start_index: $start_index max-results: $numResults";

        # Create a request
        my $req = HTTP::Request->new( GET => $uri );

        my $ua = LWP::UserAgent->new;

        # Pass request to the user agent and get a response back
        my $res = $ua->request( $req );

        die unless $res->is_success;

        #say 'URL final = ' . $res->request->uri;
        my $content = $res->content;

        my $dom = XML::LibXML->load_xml( string => $content );

        my $xc = XML::LibXML::XPathContext->new( $dom );

        #'http://a9.com/-/spec/opensearchrss/1.0/

        my @entries = $xc->findnodes( '//list/story' );

        #say Dumper([@entries]);

        my $num_stories = scalar( @entries );

        say STDERR "Got $num_stories stories";

        if ( $num_stories == 0 )
        {
            last;
        }

        foreach my $entry ( @entries )
        {

            my $hash = _get_data_hash_from_item_entry( $entry );

            #say Dumper ( $hash );

            _get_item_db_record( $hash );
        }

        $start_index += $numResults;
    }

    return;
}

sub _get_npr_api_url
{
    my ( $id, $api_key ) = @_;

    npr_api_url( "http://api.npr.org/query?id=$id&apiKey=$api_key" );

    return;
}

sub main
{
    Readonly my $api_key => "MDAzNzI2MDAxMDEyNDczMjQ5OTUwODhmZA001";

    _get_npr_api_url( 1034, $api_key );
    _get_npr_api_url( 13,   $api_key );
}

main();
