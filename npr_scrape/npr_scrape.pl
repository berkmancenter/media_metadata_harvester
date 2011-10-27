#!/usr/bin/perl -w

use Feed::Find;
use Data::Dumper;
use Encode;
use LWP::UserAgent;
use XML::LibXML;
use Carp;
use Class::CSV;

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

my $npr_ids_already_scrapped = [

    #topics
    '1034',    # (1) Book Reviews
    '1032',    # (2) Books
    '1033',    # (3) Author Interviews
    '1022',    # (4) Interviews
    '1085',    # (5) Summer Reading: Fiction
    '1089',    # (6) Summer Reading: Nonfiction
    '1086',    # (7) Summer Reading: Kids

    # programs
    '13',      # (1) Fresh Air
    '5',       # (2) Talk of the Nation
    '2',       # (3) All Things Considered

    #series
    '13795507',     # (1) Crime in the City
    '14019811',     # (2) Most Influential Black Authors
    '105197262',    # (3) Observing China At 60: Three Authors
    '10448909',     # (4) Book Tour
    '91752774',     # (5) Books We Like
    '4732640',      # (6) Fully Authorized
];

sub main
{
    Readonly my $api_key => "MDAzNzI2MDAxMDEyNDczMjQ5OTUwODhmZA001";

    my $fields = [ 'TITLE', 'ID',  'Additional Info' ];

    my $csv = Class::CSV->parse(
        filename => 'npr_topics_all.csv',
        fields   => $fields,
    );

    my $id_lines_scrapped = 0;

    shift @ { $csv->lines };

    foreach my $line ( @{ $csv->lines } )
    {

        my $npr_id = $line->{ ID };

        if ( any { $_ eq $npr_id } @ {$npr_ids_already_scrapped  } )
	{
	   say "skipping already scrapped id: $npr_id";
	   next;
	}

        say "Scrapping line " . ($id_lines_scrapped + 1) . " of " . scalar( @{ $csv->lines } );
	say $line->{ TITLE } . ' ' . $line->{ ID };


        _get_npr_api_url( $npr_id, $api_key );

	$id_lines_scrapped++;
	#exit;
    }
}

main();
